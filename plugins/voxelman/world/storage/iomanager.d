/**
Copyright: Copyright (c) 2016 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/
module voxelman.world.storage.iomanager;

import voxelman.log;
import std.experimental.allocator.mallocator;
import std.bitmanip;
import std.array : empty;
import cbor;
import pluginlib;
import voxelman.core.config;
import voxelman.container.buffer;
import voxelman.config.configmanager : ConfigOption, ConfigManager;
import voxelman.world.worlddb;


alias SaveHandler = void delegate(ref PluginDataSaver);
alias LoadHandler = void delegate(ref PluginDataLoader);

final class IoManager : IResourceManager
{
	package(voxelman.world) LoadHandler[] worldLoadHandlers;
	package(voxelman.world) SaveHandler[] worldSaveHandlers;
	StringMap stringMap;

private:
	ConfigOption saveDirOpt;
	ConfigOption worldNameOpt;

	void delegate(string) onPostInit;

	auto dbKey = IoKey(null);
	void loadStringKeys(ref PluginDataLoader loader) {
		stringMap.load(loader.readEntryDecoded!(string[])(loader.formKey(dbKey)));
		if (stringMap.strings.length == 0) {
			stringMap.put(null); // reserve 0 index for string map
		}
	}

	void saveStringKeys(ref PluginDataSaver saver) {
		//infof("strings %s", stringMap.strings);
		saver.writeEntryEncoded(saver.formKey(dbKey), stringMap.strings);
		//infof("dbKey %s", dbKey);
	}

public:
	this(void delegate(string) onPostInit)
	{
		this.onPostInit = onPostInit;
		stringMap.put(null); // reserve 0 index for string map
		//infof("strings %s", stringMap.strings);
		worldLoadHandlers ~= &loadStringKeys;
		worldSaveHandlers ~= &saveStringKeys;
	}

	override string id() @property { return "voxelman.world.iomanager"; }

	override void init(IResourceManagerRegistry resmanRegistry) {
		ConfigManager config = resmanRegistry.getResourceManager!ConfigManager;
		saveDirOpt = config.registerOption!string("save_dir", "../../saves");
		worldNameOpt = config.registerOption!string("world_name", "world");
	}
	override void postInit() {
		import std.path : buildPath;
		import std.file : mkdirRecurse;
		auto saveFilename = buildPath(saveDirOpt.get!string, worldNameOpt.get!string~".db");
		mkdirRecurse(saveDirOpt.get!string);
		onPostInit(saveFilename);
	}

	void registerWorldLoadSaveHandlers(LoadHandler loadHandler, SaveHandler saveHandler)
	{
		worldLoadHandlers ~= loadHandler;
		worldSaveHandlers ~= saveHandler;
	}
}

struct IoKey {
	string str;
	uint id = uint.max;
}

struct StringMap {
	private Buffer!string array;
	private uint[string] map;

	private void load(string[] ids) {
		array.clear();
		foreach(str; ids) {
			put(str);
		}
	}

	private string[] strings() {
		return array.data;
	}


	private uint put(string key) {
		uint id = cast(uint)array.data.length;
		map[key] = id;
		array.put(key);
		return id;
	}

	private uint get(ref IoKey key) {
		if (key.id == uint.max) {
			key.id = map.get(key.str, uint.max);
			if (key.id == uint.max) {
				key.id = put(key.str);
			}
		}
		return key.id;
	}
}

struct PluginDataSaver
{
	StringMap* stringMap;
	private Buffer!ubyte buffer;
	private size_t prevDataLength;

	package(voxelman.world) void alloc() @nogc {
	}

	package(voxelman.world) void free() @nogc {
	}

	// HACK, duplicate
	ubyte[16] formKey(ref IoKey ioKey) {
		//infof("encode %s", ioKey.str);
		return formWorldKey(stringMap.get(ioKey));
	}

	Buffer!ubyte* beginWrite() {
		prevDataLength = buffer.data.length;
		return &buffer;
	}

	void endWrite(ubyte[16] key) {
		uint entrySize = cast(uint)(buffer.data.length - prevDataLength);
		//printCborStream(buffer.data[$-entrySize..$]);
		buffer.put(*cast(ubyte[4]*)&entrySize);
		buffer.put(key);
	}

	void writeEntryEncoded(T)(ubyte[16] key, T data) {
		beginWrite();
		encodeCbor(buffer, data);
		endWrite(key);
	}

	package(voxelman.world) void reset() @nogc {
		buffer.clear();
	}

	package(voxelman.world) int opApply(int delegate(ubyte[16] key, ubyte[] data) dg)
	{
		ubyte[] data = buffer.data;
		while(!data.empty)
		{
			ubyte[16] key = data[$-16..$];
			uint entrySize = *cast(uint*)(data[$-4-16..$].ptr);
			ubyte[] entry = data[$-4-16-entrySize..$-4-16];

			auto result = dg(key, entry);

			data = data[0..$-4-16-entrySize];

			if (result) return result;
		}
		return 0;
	}
}

unittest
{
	PluginDataSaver saver;
	StringMap stringMap;
	saver.stringMap = &stringMap;

	auto dbKey1 = IoKey("Key1");
	saver.writeEntryEncoded(saver.formKey(dbKey1), 1);

	auto dbKey2 = IoKey("Key2");
	auto sink = saver.beginWrite();
		encodeCbor(sink, 2);
	saver.endWrite(saver.formKey(dbKey2));

	// iteration
	foreach(ubyte[16] key, ubyte[] data; saver) {
		//
	}
	saver.reset();
}

struct PluginDataLoader
{
	StringMap* stringMap;
	WorldDb worldDb;

	// HACK, duplicate
	ubyte[16] formKey(ref IoKey ioKey) {
		//infof("decode %s", ioKey.str);
		return formWorldKey(stringMap.get(ioKey));
	}

	ubyte[] readEntryRaw(ubyte[16] key) {
		auto data = worldDb.get(key);
		//printCborStream(data[]);
		return data;
	}

	/// decodes entry if data in db is not empty. Leaves value untouched otherwise.
	void readEntryDecoded(T)(ubyte[16] key, ref T value) {
		ubyte[] data = readEntryRaw(key);
		if (data)
			decodeCbor!(Yes.Duplicate)(data, value);
	}

	T readEntryDecoded(T)(ubyte[16] key) {
		ubyte[] data = readEntryRaw(key);
		T value;
		if (data) {
			decodeCbor!(Yes.Duplicate)(data, value);
		}
		return value;
	}
}
