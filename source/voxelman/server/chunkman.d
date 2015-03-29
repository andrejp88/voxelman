/**
Copyright: Copyright (c) 2013-2015 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/
module voxelman.server.chunkman;

import std.experimental.logger;
import std.concurrency : Tid, thisTid, send, receiveTimeout;
import std.datetime : msecs;
import core.thread : thread_joinAll;

import dlib.math.vector : vec3, ivec3;

import netlib;

import voxelman.block;
import voxelman.blockman;
import voxelman.storage.chunk;
import voxelman.chunkgen;
import voxelman.chunkmesh;
import voxelman.storage.chunkstorage;
import voxelman.storage.utils;
import voxelman.config;
import voxelman.meshgen;
import voxelman.server.clientinfo;
import voxelman.server.serverplugin;
import voxelman.packets;
import voxelman.storage.storageworker;
import voxelman.utils.queue : Queue;
import voxelman.utils.workergroup;

version = Disk_Storage;


struct ChunkObserverList
{
	ClientId[] observers;

	ClientId[] opIndex()
	{
		return observers;
	}

	bool empty() @property
	{
		return observers.length == 0;
	}

	void add(ClientId clientId)
	{
		observers ~= clientId;
	}

	void remove(ClientId clientId)
	{
		import std.algorithm : remove, SwapStrategy;
		observers = remove!((a) => a == clientId, SwapStrategy.unstable)(observers);
	}
}


///
struct ChunkMan
{
	@disable this();
	this(ServerConnection connection)
	{
		assert(connection);
		this.connection = connection;
	}

	ChunkStorage chunkStorage;
	alias chunkStorage this;

	ServerConnection connection;
	ChunkObserverList[ivec3] chunkObservers;

	// Stats
	size_t numLoadChunkTasks;
	size_t totalLoadedChunks;
	size_t totalObservedChunks;

	BlockMan blockMan;

	WorkerGroup!(chunkGenWorkerThread) genWorkers;
	WorkerGroup!(storageWorkerThread) storeWorker;
	size_t chunksEnqueued;
	size_t maxChunksToEnqueue = 400;
	Queue!ivec3 loadQueue;

	void init()
	{
		blockMan.loadBlockTypes();

		genWorkers.startWorkers(NUM_WORKERS, thisTid);
		version(Disk_Storage)
			storeWorker.startWorkers(1, thisTid, SAVE_DIR);

		chunkStorage.onChunkRemoved = &onChunkRemoved;
		chunkStorage.onChunkAdded = &onChunkAdded;
	}

	void stop()
	{
		infof("saving chunks %s", chunkStorage.chunks.length);

		foreach(chunk; chunkStorage.chunks.byValue)
			chunkStorage.removeQueue.add(chunk);

		size_t toBeDone = chunkStorage.chunks.length;
		uint donePercentsPrev;

		while(chunkStorage.chunks.length > 0)
		{
			update();

			auto donePercents = cast(float)(toBeDone - chunkStorage.chunks.length) / toBeDone * 100;
			if (donePercents >= donePercentsPrev + 10)
			{
				donePercentsPrev += ((donePercents - donePercentsPrev) / 10) * 10;
				infof("saved %s%%", donePercentsPrev);
			}
		}

		genWorkers.stopWorkers();

		version(Disk_Storage)
			storeWorker.stopWorkersWhenDone();

		thread_joinAll();
	}

	void update()
	{
		bool message = true;
		while (message)
		{
			message = receiveTimeout(0.msecs,
				(immutable(ChunkGenResult)* data){onChunkLoaded(cast(ChunkGenResult*)data);}
			);
		}

		chunkStorage.update();
	}

	void removeRegionObserver(ClientId clientId)
	{
		auto region = connection.clientStorage[clientId].visibleRegion;
		foreach(chunkCoord; region.chunkCoords)
		{
			removeChunkObserver(chunkCoord, clientId);
		}
	}

	void updateObserverPosition(ClientId clientId)
	{
		ClientInfo* clientInfo = connection.clientStorage[clientId];
		assert(clientInfo, "clientStorage[clientId] is null");
		ChunkRange oldRegion = clientInfo.visibleRegion;
		vec3 cameraPos = clientInfo.pos;
		int viewRadius = clientInfo.viewRadius;

		ivec3 chunkPos = worldToChunkPos(cameraPos);
		ChunkRange newRegion = calcChunkRange(chunkPos, viewRadius);
		if (oldRegion == newRegion) return;

		onClientVisibleRegionChanged(oldRegion, newRegion, clientId);
		connection.clientStorage[clientId].visibleRegion = newRegion;
	}

	void onClientVisibleRegionChanged(ChunkRange oldRegion, ChunkRange newRegion, ClientId clientId)
	{
		if (oldRegion.empty)
		{
			//trace("observe region");
			observeChunks(newRegion.chunkCoords, clientId);
			return;
		}

		auto chunksToRemove = oldRegion.chunksNotIn(newRegion);

		// remove chunks
		foreach(chunkCoord; chunksToRemove)
		{
			removeChunkObserver(chunkCoord, clientId);
		}

		// load chunks
		observeChunks(newRegion.chunksNotIn(oldRegion), clientId);
	}

	void observeChunks(R)(R chunkCoords, ClientId clientId)
	{
		import std.range : array;
		import std.algorithm : sort;

		ClientInfo* clientInfo = connection.clientStorage[clientId];
		ivec3 observerPos = ivec3(clientInfo.pos);

		ivec3[] chunksToLoad = chunkCoords.array;
		sort!((a, b) => a.euclidDistSqr(observerPos) < b.euclidDistSqr(observerPos))(chunksToLoad);

		foreach(chunkCoord; chunksToLoad)
		{
			addChunkObserver(chunkCoord, clientId);
		}
	}

	void addChunkObserver(ivec3 coord, ClientId clientId)
	{
		if (!isChunkInWorldBounds(coord)) return;

		bool alreadyLoaded = chunkStorage.loadChunk(coord);

		if (chunkObservers[coord].empty)
		{
			++totalObservedChunks;
		}

		chunkObservers[coord].add(clientId);

		if (alreadyLoaded)
		{
			sendChunkTo(coord, clientId);
		}
	}

	void removeChunkObserver(ivec3 coord, ClientId clientId)
	{
		if (!isChunkInWorldBounds(coord)) return;

		chunkObservers[coord].remove(clientId);

		if (chunkObservers[coord].empty)
		{
			chunkStorage.removeQueue.add(chunkStorage.getChunk(coord));
			--totalObservedChunks;
		}
	}

	void onChunkLoaded(ChunkGenResult* data)
	{
		//writefln("Chunk data received in main thread");

		Chunk* chunk = chunkStorage.getChunk(data.coord);
		assert(chunk !is null);

		chunk.hasWriter = false;
		chunk.isLoaded = true;

		assert(!chunk.isUsed);

		++totalLoadedChunks;
		--numLoadChunkTasks;
		//--chunksEnqueued;

		chunk.isVisible = true;
		if (data.blockData.uniform)
		{
			chunk.isVisible = blockMan.blocks[data.blockData.uniformType].isVisible;
		}
		chunk.snapshot.blockData = data.blockData;

		if (chunk.isMarkedForDeletion)
		{
			return;
		}

		// Send data to observers
		sendChunkToObservers(data.coord);
	}

	void onChunkAdded(Chunk* chunk)
	{
		chunkObservers[chunk.coord] = ChunkObserverList();
		chunk.hasWriter = true;
		++numLoadChunkTasks;

		version(Disk_Storage)
		{
			storeWorker.nextWorker.send(chunk.coord, genWorkers.nextWorker);
		}
		else
		{
			genWorkers.nextWorker.send(chunk.coord);
		}
	}

	void onChunkRemoved(Chunk* chunk)
	{
		assert(chunkObservers.get(chunk.coord, ChunkObserverList.init).empty);
		chunkObservers.remove(chunk.coord);

		//loadQueue.put(chunkCoord);

		version(Disk_Storage)
		{
			if (isChunkInWorldBounds(chunk.coord))
			{
				storeWorker.nextWorker.send(
					chunk.coord, cast(shared)chunk.snapshot.blockData, true);
			}
		}
		else
		{
			delete chunk.snapshot.blockData.blocks;
		}
	}

	void sendChunkToObservers(ivec3 coord)
	{
		//tracef("send chunk to all %s %s", coord, chunkStorage.getChunk(coord).snapshot.blockData.blocks.length);
		sendToChunkObservers(coord,
			ChunkDataPacket(coord, chunkStorage.getChunk(coord).snapshot.blockData));
	}

	void sendChunkTo(ivec3 coord, ClientId clientId)
	{
		//tracef("send chunk to %s %s", coord, chunkStorage.getChunk(coord).snapshot.blockData.blocks.length);
		connection.sendTo(clientId,
			ChunkDataPacket(coord, chunkStorage.getChunk(coord).snapshot.blockData));
	}

	void sendToChunkObservers(P)(ivec3 coord, P packet)
	{
		if (auto observerlist = coord in chunkObservers)
		{
			connection.sendTo((*observerlist).observers, packet);
		}
	}

	bool isChunkInWorldBounds(ivec3 coord)
	{
		static if (BOUND_WORLD)
		{
			if(coord.x<0 || coord.y<0 || coord.z<0 || coord.x>=WORLD_SIZE ||
				coord.y>=WORLD_SIZE || coord.z>=WORLD_SIZE)
				return false;
		}

		return true;
	}

	void printAdjacent(Chunk* chunk)
	{
		void printChunk(Side side)
		{
			byte[3] offset = sideOffsets[side];
			ivec3 otherCoord = ivec3(chunk.coord.x + offset[0],
									chunk.coord.y + offset[1],
									chunk.coord.z + offset[2]);
			Chunk* c = chunkStorage.getChunk(otherCoord);
			tracef("%s", c is null ? "null" : "a");
		}

		foreach(s; Side.min..Side.max)
			printChunk(s);
	}
}
