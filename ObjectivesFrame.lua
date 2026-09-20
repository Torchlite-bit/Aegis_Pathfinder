
local AegisPathfinder = AegisPathfinder
local L = AegisPathfinder.Locale
local ww = WidgetWarlock
local Theme = AegisPathfinder.Theme


local ROWHEIGHT = 30
local ROWOFFSET = 6
local TABBAR_H = 26
local HEADER_HEIGHT = 55 + TABBAR_H
local DEFAULT_WIDTH = 630
local DEFAULT_HEIGHT = 305 + 28
local MIN_WIDTH = 400
local MIN_HEIGHT = 200
local MAX_ROWS = 30
local NUMROWS = math.floor((305 - HEADER_HEIGHT) / ROWHEIGHT)


local offset = 0
local rows = {}
local scrollbar, upbutt, downbutt, title, completed


local frame = CreateFrame("Frame", "AegisPathfinderObjectives", UIParent)
AegisPathfinder.objectiveframe = frame
frame:SetFrameStrata("DIALOG")
frame:SetWidth(DEFAULT_WIDTH)
frame:SetHeight(DEFAULT_HEIGHT)
frame:SetPoint("TOPRIGHT", AegisPathfinder.statusframe, "BOTTOMRIGHT")
AegisPathfinder.objectiveskin = Theme:Panel(frame, "panel")
frame:Hide()
frame:SetScript("OnShow", function() AegisPathfinder:UpdateObjectivePanel() end)
table.insert(UISpecialFrames, "AegisPathfinderObjectives")

-- Make frame resizable
frame:SetResizable(true)
frame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
frame:SetMaxResize(1200, 800)

-- Resize grip in bottom-right corner
local grip = CreateFrame("Frame", nil, frame)
grip:SetWidth(16)
grip:SetHeight(16)
grip:SetPoint("BOTTOMRIGHT", -2, 2)
grip:EnableMouse(true)
grip:SetFrameLevel(frame:GetFrameLevel() + 2)

local gripDots = {}
for x = 1, 3 do
	for y = 1, 4 - x do
		local dot = grip:CreateTexture(nil, "OVERLAY")
		dot:SetWidth(2)
		dot:SetHeight(2)
		dot:SetTexture(Theme.texture.solid)
		Theme:Tint(dot, "textDim", 0.55)
		dot:SetPoint("BOTTOMRIGHT", -x * 4, y * 4)
		table.insert(gripDots, dot)
	end
end

grip:SetScript("OnEnter", function()
	for _, dot in ipairs(gripDots) do Theme:Tint(dot, "accent", 1) end
end)
grip:SetScript("OnLeave", function()
	for _, dot in ipairs(gripDots) do Theme:Tint(dot, "textDim", 0.55) end
end)
grip:SetScript("OnMouseDown", function()
	for _, dot in ipairs(gripDots) do Theme:Tint(dot, "accentGlow", 1) end
	frame:StartSizing("BOTTOMRIGHT")
end)
grip:SetScript("OnMouseUp", function()
	for _, dot in ipairs(gripDots) do Theme:Tint(dot, "textDim", 0.55) end
	frame:StopMovingOrSizing()
	AegisPathfinder:OnObjectiveFrameResized()
end)

frame:SetScript("OnSizeChanged", function()
	if rows and rows[1] then
		AegisPathfinder:OnObjectiveFrameResized()
	end
end)


local function ResetScrollbar()
	local f = this
	local newval = math.max(0, (AegisPathfinder.current or 0) - NUMROWS / 2 - 1)
	local steps = AegisPathfinder.actions and table.getn(AegisPathfinder.actions) or 0

	scrollbar:SetMinMaxValues(0, math.max(steps - NUMROWS, 1))
	scrollbar:SetValue(newval)

	AegisPathfinder:UpdateOHPanel()
end

local function OnShow(f)
	local f = f or this
	ResetScrollbar()
	f:SetAlpha(0)
	f:SetScript("OnUpdate", ww.FadeIn)

	if AegisPathfinder.optionsframe:IsVisible() then HideUIPanel(AegisPathfinder.optionsframe) end
	if AegisPathfinder.guidelistframe:IsVisible() then HideUIPanel(AegisPathfinder.guidelistframe) end
end


local function HideTooltip()
	if GameTooltip:IsOwned(this) then
		GameTooltip:Hide()
	end
end

local function ShowTooltip()
	local f = this
	if f.text:GetStringWidth() <= f:GetWidth() then return end

	GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
	GameTooltip:SetText(f.text:GetText(), nil, nil, nil, nil, true)
end

local function CreateButton(parent, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
	local b = CreateFrame("Button", nil, parent)
	if AegisPathfinder.select("#", a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20) > 0 then b:SetPoint(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20) end
	b:SetWidth(80)
	b:SetHeight(22)

	-- Themed pill, replacing the Blizzard panel-button artwork. SetText is
	-- shadowed so existing call sites keep working unchanged.
	b.__fill = Theme:NineSlice(b, Theme.texture.pillFill, "BACKGROUND", "panel3")
	b.__border = Theme:NineSlice(b, Theme.texture.pillBorder, "BORDER", "border")

	local label = b:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(label, "display", 11)
	label:SetPoint("CENTER", b, "CENTER", 0, 0)
	Theme:TextColor(label, "textDim")
	b.__label = label

	function b:SetText(t) self.__label:SetText(string.upper(t or "")) end
	function b:GetText() return self.__label:GetText() end

	b:SetScript("OnEnter", function()
		this.__fill:SetTint("tabbg")
		Theme:TextColor(this.__label, "text")
	end)
	b:SetScript("OnLeave", function()
		this.__fill:SetTint("panel3")
		Theme:TextColor(this.__label, "textDim")
	end)

	return b
end


function AegisPathfinder:UpdateObjectivePanel()
	frame:SetScript("OnShow", nil)
	local guidebutton = CreateButton(frame, "BOTTOMRIGHT", -24, 6)
	guidebutton:SetText("Guides")
	guidebutton:SetScript("OnClick", function() frame:Hide(); AegisPathfinder.guidelistframe:Show() end)

	local configbutton = CreateButton(frame, "RIGHT", guidebutton, "LEFT")
	configbutton:SetText(L["Config"])
	configbutton:SetScript("OnClick", function() frame:Hide(); AegisPathfinder.optionsframe:Show() end)

	local routebutton = CreateButton(frame, "RIGHT", configbutton, "LEFT")
	routebutton:SetText("Route")
	routebutton:SetScript("OnClick", function() frame:Hide(); AegisPathfinder:ShowRouteSelector() end)

	local materialsbutton = CreateButton(frame, "RIGHT", routebutton, "LEFT")
	materialsbutton:SetText("Materials")
	materialsbutton:SetScript("OnClick", function() AegisPathfinder:ToggleMaterialsPanel() end)
	materialsbutton:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText("Reagents the rest of this guide still needs", nil, nil, nil, nil, true)
	end)
	materialsbutton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Return to Main button (only visible when branching)
	local returnbutton = CreateButton(frame, "RIGHT", materialsbutton, "LEFT")
	returnbutton:SetWidth(100)
	returnbutton:SetText("Return Main")
	returnbutton:SetScript("OnClick", function() AegisPathfinder:ReturnFromBranch() end)
	returnbutton:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		if AegisPathfinder.db.char.branchsavedguide then
			GameTooltip:SetText("Return to: " .. AegisPathfinder.db.char.branchsavedguide)
		else
			GameTooltip:SetText("Return to main route")
		end
	end)
	returnbutton:SetScript("OnLeave", function() GameTooltip:Hide() end)
	frame.returnbutton = returnbutton

	if AegisPathfinder.db.char.debug then
		local b = CreateButton(frame, "RIGHT", returnbutton, "LEFT")
		b:SetText("Debug All")
		b:SetScript("OnClick", function() frame:Hide(); self:DebugGuideSequence(true) end)
	end

	title = frame:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(title, "display", 18)
	title:SetPoint("BOTTOM", frame, "TOP", 0, 4)
	Theme:TextColor(title, "text")

	--[[ Tab bar.

		The concept's model for the branch system: the guide you are on is a
		tab, branching opens a second one beside it, and closing that tab is
		how you come back. The addon expressed the same thing as a button plus
		a status tag, which says less about where you are.

		The badge marks whether the main guide is authored (XP) or a
		placeholder (TPL) -- the same signal the guide list carries, in the one
		place you are looking while you follow it.
	]]
	local tabbar = CreateFrame("Frame", nil, frame)
	tabbar:SetHeight(TABBAR_H)
	tabbar:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -4)
	tabbar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -4)
	Theme:Strip(tabbar, "tabbg")

	local function MakeTab(width)
		local t = CreateFrame("Button", nil, tabbar)
		t:SetHeight(TABBAR_H - 4)
		t:SetWidth(width)
		t.fill = Theme:NineSlice(t, Theme.texture.tabFill, "BACKGROUND", "tabbg")
		t.label = t:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(t.label, "body", 11)
		t.label:SetJustifyH("LEFT")
		Theme:TextColor(t.label, "textDim")

		function t:SetActive(active)
			if active then
				self.fill:SetTint("panel")
				Theme:TextColor(self.label, "text")
			else
				self.fill:SetTint("tabbg")
				Theme:TextColor(self.label, "textDim")
			end
		end

		return t
	end

	local mainTab = MakeTab(210)
	mainTab:SetPoint("BOTTOMLEFT", tabbar, "BOTTOMLEFT", 8, 0)
	mainTab.badge = Theme:Badge(mainTab, "XP", "xp")
	mainTab.badge:SetPoint("LEFT", mainTab, "LEFT", 7, 0)
	mainTab.label:SetPoint("LEFT", mainTab.badge, "RIGHT", 6, 0)
	mainTab.label:SetPoint("RIGHT", mainTab, "RIGHT", -6, 0)
	mainTab:SetScript("OnClick", function()
		-- Clicking the guide you left is how you go back to it.
		if AegisPathfinder.db.char.isbranching then
			AegisPathfinder:ReturnFromBranch()
		end
	end)
	mainTab:SetScript("OnEnter", function()
		if not AegisPathfinder.db.char.isbranching then return end
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Return to " .. (AegisPathfinder.db.char.branchsavedguide or "the main route"))
	end)
	mainTab:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local branchTab = MakeTab(190)
	branchTab:SetPoint("LEFT", mainTab, "RIGHT", 2, 0)
	branchTab.label:SetPoint("LEFT", branchTab, "LEFT", 8, 0)
	branchTab.label:SetPoint("RIGHT", branchTab, "RIGHT", -20, 0)

	local branchClose = CreateFrame("Button", nil, branchTab)
	branchClose:SetWidth(14)
	branchClose:SetHeight(14)
	branchClose:SetPoint("RIGHT", branchTab, "RIGHT", -4, 0)
	local closeGlyph = branchClose:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(closeGlyph, "body", 11)
	closeGlyph:SetPoint("CENTER", branchClose, "CENTER", 0, 0)
	closeGlyph:SetText("x")
	Theme:TextColor(closeGlyph, "textDim")
	branchClose:SetScript("OnClick", function() AegisPathfinder:ReturnFromBranch() end)
	branchClose:SetScript("OnEnter", function()
		Theme:TextColor(closeGlyph, "text")
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Close this branch and return")
	end)
	branchClose:SetScript("OnLeave", function()
		Theme:TextColor(closeGlyph, "textDim")
		GameTooltip:Hide()
	end)
	branchTab:Hide()

	local addTab = CreateFrame("Button", nil, tabbar)
	addTab:SetWidth(20)
	addTab:SetHeight(TABBAR_H - 8)
	addTab:SetPoint("LEFT", branchTab, "RIGHT", 4, 0)
	Theme:NineSlice(addTab, Theme.texture.tabFill, "BACKGROUND", "panel3")
	local addGlyph = addTab:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(addGlyph, "display", 14)
	addGlyph:SetPoint("CENTER", addTab, "CENTER", 0, 0)
	addGlyph:SetText("+")
	Theme:TextColor(addGlyph, "textDim")
	addTab:SetScript("OnClick", function()
		frame:Hide()
		AegisPathfinder.guidelistframe:Show()
	end)
	addTab:SetScript("OnEnter", function()
		Theme:TextColor(addGlyph, "accent")
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Branch to another guide")
	end)
	addTab:SetScript("OnLeave", function()
		Theme:TextColor(addGlyph, "textDim")
		GameTooltip:Hide()
	end)

	frame.tabbar = tabbar
	frame.mainTab, frame.branchTab, frame.addTab = mainTab, branchTab, addTab

	-- Current objective header (prominent display)
	local currentHeader = CreateFrame("Frame", nil, frame)
	currentHeader:SetHeight(50)
	currentHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -(6 + TABBAR_H))
	currentHeader:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -(6 + TABBAR_H))
	Theme:Strip(currentHeader, "panel2")
	Theme:Divider(currentHeader, currentHeader, "BOTTOMLEFT", 0, 0)

	local currentIcon = ww.SummonTexture(currentHeader, nil, 36, 36, nil, "LEFT", currentHeader, "LEFT", 8, 0)
	local currentText = currentHeader:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(currentText, "display", 15)
	currentText:SetPoint("LEFT", currentIcon, "RIGHT", 8, 6)
	Theme:TextColor(currentText, "text")

	local currentNote = currentHeader:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(currentNote, "body", 11)
	currentNote:SetPoint("TOPLEFT", currentText, "BOTTOMLEFT", 0, -2)
	Theme:TextColor(currentNote, "textDim")

	-- Navigation buttons in header
	local prevHeaderBtn = CreateButton(currentHeader, "RIGHT", currentHeader, "RIGHT", -90, 0)
	prevHeaderBtn:SetWidth(32) prevHeaderBtn:SetText("<")
	prevHeaderBtn:SetScript("OnClick", function() AegisPathfinder:GoToPreviousObjective() end)
	prevHeaderBtn:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText("Previous objective")
	end)
	prevHeaderBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local nextHeaderBtn = CreateButton(currentHeader, "LEFT", prevHeaderBtn, "RIGHT", 2, 0)
	nextHeaderBtn:SetWidth(32) nextHeaderBtn:SetText(">")
	nextHeaderBtn:SetScript("OnClick", function() AegisPathfinder:SkipToNextObjective() end)
	nextHeaderBtn:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText("Skip to next objective")
	end)
	nextHeaderBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local skipHeaderBtn = CreateButton(currentHeader, "LEFT", nextHeaderBtn, "RIGHT", 2, 0)
	skipHeaderBtn:SetWidth(32) skipHeaderBtn:SetText(">>")
	skipHeaderBtn:SetScript("OnClick", function() AegisPathfinder:SetTurnedIn(); AegisPathfinder:UpdateStatusFrame() end)
	skipHeaderBtn:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText("Mark complete and advance")
	end)
	skipHeaderBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	frame.currentHeader = currentHeader
	frame.currentIcon = currentIcon
	frame.currentText = currentText
	frame.currentNote = currentNote

	completed = frame:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(completed, "display", 14)
	completed:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
	Theme:TextColor(completed, "accent")

	scrollbar, upbutt, downbutt = ww.ConjureScrollBar(frame)
	scrollbar:SetPoint("TOPRIGHT", frame, -7, -(21 + TABBAR_H))
	scrollbar:SetPoint("BOTTOM", frame, 0, 22 + 22)
	scrollbar:SetScript("OnValueChanged", function() local f, val = this, arg1 self:UpdateOHPanel(val) end)

	upbutt:SetScript("OnClick", function()
		local f = this
		scrollbar:SetValue(offset - NUMROWS + 1)
		PlaySound("UChatScrollButton")
	end)

	downbutt:SetScript("OnClick", function()
		local f = this
		scrollbar:SetValue(offset + NUMROWS - 1)
		PlaySound("UChatScrollButton")
	end)

	for i = 1, MAX_ROWS do
		local row = CreateFrame("Button", nil, frame)
		row:SetPoint("TOPLEFT", i == 1 and frame or rows[i - 1], i == 1 and "TOPLEFT" or "BOTTOMLEFT", 0, i == 1 and -(58 + TABBAR_H) or 0)
		row:SetPoint("RIGHT", scrollbar, "LEFT", -4, 0)
		row:SetHeight(ROWHEIGHT)

		-- Flat row with a left accent bar on the active step, as in the
		-- concept. The bar is hidden until UpdateOHPanel marks the row.
		row.bg = row:CreateTexture(nil, "BACKGROUND")
		row.bg:SetTexture(Theme.texture.solid)
		row.bg:SetAllPoints(row)
		row.bg:SetVertexColor(1, 1, 1, 0.035)
		row.bg:Hide()

		row.activebar = row:CreateTexture(nil, "BORDER")
		row.activebar:SetTexture(Theme.texture.solid)
		row.activebar:SetWidth(2)
		row.activebar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		row.activebar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
		Theme:Tint(row.activebar, "accent")
		row.activebar:Hide()

		local check = Theme:StepCheck(row, ROWHEIGHT - ROWOFFSET)
		check:SetPoint("LEFT", row, "LEFT", ROWOFFSET, 0)
		local icon = ww.SummonTexture(row, nil, ROWHEIGHT - ROWOFFSET, ROWHEIGHT - ROWOFFSET, nil, "LEFT", check, "RIGHT", ROWOFFSET, 0)
		local text = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(text, "body", 12)
		text:SetPoint("LEFT", icon, "RIGHT", ROWOFFSET, 0)
		Theme:TextColor(text, "text")

		local detailhover = CreateFrame("Button", nil, row)
		detailhover:SetHeight(ROWHEIGHT - ROWOFFSET)
		detailhover:SetPoint("LEFT", text, "RIGHT", ROWOFFSET * 3, 0)
		detailhover:SetPoint("RIGHT", scrollbar, "LEFT", -ROWOFFSET, 0)
		detailhover:SetScript("OnEnter", ShowTooltip)
		detailhover:SetScript("OnLeave", HideTooltip)

		local detail = detailhover:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(detail, "body", 11)
		detail:SetAllPoints(detailhover)
		detail:SetJustifyH("RIGHT")
		Theme:TextColor(detail, "goldDeep")
		detailhover.text = detail

		check:SetScript("OnClick", function()
			local f = this
			self:SetTurnedIn(row.i, f:GetChecked())
		end)

		row:SetScript("OnClick", function()
			AegisPathfinder:GoToObjective(row.i)
		end)

		detailhover:SetScript("OnClick", function()
			AegisPathfinder:GoToObjective(row.i)
		end)

		row.text = text
		row.detail = detail
		row.check = check
		row.icon = icon
		rows[i] = row
	end

	frame:EnableMouseWheel()
	frame:SetScript("OnMouseWheel", function()
		local f, val = this, arg1
		scrollbar:SetValue(offset - val)
	end)

	-- Restore saved size
	if self.db.profile.objframewidth then
		frame:SetWidth(self.db.profile.objframewidth)
	end
	if self.db.profile.objframeheight then
		frame:SetHeight(self.db.profile.objframeheight)
	end

	self:OnObjectiveFrameResized()

	frame:SetScript("OnShow", OnShow)
	ww.SetFadeTime(frame, 0.5)
	OnShow(frame)
	return frame
end


--- Keep the tab bar in step with which guide is loaded and whether the
--- player is off on a branch.
function AegisPathfinder:UpdateObjectiveTabs()
	if not frame.mainTab then return end

	local branching = self.db.char.isbranching
	-- While branching, currentguide is the branch; the guide you left is
	-- saved separately.
	local mainName = (branching and self.db.char.branchsavedguide)
		or self.db.char.currentguide or "No Guide"

	frame.mainTab.label:SetText(mainName)
	frame.mainTab.badge:SetKind(self:IsTemplateGuide(mainName) and "tpl" or "xp",
		self:IsTemplateGuide(mainName) and "TPL" or "XP")
	frame.mainTab:SetActive(not branching)

	if branching then
		frame.branchTab:Show()
		frame.branchTab.label:SetText(self.db.char.currentguide or "Branch")
		frame.branchTab:SetActive(true)
		frame.addTab:SetPoint("LEFT", frame.branchTab, "RIGHT", 4, 0)
	else
		frame.branchTab:Hide()
		-- With no branch tab between them, the + button follows the main tab
		-- rather than floating where the hidden tab used to be.
		frame.addTab:SetPoint("LEFT", frame.mainTab, "RIGHT", 4, 0)
	end
end

function AegisPathfinder:OnObjectiveFrameResized()
	local w = frame:GetWidth()
	local h = frame:GetHeight()

	-- Save dimensions
	self.db.profile.objframewidth = w
	self.db.profile.objframeheight = h

	-- Recalculate visible rows
	local contentHeight = h - 28 - HEADER_HEIGHT  -- 28 for bottom buttons area
	NUMROWS = math.max(1, math.floor(contentHeight / ROWHEIGHT))
	if NUMROWS > MAX_ROWS then NUMROWS = MAX_ROWS end

	-- Show/hide rows based on new count
	for i, row in ipairs(rows) do
		if i > NUMROWS then
			row:Hide()
		end
	end

	-- Update scrollbar range
	if scrollbar and self.actions then
		scrollbar:SetMinMaxValues(0, math.max(table.getn(self.actions) - NUMROWS, 1))
	end

	-- Refresh display
	if frame:IsVisible() and self.current then
		self:UpdateOHPanel()
	end
end


local accepted = {}
local acceptedDirty = true
function AegisPathfinder:UpdateOHPanel(value)
	if not frame or not frame:IsVisible() then return end

	self:UpdateObjectiveTabs()
	-- The panel can be opened before any guide is parsed; everything below reads
	-- the step list and the current step directly.
	if not self.actions or not self.current then return end

	-- Update title with branch indicator
	local guideName = self.db.char.currentguide or L["No Guide Loaded"]
	if self.db.char.isbranching then
		title:SetText("|cff00ff00[Branch]|r " .. guideName)
	else
		title:SetText(guideName)
	end

	-- Show/hide return button based on branch status
	if frame.returnbutton then
		if self.db.char.isbranching then
			frame.returnbutton:Show()
			frame.returnbutton:Enable()
		else
			frame.returnbutton:Hide()
		end
	end

	local r, g, b = self.ColorGradient((self.current - 1) / table.getn(self.actions))
	completed:SetText(string.format(L["|cff%02x%02x%02x%d%% complete"], r * 255, g * 255, b * 255, (self.current - 1) / table.getn(self.actions) * 100))

	if self.guidechanged then
		self.guidechanged = nil
		acceptedDirty = true
		ResetScrollbar()
	end

	if value then offset = math.floor(value) end
	if (offset + NUMROWS) > table.getn(self.actions) then offset = table.getn(self.actions) - NUMROWS end
	if offset < 0 then offset = 0 end

	if offset == 0 then upbutt:Disable() else upbutt:Enable() end
	if offset == (table.getn(self.actions) - NUMROWS) then downbutt:Disable() else downbutt:Enable() end

	if not value or acceptedDirty then
		for i in pairs(accepted) do accepted[i] = nil end

		if self.actions then
			for i in pairs(self.actions) do
				local action, name = self:GetObjectiveInfo(i)
				local _, _, quest = string.find(name, L.PART_FIND)
				local _, _, part = string.find(name, ".*%(Part (%d+)%)")
				if quest and not accepted[quest] and not self:GetObjectiveStatus(i) then accepted[quest] = name end
			end
		end
		acceptedDirty = false
	end

	for i, row in ipairs(rows) do
		if i > NUMROWS then row:Hide()
		else
		row.i = i + offset
		local idx = i + offset
		local action, name = self:GetObjectiveInfo(idx)
		if not name then row:Hide()
		else
			local turnedin, logi, complete = self:GetObjectiveStatus(idx)
			local optional, intown = self:GetObjectiveTag("O", idx), self:GetObjectiveTag("T", idx)
			local isActive = (idx == self.current)
			row:Show()

			-- Visual hierarchy based on status
			local shortname = string.gsub(name, L.PART_GSUB, "")
			logi = not turnedin and (not accepted[shortname] or (accepted[shortname] == name)) and logi
			complete = not turnedin and (not accepted[shortname] or (accepted[shortname] == name)) and complete
			local checked = turnedin or action == "ACCEPT" and logi or action == "COMPLETE" and complete

			-- Row state, following the concept: the active step gets a faint
			-- wash and a left accent bar, a completed step dims, everything
			-- else is flat.
			row.bg:Hide()
			row.activebar:Hide()

			if isActive then
				row.bg:SetVertexColor(1, 1, 1, 0.035)
				row.bg:Show()
				row.activebar:Show()
				Theme:TextColor(row.text, "text")
			elseif checked then
				Theme:TextColor(row.text, "subtle")
			elseif intown then
				-- |T| in-town steps keep a hint of accent.
				row.bg:SetVertexColor(Theme.color.accent[1], Theme.color.accent[2],
					Theme.color.accent[3], 0.06)
				row.bg:Show()
				Theme:TextColor(row.text, "accentGlow")
			else
				Theme:TextColor(row.text, "textDim")
			end

			row.check:SetAutoEligible(self:IsAutoDetectable(action, idx))

			-- Show quest progress for COMPLETE objectives
			local progressText = ""
			if action == "COMPLETE" and logi and not complete then
				local numObj = GetNumQuestLeaderBoards(logi)
				for j = 1, numObj do
					local text = GetQuestLogLeaderBoard(j, logi)
					if text then progressText = text break end
				end
			end

			row.icon:SetTexture(self.icons[action])
			if action ~= "ACCEPT" and action ~= "TURNIN" then row.icon:SetTexCoord(4 / 48, 44 / 48, 4 / 48, 44 / 48) end
			row.text:SetText(string.format("[%d] %s", idx, name) .. (optional and L[" |cff808080(Optional)"] or ""))
			row.detail:SetText(progressText ~= "" and progressText or self:GetObjectiveTag("N", idx))
			row.check:SetChecked(checked)

			if (AegisPathfinder.current > idx) and optional and not checked then
				row.text:SetTextColor(0.5, 0.5, 0.5)
				row.check:Disable()
			elseif not isActive and not checked then
				row.check:Enable()
			else
				row.check:Enable()
			end

			if self.db.char.currentguide == "No Guide" then row.check:Disable() end
		end
		end -- i > NUMROWS
	end

	-- Update current objective header
	if frame.currentIcon and self.current then
		local action, name = self:GetObjectiveInfo(self.current)
		local note = self:GetObjectiveTag("N", self.current)
		frame.currentIcon:SetTexture(self.icons[action])
		if action ~= "ACCEPT" and action ~= "TURNIN" then
			frame.currentIcon:SetTexCoord(4 / 48, 44 / 48, 4 / 48, 44 / 48)
		else
			frame.currentIcon:SetTexCoord(0, 1, 0, 1)
		end
		frame.currentText:SetText(string.format("[%d/%d] %s: %s", self.current, table.getn(self.actions), action, name or "???"))
		frame.currentNote:SetText(note or "")
	end
end
