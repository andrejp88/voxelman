/**
Copyright: Copyright (c) 2013-2017 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module voxelman.graphics.font.fontmanager;

import voxelman.math;
import voxelman.graphics.font.font;
import voxelman.graphics.textureatlas;

enum string ascii = `!"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_` ~ "abcdefghijklmnopqrstuvwxyz{|}~`";
enum string cyrillic = "АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯЄІЇҐабвгдежзийклмнопрстуфхцчшщъыьэюяєіїґ";
//string glyphs = q"[!"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_abcdefghijklmnopqrstuvwxyz{|}~`АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯЄІЇҐабвгдежзийклмнопрстуфхцчшщъыьэюяєіїґ]";
enum string GLYPHS = ascii~cyrillic;

class FontManager
{
	public:

	FontRef defaultFont;

	this(TextureAtlas texAtlas)
	{
		this.texAtlas = texAtlas;
		defaultFont = createFont("font_hor.png", 10, GLYPHS);
	}

	FontRef createFont(in string filename, in uint size, in dchar[] chars = GLYPHS)
	{
		FontRef newFont = loadFont(filename, size, chars, texAtlas);
		fonts[filename] = newFont;
		return newFont;
	}

	TextureAtlas texAtlas;
	FontRef[string] fonts;
}

FontRef loadFont(in string filename, in uint size, in dchar[] chars, TextureAtlas texAtlas)
{
	import voxelman.graphics.font.bitmapfontloader;
	FontRef result = new Font(filename);

	import std.path;
	string ext = std.path.extension(filename);

	switch(ext)
	{
		case ".png": loadBitmapFont(result, texAtlas, chars); break;
		default: break;
	}

	return result;
}
