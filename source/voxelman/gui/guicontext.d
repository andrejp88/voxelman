/**
Copyright: Copyright (c) 2017 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module voxelman.gui.guicontext;

import std.stdio;
import datadriven;
import voxelman.graphics;
import voxelman.gui;
import voxelman.platform.input;
import voxelman.math;
import voxelman.text.linebuffer;


struct GuiState
{
	WidgetId draggingWidget;    /// Will receive onDrag events
	WidgetId focusedWidget;     /// Will receive all key events if input is not grabbed by other widget
	WidgetId hoveredWidget;     /// Widget over which pointer is located
	WidgetId inputOwnerWidget;  /// If set, this widget will receive all pointer movement events
	WidgetId lastClickedWidget; /// Used for double-click checking
	WidgetId pressedWidget;

	ivec2 canvasSize;
	ivec2 prevPointerPos = ivec2(int.max, int.max);
	ivec2 curPointerPos;
}

class GuiContext
{
	EntityIdManager widgetIds;
	EntityManager widgets;
	WidgetId[string] nameToId;

	WidgetId[] roots;

	GuiState state;

	this()
	{
		widgets.eidMan = &widgetIds;
		widgets.registerComponent!WidgetContainer;
		widgets.registerComponent!WidgetEvents;
		widgets.registerComponent!WidgetTransform;
		widgets.registerComponent!WidgetIsFocusable;
		widgets.registerComponent!WidgetName;
		widgets.registerComponent!WidgetRespondsToPointer;
		widgets.registerComponent!WidgetStyle;

		roots ~= createWidget("root");
	}

	// WIDGET METHODS

	/// returns 0 if not found
	WidgetId getByName(string name)
	{
		return nameToId.get(name, WidgetId(0));
	}

	/// Pass string as first parameter to set name
	/// Pass WidgetId as first parameter, or after string to set parent
	/// createWidget([string name,] [WidgetId parent,] Component... components)
	WidgetId createWidget(Components...)(Components components)
	{
		auto wId = widgetIds.nextEntityId();

		static if (is(Components[0] == string))
		{
			nameToId[components[0]] = wId;
			widgets.set(wId, WidgetName(components[0]));

			static if (is(Components[1] == WidgetId))
			{
				addChild(components[1], wId);
				enum firstComponent = 2;
			}
			else
			{
				enum firstComponent = 1;
			}
		}
		else static if (is(Components[0] == WidgetId))
		{
			addChild(components[0], wId);
			enum firstComponent = 1;
		}

		widgets.set(wId, components[firstComponent..$]);

		return wId;
	}

	void addChild(WidgetId parent, WidgetId child)
	{
		widgets.getOrCreate!WidgetContainer(parent).put(child);
		widgets.getOrCreate!WidgetTransform(child).parent = parent;
	}

	WidgetId[] widgetChildren(WidgetId wId)
	{
		if (auto container = widgets.get!WidgetContainer(wId)) return container.children;
		return null;
	}

	static struct WidgetTreeVisitor(bool rootFirst)
	{
		WidgetId root;
		GuiContext ctx;
		int opApply(scope int delegate(WidgetId) del)
		{
			int visitSubtree(WidgetId root)
			{
				static if (rootFirst) {
					if (auto ret = del(root)) return ret;
				}
				foreach(child; ctx.widgetChildren(root))
					if (auto ret = visitSubtree(child))
						return ret;
				static if (!rootFirst) {
					if (auto ret = del(root)) return ret;
				}
				return 0;
			}

			return visitSubtree(root);
		}
	}

	auto visitWidgetTreeRootFirst(WidgetId root)
	{
		return WidgetTreeVisitor!true(root, this);
	}

	auto visitWidgetTreeChildrenFirst(WidgetId root)
	{
		return WidgetTreeVisitor!false(root, this);
	}

	void postEvent(Event)(WidgetId wId, auto ref Event event)
	{
		event.ctx = this;
		if (auto events = widgets.get!WidgetEvents(wId)) events.postEvent(wId, event);
	}

	static bool containsPointer(WidgetId widget, GuiContext context, ivec2 pointerPos)
	{
		auto transform = context.widgets.getOrCreate!WidgetTransform(widget);
		return irect(transform.absPos, transform.size).contains(pointerPos);
	}


	// EVENT HANDLERS

	void pointerPressed(uint button)
	{
		auto event = PointerPressEvent(state.curPointerPos, cast(PointerButton)button);

		foreach_reverse(root; roots)
		{
			WidgetId[] path = buildPathToLeaf!(containsPointer)(this, root, this, state.curPointerPos);
			WidgetId[] eventConsumerChain = propagateEventSinkBubble(this, path, event, OnHandle.StopTraversing);

			if (eventConsumerChain.length > 0)
			{
				WidgetId consumer = eventConsumerChain[$-1];
				if (widgets.has!WidgetIsFocusable(consumer))
					focusedWidget = consumer;

				pressedWidget = consumer;
				return;
			}
		}

		focusedWidget = WidgetId(0);
	}

	void pointerReleased(uint button)
	{
		auto event = PointerReleaseEvent(state.curPointerPos, cast(PointerButton)button);

		foreach_reverse(root; roots)
		{
			WidgetId[] path = buildPathToLeaf!(containsPointer)(this, root, this, state.curPointerPos);

			foreach_reverse(item; path) // test if pointer over pressed widget.
			{
				if (item == pressedWidget)
				{
					WidgetId[] eventConsumerChain = propagateEventSinkBubble(this, path, event, OnHandle.StopTraversing);

					if (eventConsumerChain.length > 0)
					{
						if (pressedWidget == eventConsumerChain[$-1])
						{
							auto clickEvent = PointerClickEvent(state.curPointerPos, cast(PointerButton)button);
							postEvent(pressedWidget, clickEvent);
							lastClickedWidget = pressedWidget;
						}
					}

					pressedWidget = WidgetId(0);
					return;
				}
			}
		}

		if (pressedWidget) // no one handled event. Let's pressed widget know that pointer was released.
		{
			postEvent(pressedWidget, event); // pressed widget will know if pointer was unpressed somewhere else.
			updateHovered(state.curPointerPos); // So widget knows if pointer released not over it.
		}

		pressedWidget = WidgetId(0);
	}

	void pointerMoved(ivec2 newPointerPos)
	{
		if (newPointerPos == state.curPointerPos) return;

		ivec2 delta = newPointerPos - state.prevPointerPos;
		state.prevPointerPos = state.curPointerPos;
		state.curPointerPos = newPointerPos;

		auto event = PointerMoveEvent(newPointerPos, delta);

		if (pressedWidget)
		{
			if (containsPointer(pressedWidget, this, state.curPointerPos))
			{
				postEvent(pressedWidget, event);
				if (event.handled)
				{
					hoveredWidget = pressedWidget;
					return;
				}
			}
		}
		else
		{
			if (updateHovered(newPointerPos)) return;
		}

		hoveredWidget = WidgetId(0);
	}

	bool updateHovered(ivec2 pointerPos)
	{
		foreach_reverse(root; roots)
		{
			WidgetId[] path = buildPathToLeaf!(containsPointer)(this, root, this, pointerPos);
			foreach_reverse(widget; path)
			{
				if (widgets.has!WidgetRespondsToPointer(widget))
				{
					hoveredWidget = widget;
					return true;
				}
			}
		}

		hoveredWidget = WidgetId(0);
		return false;
	}

	void update(double deltaTime, RenderQueue renderQueue, ref LineBuffer debugText)
	{
		updateLayout();
		foreach(root; roots)
		{
			propagateEventSinkBubbleTree(this, root, GuiUpdateEvent(deltaTime, &debugText));
			propagateEventSinkBubbleTree(this, root, DrawEvent(renderQueue, &debugText));
		}
	}

	private void updateLayout()
	{
		foreach(root; roots)
		{
			widgets.getOrCreate!WidgetTransform(root).size = state.canvasSize;

			foreach(widgetId; visitWidgetTreeChildrenFirst(root))
			{
				auto measureHandler = widgets.getOrCreate!WidgetTransform(root).measureHandler;
				if (measureHandler) measureHandler(widgetId);
			}

			foreach(widgetId; visitWidgetTreeRootFirst(root))
			{
				auto layoutHandler = widgets.getOrCreate!WidgetTransform(root).layoutHandler;
				if (layoutHandler) layoutHandler(widgetId);
				else defaultLayoutHandler(widgetId);
			}
		}
	}

	void defaultLayoutHandler(WidgetId parentId)
	{
		auto parentTransform = widgets.getOrCreate!WidgetTransform(parentId);
		foreach (WidgetId childId; widgetChildren(parentId))
		{
			auto childTransform = widgets.getOrCreate!WidgetTransform(childId);
			childTransform.absPos = parentTransform.absPos + childTransform.relPos;
		}
	}

	// STATE

	WidgetId draggingWidget() { return state.draggingWidget; }
	void draggingWidget(WidgetId wId) { state.draggingWidget = wId; }

	WidgetId focusedWidget() { return state.focusedWidget; }
	void focusedWidget(WidgetId wId)
	{
		if (state.focusedWidget != wId)
		{
			if (state.focusedWidget) postEvent(state.focusedWidget, FocusLoseEvent());
			if (wId) postEvent(wId, FocusGainEvent());
			state.focusedWidget = wId;
		}
	}

	WidgetId hoveredWidget() { return state.hoveredWidget; }
	void hoveredWidget(WidgetId wId) @trusted /// setter
	{
		if (state.hoveredWidget != wId)
		{
			if (state.hoveredWidget) postEvent(state.hoveredWidget, PointerLeaveEvent());
			if (wId) postEvent(wId, PointerEnterEvent());
			state.hoveredWidget = wId;
		}
	}

	WidgetId inputOwnerWidget() { return state.inputOwnerWidget; }
	void inputOwnerWidget(WidgetId wId) { state.inputOwnerWidget = wId; }

	WidgetId lastClickedWidget() { return state.lastClickedWidget; }
	void lastClickedWidget(WidgetId wId) { state.lastClickedWidget = wId; }

	WidgetId pressedWidget() { return state.pressedWidget; }
	void pressedWidget(WidgetId wId) { state.pressedWidget = wId; }

	// HANDLERS
	bool handleWidgetUpdate(WidgetId wId, ref GuiUpdateEvent event)
	{
		return true;
	}
}
