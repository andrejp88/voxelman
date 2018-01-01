/**
Copyright: Copyright (c) 2015-2018 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/
module voxelman.log.utils;

import std.experimental.logger;
import std.stdio : stdout, File;

class ConciseLogger : FileLogger
{
	import std.datetime : SysTime;
	import std.concurrency : Tid;
	this(File file, const LogLevel lv = LogLevel.info) @safe
	{
		super(file, lv);
	}

	this(in string fn, const LogLevel lv = LogLevel.info) @safe
	{
		super(fn, lv);
	}

	override protected void beginLogMsg(string file, int line, string funcName,
		string prettyFuncName, string moduleName, LogLevel logLevel,
		Tid threadId, SysTime timestamp, Logger logger)
		@safe
	{
		// empty
	}
}

MultiLogger setupMultiLogger()
{
	globalLogLevel = LogLevel.all;
	auto logger = new MultiLogger;
	sharedLog = logger;
	return logger;
}

void setupFileLogger(MultiLogger parentLogger, string filename)
{
	auto file = File(filename, "w");
	auto fileLogger = new ConciseLogger(file);
	fileLogger.logLevel = LogLevel.all;
	parentLogger.insertLogger("fileLogger", fileLogger);
}

void setupStdoutLogger(MultiLogger parentLogger)
{
	auto conciseLogger = new ConciseLogger(stdout);
	conciseLogger.logLevel = LogLevel.info;
	parentLogger.insertLogger("stdoutLogger", conciseLogger);
}
