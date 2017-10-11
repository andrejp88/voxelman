/**
Copyright: Copyright (c) 2017 Andrey Penechko.
License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module gui2;

import std.format : formattedWrite;
import std.stdio;
import voxelman.math;
import voxelman.gui;
import voxelman.gui.textedit.messagelog;
import voxelman.gui.textedit.textmodel;
import voxelman.gui.textedit.texteditorview;
import voxelman.graphics;
import voxelman.text.scale;

import launcher;
import voxelman.gui.guiapp;

class LauncherGui : GuiApp
{
	Launcher launcher;

	string pluginFolder = `./plugins`;
	string pluginPackFolder = `./pluginpacks`;
	string toolFolder = `./tools`;

	AutoListModel!WorldList worldList;
	AutoListModel!ServerList serverList;
	WidgetProxy job_stack;
	TextViewSettings textSettings;


	this(string title, ivec2 windowSize)
	{
		super(title, windowSize);
		maxFps = 30;
		launcher.init();
		launcher.setRootPath(pluginFolder, pluginPackFolder, toolFolder);
		launcher.refresh();
	}

	override void load(string[] args)
	{
		super.load(args);
		textSettings = TextViewSettings(renderQueue.defaultFont);
		WidgetProxy root = WidgetProxy(guictx.roots[0], guictx);
		createMain(root);
	}

	override void userPreUpdate(double delta)
	{
		launcher.update();
	}

	override void closePressed()
	{
		if (!launcher.anyProcessesRunning)
		{
			isClosePressed = true;
		}
	}

	void createMain(WidgetProxy root)
	{
		HLayout.attachTo(root, 0, padding4(0));

		WidgetProxy left_panel = PanelLogic.create(root, color_gray)
			.minSize(ivec2(60, 0))
			.vexpand
			.setVLayout(3, padding4(3, 0, 3, 3));

		WidgetProxy right_panel = VLayout.create(root, 0, padding4(0)).hvexpand;

		left_panel.createIconTextButton("play", "Play", () => PagedWidget.switchPage(right_panel, 0)).hexpand;
		left_panel.createIconTextButton("hammer", "Debug", () => PagedWidget.switchPage(right_panel, 1)).hexpand;

		createPlay(right_panel);
		createDebug(right_panel);

		PagedWidget.convert(right_panel, 0);
	}

	WidgetProxy createPlay(WidgetProxy parent)
	{
		auto play_panel = HLayout.create(parent, 0, padding4(0)).hvexpand;

		auto worlds_panel = VLayout.create(play_panel, 0, padding4(1)).hvexpand;

			worldList = new AutoListModel!WorldList(WorldList(&launcher));
			auto list_worlds = ColumnListLogic.create(worlds_panel, worldList).minSize(260, 100).hvexpand;

			WidgetProxy bottom_panel_worlds = HLayout.create(worlds_panel, 2, padding4(1)).hexpand.addBackground(color_gray);
				bottom_panel_worlds.createTextButton("New", &newWorld);
				bottom_panel_worlds.createTextButton("Remove", &removeWorld).visible_if(&worldList.hasSelected);
				bottom_panel_worlds.createTextButton("Refresh", &refreshWorlds);
				HFill.create(bottom_panel_worlds);
				bottom_panel_worlds.createTextButton("Server", &startServer).visible_if(&worldList.hasSelected);
				bottom_panel_worlds.createTextButton("Start", &startClient).visible_if(&worldList.hasSelected);

		VLine.create(play_panel);

		auto servers_panel = VLayout.create(play_panel, 0, padding4(1)).hvexpand;
			serverList = new AutoListModel!ServerList(ServerList(&launcher));
			auto list_servers = ColumnListLogic.create(servers_panel, serverList).minSize(320, 100).hvexpand;

			WidgetProxy bottom_panel_servers = HLayout.create(servers_panel, 2, padding4(1)).hexpand.addBackground(color_gray);
				bottom_panel_servers.createTextButton("New", &newServer);
				bottom_panel_servers.createTextButton("Remove", &removeServer).visible_if(&serverList.hasSelected);
				HFill.create(bottom_panel_servers);
				bottom_panel_servers.createTextButton("Connect", &connetToServer).visible_if(&serverList.hasSelected);

		return play_panel;
	}

	WidgetProxy createDebug(WidgetProxy parent)
	{
		auto debug_panel = VLayout.create(parent, 0, padding4(0)).hvexpand;
		auto top_buttons = HLayout.create(debug_panel, 2, padding4(1)).hexpand;

		TextButtonLogic.create(top_buttons, "Client", &startClient_debug);
		TextButtonLogic.create(top_buttons, "Server", &startServer_debug);
		TextButtonLogic.create(top_buttons, "Combined", &startCombined_debug);

		job_stack = VLayout.create(debug_panel, 0, padding4(0)).hvexpand;

		return debug_panel;
	}

	void newWorld() {}
	void removeWorld() {}
	void refreshWorlds() {
		launcher.refresh();
	}
	void startServer() {
		auto job = launcher.startServer(launcher.pluginPacks[0], launcher.saves[worldList.selectedRow]);
		if (job) onJobCreate(job);
	}
	void startClient() {
		auto job = launcher.startCombined(launcher.pluginPacks[0], launcher.saves[worldList.selectedRow]);
		if (job) onJobCreate(job);
	}

	void newServer() {}
	void removeServer() {}
	void connetToServer() {}

	void startClient_debug() { startJob(AppType.client); }
	void startServer_debug() { startJob(AppType.server); }
	void startCombined_debug() { startJob(AppType.combined); }

	void startJob(AppType appType)
	{
		JobParams params;
		params.appType = appType;
		Job* job = launcher.createJob(params);
		onJobCreate(job);
	}

	void onJobCreate(Job* job)
	{
		auto job_item = VLayout.create(job_stack, 0, padding4(0)).hvexpand;
		auto top_buttons = HLayout.create(job_item, 2, padding4(1)).hexpand;
		createCheckButton(top_buttons, "nodeps", cast(bool*)&job.params.nodeps);
		createCheckButton(top_buttons, "force", cast(bool*)&job.params.force);
		createCheckButton(top_buttons, "x64", cast(bool*)&job.params.arch64);
		DropDown.create(top_buttons, buildTypeUiOptions, 0);
		DropDown.create(top_buttons, compilerUiOptions, 0);
		createTextButton(top_buttons, "Clear", {});
		createTextButton(top_buttons, "Close", {});
		createTextButton(top_buttons, " Run ", {});
		createTextButton(top_buttons, "Build", {});
		createTextButton(top_buttons, " B&R ", {});

		job.msglog.setClipboard = &window.clipboardString;
		auto msglogModel = new MessageLogTextModel(&job.msglog);
		auto viewport = TextEditorViewportLogic.create(job_item, msglogModel, &textSettings).hvexpand;
		viewport.get!TextEditorViewportData.autoscroll = true;
	}
}

struct WorldList
{
	Launcher* launcher;
	WorldRow opIndex(size_t i) { return WorldRow(*launcher.saves[i]); }
	size_t length() { return launcher.saves.length; }
}

struct WorldRow
{
	this(SaveInfo info) {
		this.filename = info.name;
		this.fileSize = info.size;
	}
	@Column!WorldRow("Name", 200, (WorldRow r, scope SinkT s){ s(r.filename); })
	string filename;

	@Column!WorldRow("Size", 60, (WorldRow r, scope SinkT s){ formattedWrite(s, "%sB", scaledNumberFmt(r.fileSize)); })
	ulong fileSize;
}

struct ServerList
{
	Launcher* launcher;
	ServerRow opIndex(size_t i) { return ServerRow(*launcher.servers[i]); }
	size_t length() { return launcher.servers.length; }
}

struct ServerRow
{
	this(ServerInfo info) {
		this.name = info.name;
		this.ip = info.ip;
		this.port = info.port;
	}
	@Column!ServerRow("Name", 150, (ServerRow r, scope SinkT s){ s(r.name); })
	string name;
	@Column!ServerRow("IP", 130, (ServerRow r, scope SinkT s){ s(r.ip); })
	string ip;
	@Column!ServerRow("Port", 40, (ServerRow r, scope SinkT s){ formattedWrite(s, "%s", r.port); })
	ushort port;
}
