local AegisPathfinder = AegisPathfinder
local L = AegisPathfinder.Locale
local ww = WidgetWarlock
local Theme = AegisPathfinder.Theme

-- Dungeon chip grid geometry.
local CHIP_W, CHIP_H, CHIP_GAP, CHIP_PAD = 78, 34, 6, 12
local CHIP_COLS = 3

-- The concept's window chrome: a 30px header carrying the wordmark and the
-- close chip, and an 18px subhead naming the window. Everything a panel draws
-- starts below it.
local HEADER_H, SUBHEAD_H = 30, 18
local CHROME_TOP = HEADER_H + SUBHEAD_H
local CHIP_TOP = CHROME_TOP + 20   -- below the chrome and the grid's hint

function AegisPathfinder:CreateConfigPanel()
	local frame = CreateFrame("Frame", "AegisPathfinderOptions", UIParent)
	AegisPathfinder.optionsframe = frame
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(310)
	frame:SetHeight(CHROME_TOP + 16 + 28 * 8)
	frame:SetPoint("TOPRIGHT", AegisPathfinder.statusframe, "BOTTOMRIGHT")
	Theme:Panel(frame, "panel")
	frame:Hide()

	Theme:Chrome(frame, "Config", Theme:PositionSaver("optionsframe"))

	local qtrack = ww.SummonCheckBox(22, frame, "TOPLEFT", 5, -(CHROME_TOP + 5))
	ww.SummonFontString(qtrack, "OVERLAY", "GameFontNormalSmall", L["Automatically track quests"], "LEFT", qtrack,
		"RIGHT", 5, 0)
	qtrack:SetScript("OnClick", function() self.db.char.trackquests = not self.db.char.trackquests end)

	local qskipfollowups = ww.SummonCheckBox(22, qtrack, "TOPLEFT", 0, -20)
	ww.SummonFontString(qskipfollowups, "OVERLAY", "GameFontNormalSmall", L["Automatically skip suggested follow-ups"],
		"LEFT", qskipfollowups, "RIGHT", 5, 0)
	qskipfollowups:SetScript("OnClick", function() self.db.char.skipfollowups = not self.db.char.skipfollowups end)

	local autobranch = ww.SummonCheckBox(22, qskipfollowups, "TOPLEFT", 0, -20)
	ww.SummonFontString(autobranch, "OVERLAY", "GameFontNormalSmall", "Auto-branch to custom zones", "LEFT",
		autobranch, "RIGHT", 5, 0)
	autobranch:SetScript("OnClick", function() self.db.char.autobranch = not self.db.char.autobranch end)

	-- Waypoint provider: cycles through "auto" plus every waypoint addon loaded
	local waypointBtn = Theme:PanelButton(frame)
	waypointBtn:SetWidth(286)
	waypointBtn:SetHeight(22)
	waypointBtn:SetPoint("TOPLEFT", autobranch, "BOTTOMLEFT", 0, -10)
	waypointBtn:SetScript("OnClick", function()
		AegisPathfinder:CycleWaypointProvider()
		waypointBtn:SetText(L["Waypoints"] .. ": " .. AegisPathfinder:GetWaypointProviderLabel())
	end)
	frame.waypointBtn = waypointBtn

	-- Route selector button
	local routeBtn = Theme:PanelButton(frame)
	routeBtn:SetWidth(150)
	routeBtn:SetHeight(22)
	routeBtn:SetPoint("TOPLEFT", waypointBtn, "BOTTOMLEFT", 0, -6)
	routeBtn:SetText("Change Route")
	routeBtn:SetScript("OnClick", function()
		frame:Hide()
		AegisPathfinder:ShowRouteSelector()
	end)

	local dungeonsBtn = Theme:PanelButton(frame)
	dungeonsBtn:SetWidth(130)
	dungeonsBtn:SetHeight(22)
	dungeonsBtn:SetPoint("LEFT", routeBtn, "RIGHT", 6, 0)
	dungeonsBtn:SetText("Dungeons RXP")
	dungeonsBtn:SetScript("OnClick", function()
		AegisPathfinder:ToggleDungeonPanel()
	end)
	frame.dungeonsBtn = dungeonsBtn

	local branchBtn = Theme:PanelButton(frame)
	branchBtn:SetWidth(150)
	branchBtn:SetHeight(22)
	branchBtn:SetPoint("TOPLEFT", routeBtn, "BOTTOMLEFT", 0, -6)
	branchBtn:SetText("Branch to Zone")
	branchBtn:SetScript("OnClick", function()
		frame:Hide()
		AegisPathfinder:ShowGuideList(true)
	end)
	frame.branchBtn = branchBtn

	local returnMainBtn = Theme:PanelButton(frame)
	returnMainBtn:SetWidth(130)
	returnMainBtn:SetHeight(22)
	returnMainBtn:SetPoint("LEFT", branchBtn, "RIGHT", 6, 0)
	returnMainBtn:SetText("Return to Main")
	returnMainBtn:SetScript("OnClick", function()
		AegisPathfinder:ReturnFromBranch()
		frame:Hide()
	end)
	frame.returnMainBtn = returnMainBtn

	local refreshBtn = Theme:PanelButton(frame)
	refreshBtn:SetWidth(150)
	refreshBtn:SetHeight(22)
	refreshBtn:SetPoint("TOPLEFT", branchBtn, "BOTTOMLEFT", 0, -6)
	refreshBtn:SetText("Rescan Progress")
	refreshBtn:SetScript("OnClick", function()
		AegisPathfinder:QueryServerCompletedQuests(true)
	end)

	local errorBtn = Theme:PanelButton(frame)
	errorBtn:SetWidth(130)
	errorBtn:SetHeight(22)
	errorBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 6, 0)
	errorBtn:SetText("Error Log")
	errorBtn:SetScript("OnClick", function()
		frame:Hide()
		AegisPathfinder:ShowErrorLog()
	end)

	local filtersBtn = Theme:PanelButton(frame)
	filtersBtn:SetWidth(286)
	filtersBtn:SetHeight(22)
	filtersBtn:SetPoint("TOPLEFT", refreshBtn, "BOTTOMLEFT", 0, -6)
	filtersBtn:SetText("Filters (Solo/Group/AH) RXP")
	filtersBtn:SetScript("OnClick", function()
		AegisPathfinder:ToggleFiltersPanel()
	end)
	frame.filtersBtn = filtersBtn

	frame.qtrack = qtrack
	frame.qskipfollowups = qskipfollowups
	frame.autobranch = autobranch

	local function OnShow(f)
		f = f or this
		-- Snap beside the status card only while the player has not dragged
		-- this window somewhere of their own.
		if not Theme:RestorePosition(f, "optionsframe") then
			local quad, vhalf, hhalf = self.GetQuadrant(self.statusframe)
			local anchpoint = (vhalf == "TOP" and "BOTTOM" or "TOP") .. hhalf
			f:ClearAllPoints()
			f:SetPoint(quad, self.statusframe, anchpoint)
		end

		f.qtrack:SetChecked(self.db.char.trackquests)
		f.qskipfollowups:SetChecked(self.db.char.skipfollowups)
		f.autobranch:SetChecked(self.db.char.autobranch)
		f.waypointBtn:SetText(L["Waypoints"] .. ": " .. self:GetWaypointProviderLabel())

		-- Enable/disable return button based on branch status
		if self.db.char.isbranching then
			f.returnMainBtn:Enable()
			f.returnMainBtn:SetText("Return to Main")
		else
			f.returnMainBtn:Disable()
			f.returnMainBtn:SetText("(Not branching)")
		end
		f:SetAlpha(0)
		f:SetScript("OnUpdate", ww.FadeIn)
	end

	frame:SetScript("OnShow", OnShow)
	frame:SetScript("OnHide", function()
		if AegisPathfinder.dungeonframe then
			AegisPathfinder.dungeonframe:Hide()
		end
		if AegisPathfinder.filtersframe then
			AegisPathfinder.filtersframe:Hide()
		end
	end)
	ww.SetFadeTime(frame, 0.5)
	OnShow(frame)
end

function AegisPathfinder:ToggleDungeonPanel()
	if not self.dungeonframe then
		self:CreateDungeonPanel()
	end
	if self.dungeonframe:IsShown() then
		self.dungeonframe:Hide()
	else
		self.dungeonframe:Show()
		self:PositionDungeonPanel()
	end
end

function AegisPathfinder:PositionDungeonPanel()
	if not self.dungeonframe or not self.optionsframe then return end
	local quad, vhalf, hhalf = self.GetQuadrant(self.statusframe)
	self.dungeonframe:ClearAllPoints()
	if hhalf == "LEFT" then
		self.dungeonframe:SetPoint("TOPLEFT", self.optionsframe, "TOPRIGHT", 5, 0)
	else
		self.dungeonframe:SetPoint("TOPRIGHT", self.optionsframe, "TOPLEFT", -5, 0)
	end
end

function AegisPathfinder:CreateDungeonPanel()
	local frame = CreateFrame("Frame", "AegisPathfinderDungeons", UIParent)
	self.dungeonframe = frame
	frame:SetFrameStrata("DIALOG")
	-- Three chips per row, as the concept lays them out.
	frame:SetWidth(CHIP_COLS * (CHIP_W + CHIP_GAP) - CHIP_GAP + CHIP_PAD * 2)
	frame:SetHeight(300)
	Theme:Panel(frame, "panel")
	frame:Hide()

	Theme:Chrome(frame, "Dungeons", Theme:PositionSaver("dungeonframe"))

	local hint = frame:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(hint, "body", 10)
	hint:SetPoint("TOPLEFT", frame, "TOPLEFT", CHIP_PAD, -(CHROME_TOP + 4))
	hint:SetPoint("RIGHT", frame, "RIGHT", -CHIP_PAD, 0)
	hint:SetJustifyH("LEFT")
	hint:SetText("Opting in makes a dungeon's setup steps mandatory.")
	Theme:TextColor(hint, "textDim")

	local wiredHint = frame:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(wiredHint, "body", 10)
	wiredHint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", CHIP_PAD, 9)
	wiredHint:SetPoint("RIGHT", frame, "RIGHT", -CHIP_PAD, 0)
	wiredHint:SetJustifyH("LEFT")
	Theme:TextColor(wiredHint, "blue")
	frame.wiredHint = wiredHint

	local dungeons = {
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

	frame.chips = {}
	for idx, d in ipairs(dungeons) do
		local chip = Theme:Chip(frame, d.code, d.name, CHIP_W, CHIP_H)
		local col = math.mod(idx - 1, CHIP_COLS)
		local row = math.floor((idx - 1) / CHIP_COLS)
		chip:SetPoint("TOPLEFT", frame, "TOPLEFT",
			CHIP_PAD + col * (CHIP_W + CHIP_GAP),
			-(CHIP_TOP + row * (CHIP_H + CHIP_GAP)))
		chip.dungeonCode = d.code

		local code, name = d.code, d.name
		chip:SetScript("OnClick", function()
			local on = not chip:IsActive()
			chip:SetActive(on)
			AegisPathfinder.db.char.Dungeons[code] = on
			AegisPathfinder:LoadGuide(AegisPathfinder.db.char.currentguide)
			AegisPathfinder:RefreshDungeonPanel()
		end)
		chip:SetScript("OnEnter", function()
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetText(name)
		end)
		chip:SetScript("OnLeave", function() GameTooltip:Hide() end)

		table.insert(frame.chips, chip)
	end

	-- Size to the rows actually laid out rather than a fixed height.
	local rows = math.ceil(table.getn(dungeons) / CHIP_COLS)
	frame:SetHeight(CHIP_TOP + rows * (CHIP_H + CHIP_GAP) + 26)

	local function OnShow(f)
		f = f or this
		AegisPathfinder:PositionDungeonPanel()
		AegisPathfinder:RefreshDungeonPanel()
		f:SetAlpha(0)
		f:SetScript("OnUpdate", ww.FadeIn)
	end

	frame:SetScript("OnShow", OnShow)
	ww.SetFadeTime(frame, 0.5)

	table.insert(UISpecialFrames, "AegisPathfinderDungeons")
end

function AegisPathfinder:ToggleFiltersPanel()
	if not self.filtersframe then
		self:CreateFiltersPanel()
	end
	if self.filtersframe:IsShown() then
		self.filtersframe:Hide()
	else
		self.filtersframe:Show()
		self:PositionFiltersPanel()
	end
end

function AegisPathfinder:PositionFiltersPanel()
	if not self.filtersframe or not self.optionsframe then return end
	local quad, vhalf, hhalf = self.GetQuadrant(self.statusframe)
	self.filtersframe:ClearAllPoints()
	if hhalf == "LEFT" then
		self.filtersframe:SetPoint("TOPRIGHT", self.optionsframe, "TOPLEFT", -5, 0)
	else
		self.filtersframe:SetPoint("TOPLEFT", self.optionsframe, "TOPRIGHT", 5, 0)
	end
end

function AegisPathfinder:CreateFiltersPanel()
	local frame = CreateFrame("Frame", "AegisPathfinderFilters", UIParent)
	self.filtersframe = frame
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(180)
	frame:SetHeight(CHROME_TOP + 125)
	Theme:Panel(frame, "panel")
	frame:Hide()

	Theme:Chrome(frame, "Filters", Theme:PositionSaver("filtersframe"))

	-- AH Checkbox
	local ahCb = ww.SummonCheckBox(18, frame, "TOPLEFT", 10, -(CHROME_TOP + 10))
	local ahText = ww.SummonFontString(ahCb, "OVERLAY", "GameFontNormalSmall", "Use Auction House", "LEFT", ahCb, "RIGHT",
		5, 0)
	frame.ahCb = ahCb

	ahCb:SetScript("OnClick", function()
		AegisPathfinder.db.char.UseAH = not not ahCb:GetChecked()
		AegisPathfinder:LoadGuide(AegisPathfinder.db.char.currentguide)
	end)

	-- Play Style Header
	local psHeader = ww.SummonFontString(frame, "OVERLAY", "GameFontNormal", "Play Style:", "TOPLEFT", frame, "TOPLEFT",
		10, -(CHROME_TOP + 45))

	-- Solo Checkbox
	local soloCb = ww.SummonCheckBox(18, frame, "TOPLEFT", 10, -(CHROME_TOP + 65))
	local soloText = ww.SummonFontString(soloCb, "OVERLAY", "GameFontNormalSmall", "Solo Mode", "LEFT", soloCb, "RIGHT",
		5, 0)
	frame.soloCb = soloCb

	-- Group Checkbox
	local groupCb = ww.SummonCheckBox(18, frame, "TOPLEFT", 10, -(CHROME_TOP + 88))
	local groupText = ww.SummonFontString(groupCb, "OVERLAY", "GameFontNormalSmall", "Group Mode", "LEFT", groupCb,
		"RIGHT", 5, 0)
	frame.groupCb = groupCb

	soloCb:SetScript("OnClick", function()
		soloCb:SetChecked(true)
		groupCb:SetChecked(false)
		AegisPathfinder.db.char.PlayStyle = "SOLO"
		AegisPathfinder:LoadGuide(AegisPathfinder.db.char.currentguide)
	end)

	groupCb:SetScript("OnClick", function()
		groupCb:SetChecked(true)
		soloCb:SetChecked(false)
		AegisPathfinder.db.char.PlayStyle = "GROUP"
		AegisPathfinder:LoadGuide(AegisPathfinder.db.char.currentguide)
	end)

	local function OnShow(f)
		f = f or this
		AegisPathfinder:PositionFiltersPanel()
		f.ahCb:SetChecked(AegisPathfinder.db.char.UseAH)
		local playstyle = AegisPathfinder.db.char.PlayStyle or "SOLO"
		f.soloCb:SetChecked(playstyle == "SOLO")
		f.groupCb:SetChecked(playstyle == "GROUP")
		f:SetAlpha(0)
		f:SetScript("OnUpdate", ww.FadeIn)
	end

	frame:SetScript("OnShow", OnShow)
	ww.SetFadeTime(frame, 0.5)

	table.insert(UISpecialFrames, "AegisPathfinderFilters")
end

table.insert(UISpecialFrames, "AegisPathfinderOptions")


--- Sync chip state with saved settings and with the loaded guide.
--
-- The blue dot marks a dungeon the current guide actually has |D| steps for,
-- which is the difference between "I could run this" and "this guide knows
-- about it". Without it every chip looks equally relevant no matter which
-- guide you are on.
function AegisPathfinder:RefreshDungeonPanel()
	local frame = self.dungeonframe
	if not frame or not frame.chips then return end

	local wired = self:GetGuideDungeons()
	local wiredCount = 0

	for _, chip in ipairs(frame.chips) do
		chip:SetActive(self.db.char.Dungeons[chip.dungeonCode])
		local isWired = wired[chip.dungeonCode] and true or false
		chip:SetWired(isWired)
		if isWired then wiredCount = wiredCount + 1 end
	end

    if frame.wiredHint then
		if wiredCount > 0 then
			frame.wiredHint:SetText(string.format(
				"Dotted: %d referenced by this guide.", wiredCount))
		else
			frame.wiredHint:SetText("This guide has no dungeon steps.")
		end
	end
end
