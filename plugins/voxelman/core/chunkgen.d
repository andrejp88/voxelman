/**
Copyright: Copyright (c) 2013-2016 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/
module voxelman.core.chunkgen;

import std.experimental.logger;
import std.concurrency : Tid, send, receive;
import std.variant : Variant;
import core.atomic : atomicLoad;
import std.conv : to;
import core.exception : Throwable;

import dlib.math.vector : ivec3;

import anchovy.simplex;
import voxelman.block.utils;
import voxelman.core.config;
import voxelman.storage.chunk;
import voxelman.storage.chunkprovider;
import voxelman.storage.coordinates;


alias Generator = Generator2d;
//alias Generator = Generator2d3d;
//alias Generator = TestGeneratorSmallCubes;
//alias Generator = TestGeneratorSmallCubes2;
//alias Generator = TestGeneratorSmallCubes3;

struct ChunkGenResult
{
	BlockData blockData;
	ChunkWorldPos position;
	TimestampType timestamp;
}

void chunkGenWorkerThread(Tid mainTid)
{
	try
	{
		shared(bool)* isRunning;
		bool isRunningLocal = true;
		receive( (shared(bool)* _isRunning){isRunning = _isRunning;} );

		while (atomicLoad(*isRunning) && isRunningLocal)
		{
			receive(
				(immutable(LoadSnapshotMessage)* message){
					chunkGenWorker(cast(LoadSnapshotMessage*)message, mainTid);
				},
				(Variant v){isRunningLocal = false;}
			);
		}
	}
	catch(Throwable t)
	{
		error(t.to!string, " from gen worker");
		throw t;
	}
}

// Gen single chunk
void chunkGenWorker(LoadSnapshotMessage* message, Tid mainThread)
{
	ChunkWorldPos cwp = message.cwp;
	int wx = cwp.x, wy = cwp.y, wz = cwp.z;

	BlockData bd;
	bd.blocks.length = CHUNK_SIZE_CUBE;
	bd.convertToArray();
	bd.uniform = false;
	bool uniform = true;

	Generator generator = Generator(cwp.ivector * CHUNK_SIZE);
	generator.genPerChunkData();

	bd.blocks[0] = generator.generateBlock(0, 0, 0);
	BlockId type = bd.blocks[0];

	int bx, by, bz;
	foreach(i; 1..CHUNK_SIZE_CUBE)
	{
		bx = i & CHUNK_SIZE_BITS;
		by = (i / CHUNK_SIZE_SQR) & CHUNK_SIZE_BITS;
		bz = (i / CHUNK_SIZE) & CHUNK_SIZE_BITS;

		// Actual block gen
		bd.blocks[i] = generator.generateBlock(bx, by, bz);

		if(uniform && bd.blocks[i] != type)
		{
			uniform = false;
		}
	}

	bd.uniform = uniform;
	if(uniform) {
		bd.uniformType = type;
	}

	auto res = new SnapshotLoadedMessage(message.cwp, [BlockDataSnapshot(bd)], false);
	mainThread.send(cast(immutable(SnapshotLoadedMessage)*)res);
}

struct Generator2d3d
{
	ivec3 chunkOffset;

	private int[CHUNK_SIZE_SQR] heightMap = void;

	void genPerChunkData()
	{
		genPerChunkData2d(heightMap[], chunkOffset);
	}

	BlockId generateBlock(int x, int y, int z)
	{
		enum NOISE_SCALE_3D = 42;
		enum NOISE_TRESHOLD_3D = -0.6;
		int height = heightMap[z * CHUNK_SIZE + x];
		int blockY = chunkOffset.y + y;
		if (blockY > height) {
			if (blockY > 0)
				return 1;
			else
				return 6;
		}

		float noise3d = Simplex.noise(cast(float)(chunkOffset.x+x)/NOISE_SCALE_3D,
			cast(float)(chunkOffset.y+y)/NOISE_SCALE_3D, cast(float)(chunkOffset.z+z)/NOISE_SCALE_3D);
		if (noise3d < NOISE_TRESHOLD_3D) return 1;

		if (blockY == height) return 2;
		else if (blockY > height - 10) return 3;
		else return 4;
	}
}

struct Generator2d
{
	ivec3 chunkOffset;

	private int[CHUNK_SIZE_SQR] heightMap = void;

	void genPerChunkData()
	{
		genPerChunkData2d(heightMap[], chunkOffset);
	}

	BlockId generateBlock(int x, int y, int z)
	{
		int height = heightMap[z * CHUNK_SIZE + x];
		int blockY = chunkOffset.y + y;
		if (blockY > height) {
			if (blockY > 0)
				return 1;
			else
				return 6;
		}

		if (blockY == height) return 2;
		else if (blockY > height - 10) return 3;
		else return 4;
	}
}

struct TestGeneratorSmallCubes
{
	ivec3 chunkOffset;
	void genPerChunkData(){}

	BlockId generateBlock(int x, int y, int z)
	{
		if (x % 2 == 0 && y % 2 == 0 && z % 2 == 0) return 2;
		else return 1;
	}
}

struct TestGeneratorSmallCubes2
{
	ivec3 chunkOffset;
	void genPerChunkData(){}

	BlockId generateBlock(int x, int y, int z)
	{
		if (x % 4 == 0 && y % 4 == 0 && z % 4 == 0) return 2;
		else return 1;
	}
}

struct TestGeneratorSmallCubes3
{
	enum cubesSizes = 4;
	enum cubeOffsets = 16;
	ivec3 chunkOffset;
	void genPerChunkData(){}

	BlockId generateBlock(int x, int y, int z)
	{
		if (x % cubeOffsets < cubesSizes &&
			y % cubeOffsets < cubesSizes &&
			z % cubeOffsets < cubesSizes) return 2;
		else return 1;
	}
}

float noise2d(int x, int z)
{
	enum NUM_OCTAVES = 8;
	enum DIVIDER = 50; // bigger - smoother
	enum HEIGHT_MODIFIER = 4; // bigger - higher

	float noise = 0.0;
	foreach(i; 1..NUM_OCTAVES+1)
	{
		// [-1; 1]
		noise += Simplex.noise(cast(float)x/(DIVIDER*i), cast(float)z/(DIVIDER*i))*i*HEIGHT_MODIFIER;
	}

	return noise;
}

void genPerChunkData2d(int[] heightMap, ivec3 chunkOffset)
{
	foreach(i, ref elem; heightMap)
	{
		int cx = i & CHUNK_SIZE_BITS;
		int cz = (i / CHUNK_SIZE) & CHUNK_SIZE_BITS;
		elem = cast(int)noise2d(chunkOffset.x + cx, chunkOffset.z + cz);
	}
}
