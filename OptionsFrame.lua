local TurtleGuide = TurtleGuide
local L = TurtleGuide.Locale
local ww = WidgetWarlock

function TurtleGuide:CreateConfigPanel()
	local frame = CreateFrame("Frame", "TurtleGuideOptions", UIParent)
	TurtleGuide.optionsframe = frame
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(310)
	frame:SetHeight(16 + 28 * 8)
	frame:SetPoint("TOPRIGHT", TurtleGuide.statusframe, "BOTTOMRIGHT")
	frame:SetBackdrop(ww.TooltipBorderBG)
	frame:SetBackdropColor(0.09, 0.09, 0.19, 1)
	frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.5)
	frame:Hide()

	local closebutton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closebutton:SetPoint("TOPRIGHT", frame, "TOPRIGHT")

	local title = ww.SummonFontString(frame, nil, "SubZoneTextFont", nil, "BOTTOMLEFT", frame, "TOPLEFT", 5, 0)
	local fontname, fontheight, fontflags = title:GetFont()
	title:SetFont(fontname, 18, fontflags)
	title:SetText("Options")

	local qtrack = ww.SummonCheckBox(22, frame, "TOPLEFT", 5, -5)
	ww.SummonFontString(qtrack, "OVERLAY", "GameFontNormalSmall", L["Automatically track quests"], "LEFT", qtrack,
		"RIGHT", 5, 0)
	qtrack:SetScript("OnClick", function() self.db.char.trackquests = not self.db.char.trackquests end)

	local qskipfollowups = ww.SummonCheckBox(22, qtrack, "TOPLEFT", 0, -20)
	ww.SummonFontString(qskipfollowups, "OVERLAY", "GameFontNormalSmall", L["Automatically skip suggested follow-ups"],
		"LEFT", qskipfollowups, "RIGHT", 5, 0)
	qskipfollowups:SetScript("OnClick", function() self.db.char.skipfollowups = not self.db.char.skipfollowups end)

	local autobranch = ww.SummonCheckBox(22, qskipfollowups, "TOPLEFT", 0, -20)
	ww.SummonFontString(autobranch, "OVERLAY", "GameFontNormalSmall", "Auto-branch to Turtle WoW zones", "LEFT",
		autobranch, "RIGHT", 5, 0)
	autobranch:SetScript("OnClick", function() self.db.char.autobranch = not self.db.char.autobranch end)

	-- Waypoint provider: cycles through "auto" plus every waypoint addon loaded
	local waypointBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	waypointBtn:SetWidth(286)
	waypointBtn:SetHeight(22)
	waypointBtn:SetPoint("TOPLEFT", autobranch, "BOTTOMLEFT", 0, -10)
	waypointBtn:SetScript("OnClick", function()
		TurtleGuide:CycleWaypointProvider()
		waypointBtn:SetText(L["Waypoints"] .. ": " .. TurtleGuide:GetWaypointProviderLabel())
	end)
	frame.waypointBtn = waypointBtn

	-- Route selector button
	local routeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	routeBtn:SetWidth(150)
	routeBtn:SetHeight(22)
	routeBtn:SetPoint("TOPLEFT", waypointBtn, "BOTTOMLEFT", 0, -6)
	routeBtn:SetText("Change Route")
	routeBtn:SetScript("OnClick", function()
		frame:Hide()
		TurtleGuide:ShowRouteSelector()
	end)

	local dungeonsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	dungeonsBtn:SetWidth(130)
	dungeonsBtn:SetHeight(22)
	dungeonsBtn:SetPoint("LEFT", routeBtn, "RIGHT", 6, 0)
	dungeonsBtn:SetText("Dungeons RXP")
	dungeonsBtn:SetScript("OnClick", function()
		TurtleGuide:ToggleDungeonPanel()
	end)
	frame.dungeonsBtn = dungeonsBtn

	local branchBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	branchBtn:SetWidth(150)
	branchBtn:SetHeight(22)
	branchBtn:SetPoint("TOPLEFT", routeBtn, "BOTTOMLEFT", 0, -6)
	branchBtn:SetText("Branch to Zone")
	branchBtn:SetScript("OnClick", function()
		frame:Hide()
		TurtleGuide:ShowGuideList(true)
	end)
	frame.branchBtn = branchBtn

	local returnMainBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	returnMainBtn:SetWidth(130)
	returnMainBtn:SetHeight(22)
	returnMainBtn:SetPoint("LEFT", branchBtn, "RIGHT", 6, 0)
	returnMainBtn:SetText("Return to Main")
	returnMainBtn:SetScript("OnClick", function()
		TurtleGuide:ReturnFromBranch()
		frame:Hide()
	end)
	frame.returnMainBtn = returnMainBtn

	local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	refreshBtn:SetWidth(150)
	refreshBtn:SetHeight(22)
	refreshBtn:SetPoint("TOPLEFT", branchBtn, "BOTTOMLEFT", 0, -6)
	refreshBtn:SetText("Rescan Progress")
	refreshBtn:SetScript("OnClick", function()
		TurtleGuide:QueryServerCompletedQuests(true)
	end)

	local errorBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	errorBtn:SetWidth(130)
	errorBtn:SetHeight(22)
	errorBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 6, 0)
	errorBtn:SetText("Error Log")
	errorBtn:SetScript("OnClick", function()
		frame:Hide()
		TurtleGuide:ShowErrorLog()
	end)

	local filtersBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	filtersBtn:SetWidth(286)
	filtersBtn:SetHeight(22)
	filtersBtn:SetPoint("TOPLEFT", refreshBtn, "BOTTOMLEFT", 0, -6)
	filtersBtn:SetText("Filters (Solo/Group/AH) RXP")
	filtersBtn:SetScript("OnClick", function()
		TurtleGuide:ToggleFiltersPanel()
	end)
	frame.filtersBtn = filtersBtn

	frame.qtrack = qtrack
	frame.qskipfollowups = qskipfollowups
	frame.autobranch = autobranch

	local function OnShow(f)
		f = f or this
		local quad, vhalf, hhalf = self.GetQuadrant(self.statusframe)
		local anchpoint = (vhalf == "TOP" and "BOTTOM" or "TOP") .. hhalf
		f:ClearAllPoints()
		f:SetPoint(quad, self.statusframe, anchpoint)
		local title_point, title_anchor, title_x, title_y
		if quad == "TOPLEFT" then
			title_point, title_anchor, title_x, title_y = "BOTTOMRIGHT", "TOPRIGHT", -5, 0
		else
			title_point, title_anchor, title_x, title_y = "BOTTOMLEFT", "TOPLEFT", 5, 0
		end
		title:ClearAllPoints()
		title:SetPoint(title_point, f, title_anchor, title_x, title_y)

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
		if TurtleGuide.dungeonframe then
			TurtleGuide.dungeonframe:Hide()
		end
		if TurtleGuide.filtersframe then
			TurtleGuide.filtersframe:Hide()
		end
	end)
	ww.SetFadeTime(frame, 0.5)
	OnShow(frame)
end

function TurtleGuide:ToggleDungeonPanel()
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

function TurtleGuide:PositionDungeonPanel()
	if not self.dungeonframe or not self.optionsframe then return end
	local quad, vhalf, hhalf = self.GetQuadrant(self.statusframe)
	self.dungeonframe:ClearAllPoints()
	if hhalf == "LEFT" then
		self.dungeonframe:SetPoint("TOPLEFT", self.optionsframe, "TOPRIGHT", 5, 0)
	else
		self.dungeonframe:SetPoint("TOPRIGHT", self.optionsframe, "TOPLEFT", -5, 0)
	end
end

function TurtleGuide:CreateDungeonPanel()
	local frame = CreateFrame("Frame", "TurtleGuideDungeons", UIParent)
	self.dungeonframe = frame
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(180)
	frame:SetHeight(380)
	frame:SetBackdrop(ww.TooltipBorderBG)
	frame:SetBackdropColor(0.09, 0.09, 0.19, 1)
	frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.5)
	frame:Hide()

	local closebutton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closebutton:SetPoint("TOPRIGHT", frame, "TOPRIGHT")

	local title = ww.SummonFontString(frame, nil, "SubZoneTextFont", nil, "TOPLEFT", frame, "TOPLEFT", 10, -10)
	local fontname, fontheight, fontflags = title:GetFont()
	title:SetFont(fontname, 16, fontflags)
	title:SetText("Dungeons")

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

	local prev = title
	frame.checkboxes = {}
	for idx, d in ipairs(dungeons) do
		local cb = ww.SummonCheckBox(18, frame, "TOPLEFT", 10, idx == 1 and -35 or -22)
		if idx == 1 then
			cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
		else
			cb:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
		end

		local text = ww.SummonFontString(cb, "OVERLAY", "GameFontNormalSmall", d.name, "LEFT", cb, "RIGHT", 5, 0)
		cb.dungeonCode = d.code

		local code = d.code
		cb:SetScript("OnClick", function()
			TurtleGuide.db.char.Dungeons[code] = not not cb:GetChecked()
			TurtleGuide:LoadGuide(TurtleGuide.db.char.currentguide)
		end)

		table.insert(frame.checkboxes, cb)
		prev = cb
	end

	local function OnShow(f)
		f = f or this
		TurtleGuide:PositionDungeonPanel()
		for _, cb in ipairs(f.checkboxes) do
			cb:SetChecked(TurtleGuide.db.char.Dungeons[cb.dungeonCode])
		end
		f:SetAlpha(0)
		f:SetScript("OnUpdate", ww.FadeIn)
	end

	frame:SetScript("OnShow", OnShow)
	ww.SetFadeTime(frame, 0.5)

	table.insert(UISpecialFrames, "TurtleGuideDungeons")
end

function TurtleGuide:ToggleFiltersPanel()
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

function TurtleGuide:PositionFiltersPanel()
	if not self.filtersframe or not self.optionsframe then return end
	local quad, vhalf, hhalf = self.GetQuadrant(self.statusframe)
	self.filtersframe:ClearAllPoints()
	if hhalf == "LEFT" then
		self.filtersframe:SetPoint("TOPRIGHT", self.optionsframe, "TOPLEFT", -5, 0)
	else
		self.filtersframe:SetPoint("TOPLEFT", self.optionsframe, "TOPRIGHT", 5, 0)
	end
end

function TurtleGuide:CreateFiltersPanel()
	local frame = CreateFrame("Frame", "TurtleGuideFilters", UIParent)
	self.filtersframe = frame
	frame:SetFrameStrata("DIALOG")
	frame:SetWidth(180)
	frame:SetHeight(155)
	frame:SetBackdrop(ww.TooltipBorderBG)
	frame:SetBackdropColor(0.09, 0.09, 0.19, 1)
	frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.5)
	frame:Hide()

	local closebutton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closebutton:SetPoint("TOPRIGHT", frame, "TOPRIGHT")

	local title = ww.SummonFontString(frame, nil, "SubZoneTextFont", nil, "TOPLEFT", frame, "TOPLEFT", 10, -10)
	local fontname, fontheight, fontflags = title:GetFont()
	title:SetFont(fontname, 16, fontflags)
	title:SetText("Filters")

	-- AH Checkbox
	local ahCb = ww.SummonCheckBox(18, frame, "TOPLEFT", 10, -40)
	local ahText = ww.SummonFontString(ahCb, "OVERLAY", "GameFontNormalSmall", "Use Auction House", "LEFT", ahCb, "RIGHT",
		5, 0)
	frame.ahCb = ahCb

	ahCb:SetScript("OnClick", function()
		TurtleGuide.db.char.UseAH = not not ahCb:GetChecked()
		TurtleGuide:LoadGuide(TurtleGuide.db.char.currentguide)
	end)

	-- Play Style Header
	local psHeader = ww.SummonFontString(frame, "OVERLAY", "GameFontNormal", "Play Style:", "TOPLEFT", frame, "TOPLEFT",
		10, -75)

	-- Solo Checkbox
	local soloCb = ww.SummonCheckBox(18, frame, "TOPLEFT", 10, -95)
	local soloText = ww.SummonFontString(soloCb, "OVERLAY", "GameFontNormalSmall", "Solo Mode", "LEFT", soloCb, "RIGHT",
		5, 0)
	frame.soloCb = soloCb

	-- Group Checkbox
	local groupCb = ww.SummonCheckBox(18, frame, "TOPLEFT", 10, -118)
	local groupText = ww.SummonFontString(groupCb, "OVERLAY", "GameFontNormalSmall", "Group Mode", "LEFT", groupCb,
		"RIGHT", 5, 0)
	frame.groupCb = groupCb

	soloCb:SetScript("OnClick", function()
		soloCb:SetChecked(true)
		groupCb:SetChecked(false)
		TurtleGuide.db.char.PlayStyle = "SOLO"
		TurtleGuide:LoadGuide(TurtleGuide.db.char.currentguide)
	end)

	groupCb:SetScript("OnClick", function()
		groupCb:SetChecked(true)
		soloCb:SetChecked(false)
		TurtleGuide.db.char.PlayStyle = "GROUP"
		TurtleGuide:LoadGuide(TurtleGuide.db.char.currentguide)
	end)

	local function OnShow(f)
		f = f or this
		TurtleGuide:PositionFiltersPanel()
		f.ahCb:SetChecked(TurtleGuide.db.char.UseAH)
		local playstyle = TurtleGuide.db.char.PlayStyle or "SOLO"
		f.soloCb:SetChecked(playstyle == "SOLO")
		f.groupCb:SetChecked(playstyle == "GROUP")
		f:SetAlpha(0)
		f:SetScript("OnUpdate", ww.FadeIn)
	end

	frame:SetScript("OnShow", OnShow)
	ww.SetFadeTime(frame, 0.5)

	table.insert(UISpecialFrames, "TurtleGuideFilters")
end

table.insert(UISpecialFrames, "TurtleGuideOptions")
