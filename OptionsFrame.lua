--[[ OptionsFrame.lua -- the concept's #options panel.

	One window, one scrolling body, sections top to bottom:

	  Race          a dropdown of your faction's races
	  Route pack    pills, with a preview of the route underneath
	  Dungeons      the chip grid
	  Filters       group mode and Auction House steps, as sliding switches
	  Server        a dropdown, with what is known about that server's data

	That is the concept. It used to be a menu of buttons that opened the
	dungeons, the filters and the route picker as three more windows; all of
	that lives here now, in the concept's language.

	The concept has no home for the addon's own behaviour settings, the
	waypoint provider or the maintenance actions, so they follow as three more
	sections in the same style -- the substitution is the extra sections, not
	a different look.
]]

local AegisPathfinder = AegisPathfinder
local ww = WidgetWarlock
local Theme = AegisPathfinder.Theme

-- Concept geometry: .panel{width:396px}, .options-body{padding:12px 14px 16px},
-- section{margin-bottom:16px}.
local WIDTH, HEIGHT = 396, 560
local HEADER_H, SUBHEAD_H = 30, 18
local CHROME_TOP = HEADER_H + SUBHEAD_H
local PAD_X, PAD_TOP, PAD_BOTTOM = 14, 12, 16
local SCROLL_W = 10
local BODY_W = WIDTH - PAD_X * 2 - SCROLL_W - 4
local SECTION_GAP = 16
local HEADER_GAP = 7                  -- h3 margin-bottom

-- The dungeon grid: four across in a 396px panel.
local CHIP_COLS, CHIP_GAP, CHIP_H = 4, 6, 34
local CHIP_W = math.floor((BODY_W - (CHIP_COLS - 1) * CHIP_GAP) / CHIP_COLS)

-- The route preview: .route-preview{max-height:150px}, rows of about 20px.
local PREVIEW_ROWS, PREVIEW_ROW_H = 7, 20
local PREVIEW_H = PREVIEW_ROWS * PREVIEW_ROW_H + 8

local DUNGEONS = {
	{ code = "RFC",       name = "Ragefire Chasm" },
	{ code = "WC",        name = "Wailing Caverns" },
	{ code = "DM",        name = "Deadmines" },
	{ code = "SFK",       name = "Shadowfang Keep" },
	{ code = "BFD",       name = "Blackfathom Deeps" },
	{ code = "STOCKADES", name = "The Stockade" },
	{ code = "GNOMER",    name = "Gnomeregan" },
	{ code = "RFK",       name = "Razorfen Kraul" },
	{ code = "SM",        name = "Scarlet Monastery" },
	{ code = "RFD",       name = "Razorfen Downs" },
	{ code = "ULDA",      name = "Uldaman" },
	{ code = "ZF",        name = "Zul'Farrak" },
	{ code = "MARA",      name = "Maraudon" },
	{ code = "ST",        name = "Sunken Temple" },
	{ code = "BRD",       name = "Blackrock Depths" },
}

-- Races each faction can be routed as. The value is the route name the
-- route packs are keyed by.
local RACES = {
	Alliance = {
		{ label = "Human",     route = "Human" },
		{ label = "Dwarf",     route = "Dwarf" },
		{ label = "Night Elf", route = "NightElf" },
		{ label = "Gnome",     route = "Gnome" },
		{ label = "High Elf",  route = "HighElf" },
	},
	Horde = {
		{ label = "Orc",    route = "Orc" },
		{ label = "Troll",  route = "Troll" },
		{ label = "Tauren", route = "Tauren" },
		{ label = "Undead", route = "Undead" },
		{ label = "Goblin", route = "Goblin" },
	},
}

--- Reload whichever guide is on screen so a filter change takes effect.
local function ReloadCurrentGuide()
	local self = AegisPathfinder
	if self:HasNoGuide() then return end
	self:LoadGuide(self.db.char.currentguide)
	self:UpdateStatusFrame()
end

function AegisPathfinder:CreateConfigPanel()
	local frame = CreateFrame("Frame", "AegisPathfinderOptions", UIParent)
	self.optionsframe = frame
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(WIDTH)
	frame:SetHeight(HEIGHT)
	-- .#options sits left of #objectives in the concept (right:456px against
	-- right:40px), so it opens beside the guide rather than over it.
	frame:SetPoint("TOPRIGHT", AegisPathfinder.objectiveframe, "TOPLEFT", -8, 0)
	Theme:Panel(frame, "panel")
	frame:Hide()

	Theme:Chrome(frame, "Config", Theme:PositionSaver("optionsframe"))

	-- The concept's header carries a ☰ on the left of this window too, titled
	-- "Back". Here it brings the guide forward.
	local back = Theme:ChipButton(frame.header, "menu")
	back:SetPoint("LEFT", frame.header, "LEFT", 8, 0)
	back:SetScript("OnClick", function()
		if not AegisPathfinder.objectiveframe:IsShown() then
			AegisPathfinder.objectiveframe:Show()
		end
	end)
	back:SetScript("OnEnter", function()
		this.fill:SetTint("text", 0.10)
		Theme:Tint(this.glyph, "text")
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Back to the guide")
	end)
	back:SetScript("OnLeave", function()
		this.fill:SetTint("text", 0.04)
		Theme:Tint(this.glyph, "textDim")
		GameTooltip:Hide()
	end)

	--[[ The scrolling body.

		The concept's .options-body is overflow-y:auto: seven sections do not
		fit a 560px window. A ScrollFrame holds them, the theme's scroll bar
		drives it, and the mouse wheel works anywhere over the panel.
	]]
	local scroll = CreateFrame("ScrollFrame", "AegisPathfinderOptionsScroll", frame)
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, -(CHROME_TOP + PAD_TOP))
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PAD_X + SCROLL_W), PAD_BOTTOM)

	local body = CreateFrame("Frame", nil, scroll)
	body:SetWidth(BODY_W)
	body:SetHeight(1)
	scroll:SetScrollChild(body)

	local bar = Theme:ScrollBar(frame, SCROLL_W)
	bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(CHROME_TOP + PAD_TOP + SCROLL_W))
	bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, PAD_BOTTOM + SCROLL_W)
	bar:SetMinMaxValues(0, 0)
	bar:SetValue(0)
	bar:SetScript("OnValueChanged", function() scroll:SetVerticalScroll(arg1 or 0) end)
	bar.up:SetScript("OnClick", function() bar:SetValue(math.max(0, bar:GetValue() - 40)) end)
	bar.down:SetScript("OnClick", function()
		local _, hi = bar:GetMinMaxValues()
		bar:SetValue(math.min(hi, bar:GetValue() + 40))
	end)

	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function()
		local _, hi = bar:GetMinMaxValues()
		local v = bar:GetValue() - (arg1 or 0) * 40
		if v < 0 then v = 0 elseif v > hi then v = hi end
		bar:SetValue(v)
	end)

	-- Lay the sections out top to bottom with a running cursor.
	local y = 0
	local function place(region, height, gap)
		region:ClearAllPoints()
		region:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
		y = y + height + (gap or 0)
	end
	local function section(title)
		local h = Theme:SectionHeader(body, title, BODY_W)
		place(h, 20, HEADER_GAP)
		return h
	end
	local function note(text)
		local fs = Theme:FinePrint(body, BODY_W)
		fs:SetText(text or "")
		place(fs, fs:GetHeight(), 0)
		return fs
	end

	frame.sections = {}

	-- Race -----------------------------------------------------------------------
	table.insert(frame.sections, section("Race"))
	local race = Theme:Dropdown(body, BODY_W, function(route)
		AegisPathfinder:SelectRoute(route)
		AegisPathfinder:RefreshConfigPanel()
	end)
	place(race, 30, SECTION_GAP)
	frame.race = race

	-- Route pack -------------------------------------------------------------------
	table.insert(frame.sections, section("Route pack"))

	-- One pill per pack this character can use, wrapping if they do not fit.
	local pillRow = CreateFrame("Frame", nil, body)
	pillRow:SetWidth(BODY_W)
	frame.packPills = {}
	local px, py = 0, 0
	for _, pack in ipairs(self:GetAvailableRoutePacks()) do
		local pill = Theme:Pill(pillRow, pack.displayName, 60, 26)
		pill:SetWidth(pill.label:GetStringWidth() + 26)
		if px > 0 and px + pill:GetWidth() > BODY_W then
			px, py = 0, py + 32
		end
		pill:SetPoint("TOPLEFT", pillRow, "TOPLEFT", px, -py)
		px = px + pill:GetWidth() + 6
		pill.packName = pack.name
		pill.description = pack.description
		pill:SetScript("OnClick", function()
			AegisPathfinder:SelectRoutePack(this.packName)
			AegisPathfinder:RefreshConfigPanel()
		end)
		pill:SetScript("OnEnter", function()
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetText(this.description, nil, nil, nil, nil, true)
		end)
		pill:SetScript("OnLeave", function() GameTooltip:Hide() end)
		table.insert(frame.packPills, pill)
	end
	pillRow:SetHeight(py + 26)
	place(pillRow, py + 26, 9)

	--[[ The route preview: level range and zone, one row per leg of the route
		this race takes under this pack. It scrolls on the mouse wheel, as the
		concept's max-height:150px list does. ]]
	local preview = CreateFrame("Frame", nil, body)
	preview:SetWidth(BODY_W)
	preview:SetHeight(PREVIEW_H)
	Theme:NineSlice(preview, Theme.texture.tabFill, "BACKGROUND", { 0, 0, 0 }, 0.25)
	Theme:NineSlice(preview, Theme.texture.tabBorder, "BORDER", "border")
	preview.rows, preview.offset, preview.entries = {}, 0, {}
	for i = 1, PREVIEW_ROWS do
		local row = CreateFrame("Frame", nil, preview)
		row:SetHeight(PREVIEW_ROW_H)
		row:SetPoint("TOPLEFT", preview, "TOPLEFT", 10, -(4 + (i - 1) * PREVIEW_ROW_H))
		row:SetPoint("RIGHT", preview, "RIGHT", -10, 0)
		row.lvl = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(row.lvl, "body2", 11)
		row.lvl:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.lvl:SetWidth(52)
		row.lvl:SetJustifyH("LEFT")
		Theme:TextColor(row.lvl, "accent")
		row.zone = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(row.zone, "body", 11)
		row.zone:SetPoint("LEFT", row.lvl, "RIGHT", 8, 0)
		row.zone:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		row.zone:SetJustifyH("LEFT")
		Theme:TextColor(row.zone, "textDim")
		preview.rows[i] = row
	end
	preview:EnableMouseWheel(true)
	preview:SetScript("OnMouseWheel", function()
		local maxOffset = math.max(0, table.getn(this.entries) - PREVIEW_ROWS)
		this.offset = math.max(0, math.min(maxOffset, this.offset - (arg1 or 0)))
		AegisPathfinder:DrawRoutePreview()
	end)
	place(preview, PREVIEW_H, SECTION_GAP)
	frame.preview = preview

	-- Dungeons ---------------------------------------------------------------------
	local dungeonHeader = section("Dungeons")
	local hint = dungeonHeader:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(hint, "body", 11)
	hint:SetPoint("LEFT", dungeonHeader.label, "RIGHT", 6, 0)
	hint:SetText("- RestedXP guides")
	Theme:TextColor(hint, "textDim")
	table.insert(frame.sections, dungeonHeader)

	local grid = CreateFrame("Frame", nil, body)
	grid:SetWidth(BODY_W)
	frame.chips = {}
	for idx, d in ipairs(DUNGEONS) do
		local chip = Theme:Chip(grid, d.code, d.name, CHIP_W, CHIP_H)
		local col = math.mod(idx - 1, CHIP_COLS)
		local row = math.floor((idx - 1) / CHIP_COLS)
		chip:SetPoint("TOPLEFT", grid, "TOPLEFT",
			col * (CHIP_W + CHIP_GAP), -(row * (CHIP_H + CHIP_GAP)))
		chip.dungeonCode = d.code
		local code, name = d.code, d.name
		chip:SetScript("OnClick", function()
			local on = not this:IsActive()
			this:SetActive(on)
			AegisPathfinder.db.char.Dungeons[code] = on
			ReloadCurrentGuide()
			AegisPathfinder:RefreshDungeonPanel()
		end)
		chip:SetScript("OnEnter", function()
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetText(name)
		end)
		chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
		table.insert(frame.chips, chip)
	end
	local gridRows = math.ceil(table.getn(DUNGEONS) / CHIP_COLS)
	local gridH = gridRows * (CHIP_H + CHIP_GAP) - CHIP_GAP
	grid:SetHeight(gridH)
	place(grid, gridH, 6)

	note("Toggling a dungeon on forces its setup and prerequisite steps to "
		.. "mandatory and reveals them in guides that reference it; toggling "
		.. "off hides them.")
	local wired = Theme:FinePrint(body, BODY_W)
	Theme:TextColor(wired, "blue")
	place(wired, 16, SECTION_GAP)
	frame.wiredHint = wired

	-- Filters ------------------------------------------------------------------------
	table.insert(frame.sections, section("Filters"))
	local group = Theme:Switch(body, "Group mode", function(on)
		AegisPathfinder.db.char.PlayStyle = on and "GROUP" or "SOLO"
		ReloadCurrentGuide()
		AegisPathfinder:RefreshConfigPanel()
	end)
	group:SetWidth(BODY_W)
	place(group, 22, 8)
	local ah = Theme:Switch(body, "Auction House steps", function(on)
		AegisPathfinder.db.char.UseAH = on
		ReloadCurrentGuide()
		AegisPathfinder:RefreshConfigPanel()
	end)
	ah:SetWidth(BODY_W)
	place(ah, 22, 6)
	local filterNote = Theme:FinePrint(body, BODY_W)
	place(filterNote, 16, SECTION_GAP)
	frame.groupSwitch, frame.ahSwitch, frame.filterNote = group, ah, filterNote

	-- Server -------------------------------------------------------------------------
	table.insert(frame.sections, section("Server"))
	local server = Theme:Dropdown(body, BODY_W, function(key)
		AegisPathfinder:SetCurrentServer(key)
		AegisPathfinder:RefreshConfigPanel()
	end)
	local serverItems = {}
	for _, info in ipairs(self.servers or {}) do
		table.insert(serverItems, { value = info.key, label = info.label })
	end
	server:SetItems(serverItems)
	place(server, 30, 6)
	local serverNote = Theme:FinePrint(body, BODY_W)
	place(serverNote, 44, SECTION_GAP)
	frame.server, frame.serverNote = server, serverNote

	-- Beyond the concept: the addon's own settings, in the same language. -------
	table.insert(frame.sections, section("Guide behaviour"))
	frame.switches = {}
	local BEHAVIOUR = {
		{ key = "autoquest",     label = "Accept and turn in quests automatically" },
		{ key = "trackquests",   label = "Track quests automatically" },
		{ key = "skipfollowups", label = "Skip suggested follow-ups" },
		{ key = "autobranch",    label = "Open custom-zone guides automatically" },
		{ key = "shownavcallout", label = "Navigation arrow" },
	}
	for _, def in ipairs(BEHAVIOUR) do
		local key = def.key
		local sw = Theme:Switch(body, def.label, function(on)
			AegisPathfinder.db.char[key] = on
			-- The arrow is the one setting with something on screen to update.
			if key == "shownavcallout" then AegisPathfinder:UpdateNavCallout() end
		end)
		sw:SetWidth(BODY_W)
		sw.settingKey = key
		place(sw, 22, 8)
		frame.switches[key] = sw
	end
	y = y + SECTION_GAP - 8

	table.insert(frame.sections, section("Waypoints"))
	local waypoints = Theme:Dropdown(body, BODY_W, function(name)
		AegisPathfinder:SetWaypointProvider(name)
		AegisPathfinder:RefreshConfigPanel()
	end)
	place(waypoints, 30, SECTION_GAP)
	frame.waypoints = waypoints

	table.insert(frame.sections, section("Maintenance"))
	local rescan = Theme:Pill(body, "Rescan progress", 140, 26)
	rescan:SetScript("OnClick", function() AegisPathfinder:QueryServerCompletedQuests(true) end)
	local errors = Theme:Pill(body, "Error log", 100, 26)
	errors:SetScript("OnClick", function() AegisPathfinder:ShowErrorLog() end)
	rescan:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
	errors:SetPoint("LEFT", rescan, "RIGHT", 6, 0)
	y = y + 26 + 6
	note("Rescan asks the server which quests this character has completed and "
		.. "re-marks the guide from that.")
	frame.rescan, frame.errorlog = rescan, errors

	--[[ Now the body's height is known, the scroll bar can be given its range:
		how far past the visible area the sections run. ]]
	y = y + PAD_BOTTOM
	body:SetHeight(y)
	frame.bodyHeight = y
	local visible = HEIGHT - CHROME_TOP - PAD_TOP - PAD_BOTTOM
	bar:SetMinMaxValues(0, math.max(0, y - visible))
	bar:SetValue(0)

	frame.scroll, frame.body, frame.scrollbar = scroll, body, bar

	frame:SetScript("OnShow", function()
		-- Snap beside the guide only while the player has not dragged this
		-- window somewhere of their own.
		if not Theme:RestorePosition(this, "optionsframe") then
			local _, _, hhalf = AegisPathfinder.GetQuadrant(AegisPathfinder.objectiveframe)
			this:ClearAllPoints()
			if hhalf == "LEFT" then
				this:SetPoint("TOPLEFT", AegisPathfinder.objectiveframe, "TOPRIGHT", 8, 0)
			else
				this:SetPoint("TOPRIGHT", AegisPathfinder.objectiveframe, "TOPLEFT", -8, 0)
			end
		end
		AegisPathfinder:RefreshConfigPanel()
		this:SetAlpha(0)
		this:SetScript("OnUpdate", ww.FadeIn)
	end)
	frame:SetScript("OnHide", function()
		race.list:Hide()
		server.list:Hide()
		waypoints.list:Hide()
	end)
	ww.SetFadeTime(frame, 0.5)

	table.insert(UISpecialFrames, "AegisPathfinderOptions")
end

--- Draw the visible slice of the route preview.
function AegisPathfinder:DrawRoutePreview()
	local preview = self.optionsframe and self.optionsframe.preview
	if not preview then return end
	for i, row in ipairs(preview.rows) do
		local entry = preview.entries[i + preview.offset]
		if entry then
			row.lvl:SetText(entry.levels or "")
			row.zone:SetText(entry.zone or entry.guide or "")
			row:Show()
		else
			row:Hide()
		end
	end
end

--- Bring every control into line with the saved settings.
function AegisPathfinder:RefreshConfigPanel()
	local frame = self.optionsframe
	if not frame then return end
	local db = self.db.char

	-- Race: this faction's races, the player's own marked.
	local faction = self.myfaction or "Alliance"
	local mine = self:GetRouteForRace()
	local items = {}
	for _, r in ipairs(RACES[faction] or RACES.Alliance) do
		local label = r.label .. " (" .. faction .. ")"
		if r.route == mine then label = label .. " - yours" end
		table.insert(items, { value = r.route, label = label })
	end
	frame.race:SetItems(items)
	frame.race:SetValue(db.currentroute or mine)

	-- Route pack, and the route it gives this race.
	local current = db.routepack or "VanillaGuide"
	for _, pill in ipairs(frame.packPills) do
		pill:SetActive(pill.packName == current)
	end
	local pack = self.routepacks and self.routepacks[current]
	local route = pack and pack.routes and pack.routes[db.currentroute or mine]
	frame.preview.entries = route or {}
	frame.preview.offset = 0
	self:DrawRoutePreview()

	self:RefreshDungeonPanel()

	-- Filters, and the one-line summary the concept prints under them.
	local grouped = (db.PlayStyle or "SOLO") == "GROUP"
	frame.groupSwitch:SetOn(grouped)
	frame.ahSwitch:SetOn(db.UseAH)
	frame.filterNote:SetText((grouped and "Group mode" or "Solo mode")
		.. " \194\183 Auction House steps " .. (db.UseAH and "shown" or "hidden"))

	-- Server, and what is known about guide data there.
	local key = self:GetCurrentServer()
	frame.server:SetValue(key)
	local info = self:GetServerInfo(key)
	local source = self:GetServerInfo(self.defaultDataSource)
	local lines = {}
	if info and info.dataset == "native" then
		table.insert(lines, "Guide data here is authored against " .. info.label .. ".")
	elseif info then
		table.insert(lines, "Guide data here is authored against "
			.. (source and source.label or "another server")
			.. " and has not been checked on " .. info.label
			.. ". Quest ids and coordinates may differ.")
	end
	if info then
		table.insert(lines, info.pfquest and ("pfQuest pack: " .. info.pfquest)
			or "No pfQuest pack confirmed for this server.")
	end
	frame.serverNote:SetText(table.concat(lines, " "))

	-- The addon's own switches.
	for key, sw in pairs(frame.switches) do
		sw:SetOn(db[key])
	end

	-- Waypoint providers actually loaded, plus automatic.
	local wp = { { value = "auto", label = "Automatic" } }
	for _, provider in ipairs(self:GetWaypointProviders()) do
		table.insert(wp, { value = provider.name, label = provider.label })
	end
	frame.waypoints:SetItems(wp)
	frame.waypoints:SetValue(db.waypointprovider or "auto")
end

--- Sync the dungeon chips with saved settings and with the loaded guide.
--
-- The blue dot marks a dungeon the current guide actually has |D| steps for,
-- which is the difference between "I could run this" and "this guide knows
-- about it". Without it every chip looks equally relevant no matter which
-- guide you are on.
function AegisPathfinder:RefreshDungeonPanel()
	local frame = self.optionsframe
	if not frame or not frame.chips then return end

	local wired = self:HasNoGuide() and {} or self:GetGuideDungeons()
	local wiredCount = 0

	for _, chip in ipairs(frame.chips) do
		chip:SetActive(self.db.char.Dungeons[chip.dungeonCode])
		local isWired = wired[chip.dungeonCode] and true or false
		chip:SetWired(isWired)
		if isWired then wiredCount = wiredCount + 1 end
	end

	if wiredCount > 0 then
		frame.wiredHint:SetText(string.format(
			"Dotted: %d referenced by this guide.", wiredCount))
	else
		frame.wiredHint:SetText("This guide has no dungeon steps.")
	end
end
