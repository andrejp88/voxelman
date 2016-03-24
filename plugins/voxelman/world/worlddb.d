/**
Copyright: Copyright (c) 2016 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/
module voxelman.world.worlddb;

public import sqlite.d2sqlite3;

import std.array : uninitializedArray;
import std.conv;
import std.stdio;
import std.typecons : Nullable;
import voxelman.storage.coordinates : ChunkWorldPos;
import voxelman.utils.textformatter;

alias StatementHandle = size_t;
enum USE_WAL = false;

final class WorldDb
{
	private Database db;
	private ubyte[] buffer;

	Statement perWorldInsertStmt;
	Statement perWorldSelectStmt;
	Statement perWorldDeleteStmt;

	//Statement perDimentionInsertStmt;
	//Statement perDimentionSelectStmt;
	//Statement perDimentionDeleteStmt;

	Statement perChunkInsertStmt;
	Statement perChunkSelectStmt;
	Statement perChunkDeleteStmt;

	private Statement[] statements;

	void openWorld(string filename)
	{
		buffer = uninitializedArray!(ubyte[])(4096*32);

		auto db = Database(filename);

		static if (USE_WAL) {
			db.execute("PRAGMA synchronous = normal");
			db.execute("PRAGMA journal_mode = wal");
		} else {
			db.execute("PRAGMA synchronous = off");
			db.execute("PRAGMA journal_mode = memory");
		}
		db.execute("PRAGMA count_changes = off");

		db.execute("PRAGMA temp_store = memory");
		db.execute(`PRAGMA page_size = "4096"; VACUUM`);

		db.execute(perWorldTableCreate);
		//db.execute(perDimentionTableCreate);
		db.execute(perChunkTableCreate);

		perWorldInsertStmt = db.prepare(perWorldTableInsert);
		perWorldSelectStmt = db.prepare(perWorldTableSelect);
		perWorldDeleteStmt = db.prepare(perWorldTableDelete);

		//perDimentionInsertStmt = db.prepare(perDimentionTableInsert);
		//perDimentionSelectStmt = db.prepare(perDimentionTableSelect);
		//perDimentionDeleteStmt = db.prepare(perDimentionTableDelete);

		perChunkInsertStmt = db.prepare(perChunkTableInsert);
		perChunkSelectStmt = db.prepare(perChunkTableSelect);
		perChunkDeleteStmt = db.prepare(perChunkTableDelete);
	}

	ubyte[] tempBuffer() @property { return buffer; }

	void execute(string sql)
	{
		db.execute(sql);
	}

	StatementHandle prepareStmt(string sql)
	{
		statements ~= db.prepare(sql);
		return statements.length - 1;
	}

	ref Statement stmt(StatementHandle stmtHandle)
	{
		return statements[stmtHandle];
	}

	void close()
	{
		destroy(perWorldInsertStmt);
		destroy(perWorldSelectStmt);
		destroy(perWorldDeleteStmt);
		//destroy(perDimentionInsertStmt);
		//destroy(perDimentionSelectStmt);
		//destroy(perDimentionDeleteStmt);
		destroy(perChunkInsertStmt);
		destroy(perChunkSelectStmt);
		destroy(perChunkDeleteStmt);
		foreach(ref s; statements)
			destroy(s);
		destroy(statements);
		//db.close();
	}

	// key should contain only alphanum chars and .
	void savePerWorldData(string key, ubyte[] data)
	{
		perWorldInsertStmt.inject(key, data);
	}

	// Reset statement after returned data is no longer needed
	ubyte[] loadPerWorldData(string key)
	{
		perWorldSelectStmt.bindAll(key);
		auto result = perWorldSelectStmt.execute();
		if (result.empty) return null;
		return result.front.peekNoDup!(ubyte[])(0);
	}
	void removePerWorldData(string key)
	{
		perWorldDeleteStmt.inject(key);
	}

	//void savePerDimentionData(string key, int dim, ubyte[] data)

	//ubyte[] loadPerDimentionData(string key, int dim)
	import voxelman.core.config;
	void savePerChunkData(ChunkWorldPos cwp, short dim, ubyte[] data)
	{
		perChunkInsertStmt.inject(packId(cwp, dim), data);
	}

	// Reset statement after returned data is no longer needed
	ubyte[] loadPerChunkData(ChunkWorldPos cwp, short dim)
	{
		perChunkSelectStmt.bindAll(packId(cwp, dim));
		auto result = perChunkSelectStmt.execute();
		if (result.empty) return null;
		return result.front.peekNoDup!(ubyte[])(0);
	}

	static long packId(ChunkWorldPos cwp, short dim)
	{
		long id = cast(ulong)(cast(ushort)dim)<<48 |
				cast(ulong)(cast(ushort)cwp.z)<<32 |
				cast(ulong)(cast(ushort)cwp.y)<<16 |
				cast(ulong)(cast(ushort)cwp.x);
		return id;
	}
}

enum bool withoutRowid = true;
enum string withoutRowidStr = withoutRowid ? ` without rowid;` : ``;

immutable perWorldTableCreate = `
create table if not exists per_world_data (
  id text primary key,
  data blob not null
)` ~ withoutRowidStr;

immutable perWorldTableInsert = `insert or replace into per_world_data values (:id, :value)`;
immutable perWorldTableSelect = `select data from per_world_data where id = :id`;
immutable perWorldTableDelete = `delete from per_world_data where id = :id`;

immutable perDimentionTableCreate = `
create table if not exists per_dimention_data(
  id text,
  dimention integer,
  data blob not null,
  primary key (id, dimention)
)` ~ withoutRowidStr;

immutable perDimentionTableInsert =
`insert or replace into per_dimention_data values (:dim, :id, :value)`;
immutable perDimentionTableSelect = `
select data from per_dimention_data where dimention = :dim and id = :id`;
immutable perDimentionTableDelete = `
delete from per_dimention_data where dimention = :dim and id = :id`;

immutable perChunkTableCreate = `
create table if not exists per_chunk_data(
	id integer primary key,
	data blob not null )`;

immutable perChunkTableInsert = `insert or replace into per_chunk_data values (:id, :value)`;
immutable perChunkTableSelect = `select data from per_chunk_data where id = :id`;
immutable perChunkTableDelete = `delete from per_chunk_data where id = :id`;
