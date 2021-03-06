/**
Copyright: Copyright (c) 2016-2018 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/
module voxelman.model.ply;

import std.algorithm : startsWith;
import std.conv : to, parse;
import std.string : lineSplitter, stripLeft;

import voxelman.container.buffer : Buffer;
import voxelman.model.utils : unrollFaces;
import voxelman.model.mesh : Faces, Mesh;
import voxelman.math;

enum HEADER_STR = "end_header";
enum VERTEX_STR = "element vertex ";
enum FACE_STR = "element face ";

Vert[] readPlyFile(Vert)(string fileName)
{
	import std.file : read;
	string data = cast(string)read(fileName);
	Mesh!Vert mesh = parsePly!Vert(data);
	return unrollFaces(mesh.vertices, mesh.faces);
}

Mesh!Vert parsePly(Vert)(string fileData)
{
	auto lines = fileData.lineSplitter;

	size_t numVertices;
	size_t numFaces;

	// parse header
	while(!lines.empty)
	{
		auto line = lines.front;

		if (line.startsWith(HEADER_STR))
		{
			lines.popFront;
			break;
		}
		else if (line.startsWith(VERTEX_STR))
		{
			numVertices = to!size_t(line[VERTEX_STR.length..$]);
		}
		else if (line.startsWith(FACE_STR))
		{
			numFaces = to!size_t(line[FACE_STR.length..$]);
		}

		lines.popFront;
	}

	Buffer!Vert vertices;

	// parse vertices
	foreach (i; 0..numVertices)
	{
		auto line = lines.front;

		Vert v;
		vec3 position;
		ubvec3 color;
		position.x = parse!float(line); line = stripLeft(line);
		position.y = parse!float(line); line = stripLeft(line);
		position.z = parse!float(line); line = stripLeft(line);
		color.r = parse!ubyte(line); line = stripLeft(line);
		color.g = parse!ubyte(line); line = stripLeft(line);
		color.b = parse!ubyte(line);

		vertices.put(Vert(position, color));

		lines.popFront;
	}

	Buffer!int faceData;
	faceData.reserve(numFaces * 4);

	// parse faces
	foreach (i; 0..numFaces)
	{
		auto line = lines.front;

		int numFaceVertices = parse!int(line);
		faceData.put(numFaceVertices);

		foreach (j; 0..numFaceVertices)
		{
			line = stripLeft(line);
			faceData.put(parse!int(line));
		}

		lines.popFront;
	}

	return Mesh!Vert(
		vertices.data,
		Faces(faceData.data, numFaces));
}
