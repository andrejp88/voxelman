/**
Copyright: Copyright (c) 2013-2018 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module voxelman.platform.iwindow;

import voxelman.math;
import voxelman.platform.isharedcontext;
import voxelman.utils.signal;
public import voxelman.platform.cursoricon : CursorIcon;
public import voxelman.platform.input : KeyCode, PointerButton;
public import derelict.opengl.types : GLVersion;

struct WindowParams
{
	ivec2 size;
	string title;
	bool center = false;
	bool openglDebugContext = false;

	version(Windows) {
		bool openglForwardCompat = false;
		bool openglCoreProfile = false;
		GLVersion openglVersion = GLVersion.gl31;
	} else version(OSX) {
		bool openglForwardCompat = true;
		bool openglCoreProfile = true;
		GLVersion openglVersion = GLVersion.gl32;
	} else version(linux) {
		bool openglForwardCompat = true;
		bool openglCoreProfile = false;
		GLVersion openglVersion = GLVersion.gl31;
	}
}

abstract class IWindow
{
	void init(WindowParams);
	ISharedContext createSharedContext();
	void reshape(ivec2 viewportSize);
	void moveToCenter();
	void processEvents(); // will emit signals
	double elapsedTime() @property; // in seconds
	void swapBuffers();
	void setVsync(bool);
	void releaseWindow();

	void mousePosition(ivec2 newPosition) @property;
	ivec2 mousePosition() @property;

	ivec2 size() @property;
	ivec2 framebufferSize() @property;
	void size(ivec2 newSize) @property;

	bool isKeyPressed(uint key);

	string clipboardString() @property;
	void clipboardString(string newClipboardString) @property;

	void isCursorLocked(bool value);
	bool isCursorLocked();

	void setCursorIcon(CursorIcon icon);

	Signal!(KeyCode, uint) keyPressed;
	Signal!(KeyCode, uint) keyReleased;
	Signal!dchar charEntered;
	Signal!(PointerButton, uint) mousePressed;
	Signal!(PointerButton, uint) mouseReleased;
	Signal!ivec2 mouseMoved;
	Signal!bool focusChanged;
	Signal!ivec2 windowResized;
	Signal!ivec2 windowMoved;
	Signal!bool windowIconified;
	Signal!dvec2 wheelScrolled;
	Signal!() closePressed;
	Signal!() refresh;
}
