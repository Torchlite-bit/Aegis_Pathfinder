--[[ OptionsFrame.lua -- the concept's #options panel, in pages.

	Categories down the left, as Zygor's options have them; the page picked
	on the right, scrolling when it is taller than the window. The pages hold
	the concept's sections, in the concept's order:

	  Race          a dropdown of your faction's races
	  Route pack    pills, with a preview of the route underneath
	  Dungeons      the chip grid
	  Filters       group mode, Auction House steps and Solo Self-Found
	  Server theme  a dropdown: the colours of your server, or Day or Night

	That is the concept. It used to be a menu of buttons that opened the
	dungeons, the filters and the route picker as three more windows; all of
	that lives here now, in the concept's language.

	The concept has no home for the addon's own behaviour settings, the item
	score, the waypoint provider or the maintenance actions, so they follow as
	more sections in the same style -- the substitution is the extra sections, not
	a different look.

	  Route         Race, Route pack
	  Dungeons      Dungeons
	  Filters       Filters
	  Appearance    Server theme
	  Gear          the item score, the Gear Advisor, the Gear finder
	    Item Score  the stat weights (GearFrame.lua), listed under Gear
	  Behaviour     Guide behaviour
	  Navigation    Waypoints, Arrow
	  Maintenance   Maintenance
	  About         About, Credits
]]

local AegisPathfinder = AegisPathfinder
local ww = WidgetWarlock
local Theme = AegisPathfinder.Theme

-- Concept geometry: .panel{width:396px}, .options-body{padding:12px 14px 16px},
-- section{margin-bottom:16px}.
-- The pane keeps the concept's 396px; the category list sits beside it.
local PANE_W, HEIGHT = 396, 560
local NAV_W, NAV_ROW_H = 150, 30
local WIDTH = PANE_W + NAV_W
local HEADER_H, SUBHEAD_H = 30, 18
local CHROME_TOP = HEADER_H + SUBHEAD_H
local PAD_X, PAD_TOP, PAD_BOTTOM = 14, 12, 16
local SCROLL_W = 10
local BODY_W = PANE_W - PAD_X * 2 - SCROLL_W - 4
local SECTION_GAP = 16
local MIN_HEIGHT = 360                -- the grip goes no shorter; never narrower than WIDTH
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

--- How tall fine print is at `width`: what the client says, or, where it says
--- less, the lines its unwrapped width needs -- a wrapped font string's own
--- height is not to be trusted on 1.12. Slack for where the words break.
local function TextHeight(fs, width)
	local sw = fs:GetStringWidth() or 0
	local lines = sw <= width and 1 or math.ceil(sw / (width * 0.9))
	return math.max(fs:GetHeight() or 0, lines * 13)
end

--- Lay a page out again at `width`, from what `place` remembered: what wraps
--- takes its new height and everything under it moves up or down to suit.
local function Reflow(p, width)
	local y = 0
	for _, e in ipairs(p.flow) do
		if e.region then
			e.region:ClearAllPoints()
			e.region:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -y)
			y = y + (type(e.height) == "function" and e.height(width) or e.height)
		end
		y = y + e.gap
	end
	-- The Item Score page's list sets its own height.
	if not p.ownHeight then
		p.contentHeight = y + PAD_BOTTOM
		p:SetHeight(p.contentHeight)
	end
end

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
		Theme:ShowTip(this, "BOTTOM", "Back to the guide")
	end)
	back:SetScript("OnLeave", function()
		this.fill:SetTint("text", 0.04)
		Theme:Tint(this.glyph, "textDim")
		Theme:HideTip(this)
	end)

	--[[ The scrolling body.

		The concept's .options-body is overflow-y:auto: seven sections do not
		fit a 560px window. A ScrollFrame holds them, the theme's scroll bar
		drives it, and the mouse wheel works anywhere over the panel.
	]]
	local scroll = CreateFrame("ScrollFrame", "AegisPathfinderOptionsScroll", frame)
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", NAV_W + PAD_X, -(CHROME_TOP + PAD_TOP))
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PAD_X + SCROLL_W), PAD_BOTTOM)

	-- The scroll child holds every page; one is shown at a time, and the
	-- holder takes its height.
	local holder = CreateFrame("Frame", nil, scroll)
	holder:SetWidth(BODY_W)
	holder:SetHeight(1)
	scroll:SetScrollChild(holder)
	local body
	frame.pages = {}

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

	-- Lay the sections out top to bottom with a running cursor, a page at a
	-- time.
	local y = 0
	local function page(name, sub)
		if body then body.contentHeight = y + PAD_BOTTOM end
		body = CreateFrame("Frame", nil, holder)
		body:SetWidth(BODY_W)
		body:SetHeight(1)
		body:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
		body:Hide()
		body.pageName, body.sub = name, sub
		body.flow = {}
		table.insert(frame.pages, body)
		y = 0
	end
	-- What widens with the window, each with how to set it to a width.
	frame.stretch = {}
	local function stretchy(fit) table.insert(frame.stretch, fit) end
	--[[ Lay a region out under the last, and remember it, so the page can be
		laid out again at another width (Reflow). `height` is a number, or a
		function of the width for what wraps. ]]
	local function place(region, height, gap)
		table.insert(body.flow, { region = region, height = height, gap = gap or 0 })
		region:ClearAllPoints()
		region:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
		y = y + (type(height) == "function" and height(BODY_W) or height) + (gap or 0)
	end
	local function space(n)
		table.insert(body.flow, { gap = n })
		y = y + n
	end
	local function section(title)
		local h = Theme:SectionHeader(body, title, BODY_W)
		place(h, 20, HEADER_GAP)
		stretchy(function(w) h:SetWidth(w) end)
		return h
	end
	local function fine(fs)
		stretchy(function(w) fs:SetWidth(w) end)
		return fs
	end
	local function note(text)
		local fs = fine(Theme:FinePrint(body, BODY_W))
		fs:SetText(text or "")
		place(fs, function(w) return TextHeight(fs, w) end, 0)
		return fs
	end
	local function wide(dropdown)
		stretchy(function(w) dropdown:SetWidth(w); dropdown.list:SetWidth(w) end)
		return dropdown
	end

	frame.sections = {}

	-- Race -----------------------------------------------------------------------
	page("Route")
	table.insert(frame.sections, section("Race"))
	local race = Theme:Dropdown(body, BODY_W, function(route)
		AegisPathfinder:SelectRoute(route)
		AegisPathfinder:RefreshConfigPanel()
	end)
	place(race, 30, SECTION_GAP)
	wide(race)
	frame.race = race

	-- Route pack -------------------------------------------------------------------
	table.insert(frame.sections, section("Route pack"))

	-- One pill per pack this character can use, wrapping if they do not fit.
	local pillRow = CreateFrame("Frame", nil, body)
	pillRow:SetWidth(BODY_W)
	stretchy(function(w) pillRow:SetWidth(w) end)
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
			Theme:ShowTip(this, "RIGHT", this.description)
		end)
		pill:SetScript("OnLeave", function() Theme:HideTip(this) end)
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
	stretchy(function(w) preview:SetWidth(w) end)
	frame.preview = preview

	-- Dungeons ---------------------------------------------------------------------
	page("Dungeons")
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
			if AegisPathfinder.db.char.SelfFound then return end
			local on = not this:IsActive()
			this:SetActive(on)
			AegisPathfinder.db.char.Dungeons[code] = on
			ReloadCurrentGuide()
			AegisPathfinder:RefreshDungeonPanel()
		end)
		chip:SetScript("OnEnter", function()
			Theme:ShowTip(this, "RIGHT", name)
		end)
		chip:SetScript("OnLeave", function() Theme:HideTip(this) end)
		table.insert(frame.chips, chip)
	end
	local gridRows = math.ceil(table.getn(DUNGEONS) / CHIP_COLS)
	local gridH = gridRows * (CHIP_H + CHIP_GAP) - CHIP_GAP
	grid:SetHeight(gridH)
	place(grid, gridH, 6)

	note("Toggling a dungeon on forces its setup and prerequisite steps to "
		.. "mandatory and reveals them in guides that reference it; toggling "
		.. "off hides them.")
	local wired = fine(Theme:FinePrint(body, BODY_W))
	Theme:TextColor(wired, "blue")
	place(wired, 16, SECTION_GAP)
	frame.wiredHint = wired

	-- Filters ------------------------------------------------------------------------
	page("Filters")
	table.insert(frame.sections, section("Filters"))
	local group = Theme:Switch(body, "Group mode", function(on)
		AegisPathfinder.db.char.PlayStyle = on and "GROUP" or "SOLO"
		ReloadCurrentGuide()
		AegisPathfinder:RefreshConfigPanel()
	end)
	place(group, function(w) return group:Fit(w) end, 8)
	local ah = Theme:Switch(body, "Auction House steps", function(on)
		AegisPathfinder.db.char.UseAH = on
		ReloadCurrentGuide()
		AegisPathfinder:RefreshConfigPanel()
	end)
	place(ah, function(w) return ah:Fit(w) end, 6)
	-- RestedXP's Solo Self-Found mode: alone, no trading, no Auction House.
	-- It holds group mode, the Auction House and the dungeons off while it is
	-- on, and gives them back as they were.
	local ssf = Theme:Switch(body, "Solo Self-Found", function(on)
		AegisPathfinder:SetSelfFound(on)
	end)
	ssf:SetScript("OnEnter", function()
		Theme:ShowTip(this, "RIGHT", "Solo Self-Found",
			{ "Play alone: hides group quests, dungeons, and every step that trades with other players or uses the Auction House. Their switches are held off until you turn this off." })
	end)
	ssf:SetScript("OnLeave", function() Theme:HideTip(this) end)
	place(ssf, function(w) return ssf:Fit(w) end, 6)
	local filterNote = fine(Theme:FinePrint(body, BODY_W))
	place(filterNote, 30, SECTION_GAP)
	frame.groupSwitch, frame.ahSwitch, frame.ssfSwitch, frame.filterNote = group, ah, ssf, filterNote

	--[[ Server theme: the colours of your server, or Day or Night. Colours
		only -- the guides are the same on every server. It took the place of
		the Server dropdown. ]]
	page("Appearance")
	table.insert(frame.sections, section("Server theme"))
	local theme = Theme:Dropdown(body, BODY_W, function(key)
		AegisPathfinder:SetTheme(key)
	end)
	local themeItems = {}
	for _, def in ipairs(Theme.THEMES) do
		table.insert(themeItems, { value = def.key, label = def.label })
	end
	theme:SetItems(themeItems)
	place(theme, 30, 6)
	wide(theme)
	local themeNote = fine(Theme:FinePrint(body, BODY_W))
	place(themeNote, 44, SECTION_GAP)
	frame.theme, frame.themeNote = theme, themeNote

	--[[ Gear: the item score on tooltips, and the window with its weights. ]]
	page("Gear")
	table.insert(frame.sections, section("Gear"))
	local scoreTips = Theme:Switch(body, "Item score on tooltips", function(on)
		AegisPathfinder.ItemScore.Settings().tooltips = on
	end)
	place(scoreTips, function(w) return scoreTips:Fit(w) end, 6)
	local weights = Theme:Pill(body, "Stat weights", 120, 26)
	weights:SetScript("OnClick", function()
		AegisPathfinder:ShowConfigPage(AegisPathfinder.ITEM_SCORE_PAGE)
	end)
	place(weights, 26, 6)
	note("Each item's tooltip shows what it is worth to your spec and how it "
		.. "compares with what you wear. The weights come from OctoPawn; change "
		.. "them, or pick another spec, under Item Score.")
	space(10)
	-- The Gear Advisor's switches (GearAdvisor.lua), Zygor's in this style.
	frame.advisor = {}
	local ADVISOR = {
		{ key = "enabled",   label = "Gear Advisor: tell me about upgrades" },
		{ key = "maxlevel",  label = "Turn it off at level 60" },
		{ key = "popups",    label = "Pop up new upgrades as I pick them up" },
		{ key = "autoequip", label = "Equip upgrades for me (never one that binds)" },
		{ key = "questmark", label = "Mark the best quest reward" },
		{ key = "questpick", label = "Pick it for me when quests turn in by themselves" },
		{ key = "bagmark",   label = "Border upgrades in my bags" },
	}
	for _, def in ipairs(ADVISOR) do
		local key = def.key
		local sw = Theme:Switch(body, def.label, function(on)
			AegisPathfinder.GearAdvisor.Settings()[key] = on
			AegisPathfinder.GearAdvisor:Dirty()
			AegisPathfinder:RefreshConfigPanel()
		end)
		place(sw, function(w) return sw:Fit(w) end, 6)
		frame.advisor[key] = sw
	end
	local clearDeclined = Theme:Pill(body, "Clear declined items", 150, 26)
	clearDeclined:SetScript("OnClick", function()
		AegisPathfinder.GearAdvisor:ClearDeclined()
		AegisPathfinder:Print("Declined upgrades cleared: they will be offered again.")
	end)
	place(clearDeclined, 26, 10)
	-- The Gear Finder (GearFinder.lua): upgrades in the dungeons you run.
	frame.finder = {}
	for _, def in ipairs({
		{ key = "enabled",  label = "Gear finder: upgrades from the dungeons I run" },
		{ key = "announce", label = "Name the upgrades when I walk into a dungeon" },
	}) do
		local key = def.key
		local sw = Theme:Switch(body, def.label, function(on)
			AegisPathfinder.GearFinder.Settings()[key] = on
			AegisPathfinder:RefreshConfigPanel()
		end)
		place(sw, function(w) return sw:Fit(w) end, 6)
		frame.finder[key] = sw
	end
	local openFinder = Theme:Pill(body, "Gear finder", 110, 26)
	openFinder:SetScript("OnClick", function() AegisPathfinder:ToggleGearFinder() end)
	place(openFinder, 26, 6)
	note("It looks in the dungeons at or a little above your level that are "
		.. "ticked under Dungeons, Turtle WoW's own included, and in raids if you "
		.. "ask it to.")
	space(SECTION_GAP)
	frame.scoreTips, frame.weightsButton, frame.clearDeclined = scoreTips, weights, clearDeclined
	frame.openFinder = openFinder

	--[[ Item Score: the weights, as Zygor lists them under Gear. The page is
		GearFrame.lua's; it sets its own height as its list changes. ]]
	page(AegisPathfinder.ITEM_SCORE_PAGE, true)
	table.insert(frame.sections, section("Item score"))
	local scorePage = AegisPathfinder:CreateItemScorePage(body, BODY_W, y, PAD_BOTTOM)
	body.ownHeight = true
	stretchy(function(w) scorePage:Resize(w) end)

	-- Beyond the concept: the addon's own settings, in the same language. -------
	page("Behaviour")
	table.insert(frame.sections, section("Guide behaviour"))
	frame.switches = {}
	local BEHAVIOUR = {
		{ key = "autoquest",     label = "Accept and turn in quests automatically" },
		{ key = "trackquests",   label = "Track quests automatically" },
		{ key = "skipfollowups", label = "Skip suggested follow-ups" },
		{ key = "offercustomzones", label = "Offer custom zones between guides" },
		{ key = "showminimapbutton", label = "Minimap button" },
		{ key = "showactiveitems", label = "Active items window" },
		{ key = "showactivetargets", label = "Active targets window" },
		{ key = "showmacros", label = "Macros window (AegisTarget, AegisItem)" },
		{ key = "questicons", label = "Quest icons: mark quest NPCs as you mouse over them" },
	}
	for _, def in ipairs(BEHAVIOUR) do
		local key = def.key
		local sw = Theme:Switch(body, def.label, function(on)
			AegisPathfinder.db.char[key] = on
			-- The settings with something on screen to update.
			if key == "showminimapbutton" then AegisPathfinder:UpdateMinimapButton() end
			if key == "showactiveitems" or key == "showactivetargets" or key == "showmacros"
				or key == "questicons" then
				AegisPathfinder:RefreshActiveFrames()
			end
		end)
		sw.settingKey = key
		place(sw, function(w) return sw:Fit(w) end, 8)
		frame.switches[key] = sw
	end
	space(SECTION_GAP - 8)

	page("Navigation")
	table.insert(frame.sections, section("Waypoints"))
	local waypoints = Theme:Dropdown(body, BODY_W, function(name)
		AegisPathfinder:SetWaypointProvider(name)
		AegisPathfinder:RefreshConfigPanel()
	end)
	place(waypoints, 30, SECTION_GAP)
	wide(waypoints)
	frame.waypoints = waypoints

	--[[ Whose arrow points at the step: ours, the waypoint addon's, both, or
		neither. It replaced a lone "Navigation arrow" switch, which left the
		waypoint addon's arrow pointing too -- two arrows, one place. ]]
	table.insert(frame.sections, section("Arrow"))
	local arrow = Theme:Dropdown(body, BODY_W, function(mode)
		AegisPathfinder:SetArrowMode(mode)
		AegisPathfinder:RefreshConfigPanel()
	end)
	arrow:SetItems(AegisPathfinder.ARROW_MODES)
	place(arrow, 30, 6)
	wide(arrow)
	local arrowNote = fine(Theme:FinePrint(body, BODY_W))
	place(arrowNote, 30, SECTION_GAP)
	frame.arrow, frame.arrowNote = arrow, arrowNote

	page("Maintenance")
	table.insert(frame.sections, section("Maintenance"))
	local rescan = Theme:Pill(body, "Rescan progress", 140, 26)
	rescan:SetScript("OnClick", function() AegisPathfinder:QueryServerCompletedQuests(true) end)
	local errors = Theme:Pill(body, "Error log", 100, 26)
	errors:SetScript("OnClick", function() AegisPathfinder:ShowErrorLog() end)
	local setup = Theme:Pill(body, "Run setup", 90, 26)
	setup:SetScript("OnClick", function() AegisPathfinder:ShowSetup() end)
	place(rescan, 26, 6)
	errors:SetPoint("LEFT", rescan, "RIGHT", 6, 0)
	setup:SetPoint("LEFT", errors, "RIGHT", 6, 0)
	note("Rescan asks the server which quests this character has completed and "
		.. "re-marks the guide from that. Run setup asks the first-time questions "
		.. "again: your guide, its features and your dungeons.")
	frame.rescan, frame.errorlog, frame.setup = rescan, errors, setup
	space(SECTION_GAP)

	-- Last, where an about box goes: who this addon is built on.
	page("About")
	table.insert(frame.sections, section("About"))
	frame.version = note("Version v" .. (AegisPathfinder.version or "?") .. " -- quote it in bug reports.")
	space(4)
	note("Aegis: Pathfinder is built on other people's work -- TourGuide, "
		.. "VanillaGuide, ClassicAPI, Joana's routes and more.")
	space(6)
	local credits = Theme:Pill(body, "Credits", 90, 26)
	credits:SetScript("OnClick", function() AegisPathfinder:ToggleCredits() end)
	place(credits, 26, 0)
	frame.credits = credits

	-- Each page's height is known now: what the scroll bar ranges over.
	body.contentHeight = y + PAD_BOTTOM
	for _, p in ipairs(frame.pages) do p:SetHeight(p.contentHeight) end
	frame.visible = HEIGHT - CHROME_TOP - PAD_TOP - PAD_BOTTOM
	frame.scroll, frame.holder, frame.scrollbar = scroll, holder, bar
	-- Their lists hang off UIParent, so they are closed by hand when the
	-- page or the window goes.
	frame.dropdowns = { race, theme, waypoints, arrow, scorePage.spec }

	--[[ The categories, down the left: Zygor's list, in this style -- a
		quieter column than the page, the page shown marked with an accent
		bar and the text brightened. ]]
	local nav = CreateFrame("Frame", nil, frame)
	nav:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -CHROME_TOP)
	nav:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	nav:SetWidth(NAV_W)
	local navBg = nav:CreateTexture(nil, "BACKGROUND")
	navBg:SetTexture(Theme.texture.solid)
	navBg:SetAllPoints(nav)
	Theme:Tint(navBg, "text", 0.03)
	local navEdge = nav:CreateTexture(nil, "BORDER")
	navEdge:SetTexture(Theme.texture.solid)
	navEdge:SetPoint("TOPRIGHT", nav, "TOPRIGHT", 0, 0)
	navEdge:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", 0, 0)
	navEdge:SetWidth(1)
	Theme:Tint(navEdge, "text", 0.08)
	frame.nav, frame.navButtons = nav, {}
	for i, p in ipairs(frame.pages) do
		local b = CreateFrame("Button", nil, nav)
		b:SetHeight(NAV_ROW_H)
		b:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -(8 + (i - 1) * NAV_ROW_H))
		b:SetPoint("RIGHT", nav, "RIGHT", -1, 0)
		local fill = b:CreateTexture(nil, "BACKGROUND")
		fill:SetTexture(Theme.texture.solid)
		fill:SetAllPoints(b)
		local mark = b:CreateTexture(nil, "ARTWORK")
		mark:SetTexture(Theme.texture.solid)
		mark:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
		mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
		mark:SetWidth(3)
		Theme:Tint(mark, "accent")
		local label = b:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(label, "body", 13)
		-- A page that belongs to the one above it sits in under it.
		if p.sub then Theme:SetFont(label, "body", 12) end
		label:SetPoint("LEFT", b, "LEFT", p.sub and 28 or 14, 0)
		label:SetText(p.pageName)
		b.fill, b.mark, b.label, b.pageName = fill, mark, label, p.pageName
		function b:SetActive(on)
			self.active = on
			Theme:Tint(self.fill, "text", on and 0.08 or 0)
			if on then self.mark:Show() else self.mark:Hide() end
			Theme:TextColor(self.label, on and "text" or "textDim")
		end
		b:SetScript("OnClick", function() AegisPathfinder:ShowConfigPage(this.pageName) end)
		b:SetScript("OnEnter", function() if not this.active then Theme:Tint(this.fill, "text", 0.04) end end)
		b:SetScript("OnLeave", function() if not this.active then Theme:Tint(this.fill, "text", 0) end end)
		b:SetActive(false)
		frame.navButtons[i] = b
	end
	--[[ Resize grip, bottom right, as the guide has: drag it to make the
		window wider or taller. It sizes the window itself rather than calling
		StartSizing, for the reason the guide's grip gives (ObjectivesFrame.lua):
		the client's sizing re-anchors the frame as it sees fit. ]]
	local grip = CreateFrame("Frame", nil, frame)
	grip:SetWidth(12)
	grip:SetHeight(12)
	grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	grip:EnableMouse(true)
	grip:SetFrameLevel(frame:GetFrameLevel() + 6)
	local gripTex = grip:CreateTexture(nil, "OVERLAY")
	gripTex:SetTexture(Theme.texture.grip)
	gripTex:SetAllPoints(grip)
	Theme:Tint(gripTex, "textDim", 0.55)
	local function cursor()
		local scale = frame:GetEffectiveScale()
		local x, y = GetCursorPosition()
		return x / scale, y / scale
	end
	local function stop()
		grip.sizing = nil
		grip:SetScript("OnUpdate", nil)
		Theme:Tint(gripTex, "textDim", 0.55)
	end
	local function sizing()
		local s = grip.sizing
		if not s then return end
		-- A button let go somewhere the grip never heard about still ends it.
		if s.poll and not IsMouseButtonDown("LeftButton") then return stop() end
		local x, y = cursor()
		-- Screen y grows upward: dragging down is a smaller y, a taller window.
		AegisPathfinder:SizeConfigWindow(s.w + x - s.x, s.h + s.y - y, true)
	end
	grip:SetScript("OnMouseDown", function()
		Theme:Tint(gripTex, "accentGlow", 1)
		-- Grow right and down from where the window is, however it was anchored.
		Theme:AnchorTopLeft(frame)
		local x, y = cursor()
		grip.sizing = { x = x, y = y, w = frame:GetWidth(), h = frame:GetHeight(),
			poll = IsMouseButtonDown and IsMouseButtonDown("LeftButton") and true or false }
		grip:SetScript("OnUpdate", sizing)
	end)
	grip:SetScript("OnMouseUp", function()
		sizing()
		stop()
	end)
	grip:SetScript("OnEnter", function()
		Theme:Tint(gripTex, "accent", 1)
		Theme:ShowTip(this, "LEFT", "Drag to resize")
	end)
	grip:SetScript("OnLeave", function()
		if not grip.sizing then Theme:Tint(gripTex, "textDim", 0.55) end
		Theme:HideTip(this)
	end)
	frame.grip, frame.bodyW = grip, BODY_W

	-- The size it was left at.
	self:SizeConfigWindow(self.db.profile.optionswidth, self.db.profile.optionsheight)
	self:ShowConfigPage(frame.pages[1].pageName)

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
		-- The credits open from here, and close with it.
		if AegisPathfinder.creditsframe then AegisPathfinder.creditsframe:Hide() end
		for _, d in ipairs(this.dropdowns) do d.list:Hide() end
	end)
	ww.SetFadeTime(frame, 0.5)

	table.insert(UISpecialFrames, "AegisPathfinderOptions")
end

--- The options window at `w` by `h` -- no narrower than it opens, no shorter
--- than MIN_HEIGHT, no bigger than the screen -- with every page's contents
--- widened to fit and the scroll range to match. `save` keeps the size.
function AegisPathfinder:SizeConfigWindow(w, h, save)
	local frame = self.optionsframe
	if not frame then return end
	w = math.floor(math.max(WIDTH, math.min(w or WIDTH, UIParent:GetWidth() - 40)) + 0.5)
	h = math.floor(math.max(MIN_HEIGHT, math.min(h or HEIGHT, UIParent:GetHeight() - 40)) + 0.5)
	frame:SetWidth(w)
	frame:SetHeight(h)
	local bodyW = w - NAV_W - PAD_X * 2 - SCROLL_W - 4
	if bodyW ~= frame.bodyW then
		frame.bodyW = bodyW
		frame.holder:SetWidth(bodyW)
		for _, p in ipairs(frame.pages) do p:SetWidth(bodyW) end
		for _, fit in ipairs(frame.stretch) do fit(bodyW) end
		for _, p in ipairs(frame.pages) do Reflow(p, bodyW) end
	end
	frame.visible = h - CHROME_TOP - PAD_TOP - PAD_BOTTOM
	self:SizeConfigPage(true)
	if save then
		self.db.profile.optionswidth, self.db.profile.optionsheight = w, h
	end
end

--- Show one page of the options panel: its content on the right, its name
--- marked in the list and in the header strip, scrolled to the top.
function AegisPathfinder:ShowConfigPage(name)
	local frame = self.optionsframe
	if not frame then return end
	local shown
	for _, p in ipairs(frame.pages) do
		if p.pageName == name then shown = p end
	end
	shown = shown or frame.pages[1]
	for _, p in ipairs(frame.pages) do
		if p == shown then p:Show() else p:Hide() end
	end
	for _, d in ipairs(frame.dropdowns) do d.list:Hide() end
	frame.page = shown.pageName
	if shown.refresh then shown.refresh() end
	self:SizeConfigPage()
	for _, b in ipairs(frame.navButtons) do b:SetActive(b.pageName == frame.page) end
	frame.subhead.label:SetText("CONFIG \194\183 " .. string.upper(frame.page))
end

--- Fit the scroll range to the page shown: from its top, or, with `keep`,
--- staying where it is (a page whose height just changed under you).
function AegisPathfinder:SizeConfigPage(keep)
	local frame = self.optionsframe
	if not (frame and frame.page) then return end
	local shown
	for _, p in ipairs(frame.pages) do
		if p.pageName == frame.page then shown = p end
	end
	frame.holder:SetHeight(shown.contentHeight)
	frame.scroll:UpdateScrollChildRect()
	local over = math.max(0, shown.contentHeight - frame.visible)
	frame.scrollbar:SetMinMaxValues(0, over)
	local v = keep and math.min(frame.scrollbar:GetValue(), over) or 0
	frame.scrollbar:SetValue(v)
	frame.scroll:SetVerticalScroll(v)
	if over > 0 then frame.scrollbar:Show() else frame.scrollbar:Hide() end
end

--- Open the options panel, or close it if it is open. The header's menu chip
--- and a right-click on the minimap button both land here.
function AegisPathfinder:ToggleConfigPanel()
	if not self.optionsframe then self:CreateConfigPanel() end
	if self.optionsframe:IsShown() then
		self.optionsframe:Hide()
	else
		self.optionsframe:Show()
	end
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
	-- Solo Self-Found holds group mode, the Auction House and the dungeons off.
	local grouped = (db.PlayStyle or "SOLO") == "GROUP" and not db.SelfFound
	frame.groupSwitch:SetOn(grouped)
	frame.groupSwitch:SetLocked(db.SelfFound)
	frame.ahSwitch:SetOn(db.UseAH and not db.SelfFound)
	frame.ahSwitch:SetLocked(db.SelfFound)
	frame.ssfSwitch:SetOn(db.SelfFound)
	frame.scoreTips:SetOn(self.ItemScore.Settings().tooltips)
	self:UpdateItemScorePage()
	local finder = self.GearFinder.Settings()
	for key, sw in pairs(frame.finder) do
		sw:SetOn(finder[key])
		sw:SetLocked(key ~= "enabled" and not finder.enabled)
	end
	local advisor = self.GearAdvisor.Settings()
	for key, sw in pairs(frame.advisor) do
		sw:SetOn(advisor[key])
		-- The rest of the advisor's switches mean nothing with it off.
		sw:SetLocked(key ~= "enabled" and not advisor.enabled)
	end
	frame.filterNote:SetText(db.SelfFound
		and "Solo Self-Found \194\183 no group quests, dungeons, trading or Auction House steps"
		or ((grouped and "Group mode" or "Solo mode") .. " \194\183 Auction House steps "
			.. (db.UseAH and "shown" or "hidden")))

	-- The theme, and what it looks like.
	local def = Theme.themeByKey[self:GetTheme()]
	frame.theme:SetValue(def.key)
	frame.themeNote:SetText(def.note)

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

	frame.arrow:SetValue(self:GetArrowMode())
	local provider = self:GetWaypointProvider()
	if provider and provider.arrowIsWaypoint then
		frame.arrowNote:SetText(provider.label .. "'s waypoint is its arrow, so it points "
			.. "whichever you pick here.")
	else
		frame.arrowNote:SetText("Pathfinder's floats at the top of the screen. The waypoint "
			.. "addon keeps its map pins either way.")
	end
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

	local ssf = self.db.char.SelfFound
	for _, chip in ipairs(frame.chips) do
		chip:SetActive(self.db.char.Dungeons[chip.dungeonCode] and not ssf)
		chip:SetLocked(ssf)
		local isWired = wired[chip.dungeonCode] and true or false
		chip:SetWired(isWired)
		if isWired then wiredCount = wiredCount + 1 end
	end

	if ssf then
		frame.wiredHint:SetText("Solo Self-Found is on: no dungeons until it is off.")
	elseif wiredCount > 0 then
		frame.wiredHint:SetText(string.format(
			"Dotted: %d referenced by this guide.", wiredCount))
	else
		frame.wiredHint:SetText("This guide has no dungeon steps.")
	end
end
