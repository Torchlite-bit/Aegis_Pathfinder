--[[ The objectives panel -- the guide window, and the addon's main surface.

	Laid out as the concept's `#objectives` panel, top to bottom:

	  .panel-header       header strip: ☰ · PATHFINDER · ✕, and the drag handle
	  .tabbar             the guide you are on, the one you branched to, and +
	  .navrow             ← step number → , with the step count on the right
	  .zprogress-track    4px bar of guide completion
	  .steps-list         the steps
	  .panel-footer-hint  the slash commands

	Rows follow the concept's two models. Most steps are a `.zrow`: a dot, an
	action glyph, the step title, and the note beneath it in grey. ACCEPT and
	TURNIN steps become a full-width `.zband` once they are the current step or
	are done -- red while outstanding, green once satisfied -- which is how the
	concept makes "there is a quest to hand in here" impossible to scroll past.
]]

local AegisPathfinder = AegisPathfinder
local L = AegisPathfinder.Locale
local ww = WidgetWarlock
local Theme = AegisPathfinder.Theme


-- Concept geometry. CHROME_TOP is everything above the step list; the list
-- and the footer divide what is left.
local HEADER_H   = 30
local TABBAR_H   = 26
local NAVROW_H   = 26
local PROGRESS_H = 4
local FOOTER_H   = 24
local CHROME_TOP = HEADER_H + TABBAR_H + NAVROW_H + PROGRESS_H

local ROWHEIGHT = 44          -- title over note, as the concept stacks them
local ROWPAD    = 14          -- .zrow padding-left
local DOTSIZE   = 14
local ICONSIZE  = 16

local DEFAULT_WIDTH = 630
local DEFAULT_HEIGHT = 420
local MIN_WIDTH = 400
local MIN_HEIGHT = 240
local MAX_ROWS = 30
local NUMROWS = 1


local offset = 0
local rows = {}
local scrollbar, upbutt, downbutt
local navStepNum, navCount, guideProgress
local footerQid, footerCount, meter


local frame = CreateFrame("Frame", "AegisPathfinderObjectives", UIParent)
AegisPathfinder.objectiveframe = frame
frame:SetFrameStrata("DIALOG")
frame:SetWidth(DEFAULT_WIDTH)
frame:SetHeight(DEFAULT_HEIGHT)
-- The concept parks it at top:180px; right:40px. There is no status card to
-- hang off any more, so it anchors to the screen.
frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -180)
AegisPathfinder.objectiveskin = Theme:Panel(frame, "panel")
frame:Hide()
frame:SetScript("OnShow", function() AegisPathfinder:UpdateObjectivePanel() end)
table.insert(UISpecialFrames, "AegisPathfinderObjectives")

frame:SetResizable(true)
frame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
frame:SetMaxResize(1200, 800)


--[[ Resize grip.

	One generated texture rather than six placed dots: the cluster keeps its
	spacing, and hover is a single tint instead of a loop.
]]
local grip = CreateFrame("Frame", nil, frame)
grip:SetWidth(14)
grip:SetHeight(14)
grip:SetPoint("BOTTOMRIGHT", -4, 4)
grip:EnableMouse(true)
grip:SetFrameLevel(frame:GetFrameLevel() + 4)

local gripTex = grip:CreateTexture(nil, "OVERLAY")
gripTex:SetTexture(Theme.texture.grip)
gripTex:SetAllPoints(grip)
Theme:Tint(gripTex, "textDim", 0.55)

grip:SetScript("OnEnter", function() Theme:Tint(gripTex, "accent", 1) end)
grip:SetScript("OnLeave", function() Theme:Tint(gripTex, "textDim", 0.55) end)
grip:SetScript("OnMouseDown", function()
	Theme:Tint(gripTex, "accentGlow", 1)
	frame:StartSizing("BOTTOMRIGHT")
end)
grip:SetScript("OnMouseUp", function()
	Theme:Tint(gripTex, "textDim", 0.55)
	frame:StopMovingOrSizing()
	AegisPathfinder:OnObjectiveFrameResized()
end)

frame:SetScript("OnSizeChanged", function()
	if rows and rows[1] then
		AegisPathfinder:OnObjectiveFrameResized()
	end
end)


local function ResetScrollbar()
	local newval = math.max(0, (AegisPathfinder.current or 0) - NUMROWS / 2 - 1)
	local steps = AegisPathfinder.actions and table.getn(AegisPathfinder.actions) or 0

	scrollbar:SetMinMaxValues(0, math.max(steps - NUMROWS, 1))
	scrollbar:SetValue(newval)

	AegisPathfinder:UpdateOHPanel()
end

local function OnShow(f)
	local f = f or this
	AegisPathfinder.db.char.panelopen = true
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


function AegisPathfinder:UpdateObjectivePanel()
	frame:SetScript("OnShow", nil)

	--[[ Header.

		Every window in the concept wears the same strip, and it is what you
		drag the window by -- which is why the panel could not be moved before:
		it had a floating title above the frame and no handle at all.
	]]
	local header = Theme:Header(frame, HEADER_H)
	header:MakeDragHandle(frame, Theme:PositionSaver("objframe"))

	local menuChip = Theme:ChipButton(header, "menu")
	menuChip:SetPoint("LEFT", header, "LEFT", 8, 0)
	menuChip:SetScript("OnClick", function()
		frame:Hide()
		AegisPathfinder.optionsframe:Show()
	end)
	menuChip:SetScript("OnEnter", function()
		this.fill:SetTint("text", 0.10)
		Theme:Tint(this.glyph, "text")
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
		GameTooltip:SetText(L["Config"])
	end)
	menuChip:SetScript("OnLeave", function()
		this.fill:SetTint("text", 0.04)
		Theme:Tint(this.glyph, "textDim")
		GameTooltip:Hide()
	end)

	--[[ Focus / overview.

		The concept's third chip. Focus mode -- the default -- shows the one
		step you are on and nothing else, which is how you follow a guide;
		overview shows the whole list, which is how you look ahead. The chip
		takes the accent fill while overview is on, so the panel says which
		of the two you are looking at.
	]]
	local expandChip = Theme:ChipButton(header, "expand")
	expandChip:SetPoint("LEFT", menuChip, "RIGHT", 6, 0)
	expandChip:SetScript("OnClick", function()
		AegisPathfinder:ToggleOverviewMode()
	end)
	expandChip:SetScript("OnEnter", function()
		if not this.__active then
			this.fill:SetTint("text", 0.10)
			Theme:Tint(this.glyph, "text")
		end
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
		GameTooltip:SetText(AegisPathfinder.db.char.overviewmode
			and "Show one step at a time" or "Show all steps")
	end)
	expandChip:SetScript("OnLeave", function()
		if not this.__active then
			this.fill:SetTint("text", 0.04)
			Theme:Tint(this.glyph, "textDim")
		end
		GameTooltip:Hide()
	end)
	frame.expandChip = expandChip

	local closeChip = Theme:ChipButton(header, "close")
	closeChip:SetPoint("RIGHT", header, "RIGHT", -8, 0)
	closeChip:SetScript("OnClick", function()
		AegisPathfinder.db.char.panelopen = false
		frame:Hide()
	end)

	frame.header = header

	--[[ Tab bar.

		The concept's model for the branch system: the guide you are on is a
		tab, branching opens a second one beside it, and closing that tab is
		how you come back.

		The badge marks whether the main guide is authored (XP) or a
		placeholder (TPL) -- the same signal the guide list carries, in the one
		place you are looking while you follow it.
	]]
	local tabbar = CreateFrame("Frame", nil, frame)
	tabbar:SetHeight(TABBAR_H)
	tabbar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
	tabbar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
	Theme:Strip(tabbar, "tabbg")
	Theme:Divider(tabbar, tabbar, "BOTTOMLEFT", 0, 0)

	local function MakeTab(width)
		local t = CreateFrame("Button", nil, tabbar)
		t:SetHeight(TABBAR_H - 5)
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

	local branchClose = Theme:GlyphButton(branchTab, "close", 8, 14)
	branchClose:SetPoint("RIGHT", branchTab, "RIGHT", -4, 0)
	branchClose:SetScript("OnClick", function() AegisPathfinder:ReturnFromBranch() end)
	branchClose:SetScript("OnEnter", function()
		Theme:Tint(this.glyph, "text")
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Close this branch and return")
	end)
	branchClose:SetScript("OnLeave", function()
		Theme:Tint(this.glyph, "textDim")
		GameTooltip:Hide()
	end)
	branchTab:Hide()

	local addTab = Theme:GlyphButton(tabbar, "plus", 10, TABBAR_H - 9)
	addTab:SetPoint("LEFT", branchTab, "RIGHT", 4, 0)
	Theme:NineSlice(addTab, Theme.texture.tabBorder, "BORDER", "subtle")
	addTab:SetScript("OnClick", function()
		frame:Hide()
		AegisPathfinder.guidelistframe:Show()
	end)
	addTab:SetScript("OnEnter", function()
		Theme:Tint(this.glyph, "accent")
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Branch to another guide")
	end)
	addTab:SetScript("OnLeave", function()
		Theme:Tint(this.glyph, "textDim")
		GameTooltip:Hide()
	end)

	frame.tabbar = tabbar
	frame.mainTab, frame.branchTab, frame.addTab = mainTab, branchTab, addTab

	--[[ Nav row: ← N → , with the count on the right.

		This replaces the 50px "current objective" block the panel used to
		carry. That block repeated the status card underneath it -- the same
		icon, title and note, twice on screen -- where the concept spends the
		row on moving through the guide instead.
	]]
	local navrow = CreateFrame("Frame", nil, frame)
	navrow:SetHeight(NAVROW_H)
	navrow:SetPoint("TOPLEFT", tabbar, "BOTTOMLEFT", 0, 0)
	navrow:SetPoint("TOPRIGHT", tabbar, "BOTTOMRIGHT", 0, 0)
	Theme:Strip(navrow, "tabbg")
	Theme:Divider(navrow, navrow, "BOTTOMLEFT", 0, 0)

	local prevArrow = Theme:GlyphButton(navrow, "arrowLeft", 11, 20)
	prevArrow:SetPoint("LEFT", navrow, "LEFT", ROWPAD - 4, 0)
	prevArrow:SetScript("OnClick", function() AegisPathfinder:GoToPreviousObjective() end)

	navStepNum = navrow:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(navStepNum, "display", 15)
	navStepNum:SetPoint("LEFT", prevArrow, "RIGHT", 6, 0)
	navStepNum:SetJustifyH("CENTER")
	navStepNum:SetWidth(44)
	Theme:TextColor(navStepNum, "text")

	local nextArrow = Theme:GlyphButton(navrow, "arrowRight", 11, 20)
	nextArrow:SetPoint("LEFT", navStepNum, "RIGHT", 6, 0)
	nextArrow:SetScript("OnClick", function() AegisPathfinder:SkipToNextObjective() end)

	-- Marking the step done and moving on is a third action, and one the
	-- concept reaches by ticking the step. Kept here as well because the panel
	-- is where you go when a step will not complete itself.
	local doneArrow = Theme:GlyphButton(navrow, "tick", 11, 20)
	doneArrow:SetPoint("LEFT", nextArrow, "RIGHT", 2, 0)
	doneArrow:SetScript("OnClick", function()
		AegisPathfinder:SetTurnedIn()
		AegisPathfinder:UpdateStatusFrame()
	end)

	local function ArrowTip(btn, tip)
		btn:SetScript("OnEnter", function()
			Theme:Tint(this.glyph, "text")
			GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
			GameTooltip:SetText(tip)
		end)
		btn:SetScript("OnLeave", function()
			Theme:Tint(this.glyph, "textDim")
			GameTooltip:Hide()
		end)
	end
	ArrowTip(prevArrow, "Previous objective")
	ArrowTip(nextArrow, "Skip to next objective")
	ArrowTip(doneArrow, "Mark complete and advance")

	navCount = navrow:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(navCount, "body", 10)
	navCount:SetPoint("RIGHT", navrow, "RIGHT", -ROWPAD, 0)
	navCount:SetJustifyH("RIGHT")
	Theme:TextColor(navCount, "textDim")

	frame.navrow = navrow

	-- Guide completion, as a 4px rule across the full width.
	guideProgress = Theme:ProgressBar(frame, PROGRESS_H)
	guideProgress:SetPoint("TOPLEFT", navrow, "BOTTOMLEFT", 0, 0)
	guideProgress:SetPoint("TOPRIGHT", navrow, "BOTTOMRIGHT", 0, 0)
	frame.guideProgress = guideProgress

	--[[ Footer.

		The concept replaced its slash-command hint with live state: the
		current step's quest id on the left, and how far through the guide you
		are on the right. Materials has no concept equivalent and is a view
		rather than a setting, so it keeps its button here; everything else the
		old button row carried lives where the concept puts it -- Config and
		Route behind the header's ☰, Guides behind the tab bar's +, and
		returning from a branch on the branch tab itself.
	]]
	local footer = CreateFrame("Frame", nil, frame)
	footer:SetHeight(FOOTER_H)
	footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
	footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	Theme:CapStrip(footer, "panel2", "bottom")

	local footerRule = footer:CreateTexture(nil, "OVERLAY")
	footerRule:SetTexture(Theme.texture.solid)
	footerRule:SetHeight(1)
	footerRule:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
	footerRule:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
	Theme:Tint(footerRule, "border")

	footerQid = footer:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(footerQid, "body", 10)
	footerQid:SetPoint("LEFT", footer, "LEFT", ROWPAD + 18, 0)
	footerQid:SetJustifyH("LEFT")
	Theme:TextColor(footerQid, "accent")

	footerCount = footer:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(footerCount, "body", 10)
	footerCount:SetPoint("RIGHT", footer, "RIGHT", -ROWPAD, 0)
	footerCount:SetJustifyH("RIGHT")
	Theme:TextColor(footerCount, "textDim")

	local materials = Theme:GlyphButton(footer, "use", 11, 18)
	materials:SetPoint("LEFT", footer, "LEFT", ROWPAD - 4, 0)
	materials:SetScript("OnClick", function() AegisPathfinder:ToggleMaterialsPanel() end)
	materials:SetScript("OnEnter", function()
		Theme:Tint(this.glyph, "accent")
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText("Reagents the rest of this guide still needs", nil, nil, nil, nil, true)
	end)
	materials:SetScript("OnLeave", function()
		Theme:Tint(this.glyph, "textDim")
		GameTooltip:Hide()
	end)

	frame.footer = footer

	scrollbar, upbutt, downbutt = ww.ConjureScrollBar(frame)
	scrollbar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -(CHROME_TOP + 14))
	scrollbar:SetPoint("BOTTOM", frame, "BOTTOM", 0, FOOTER_H + 18)
	scrollbar:SetScript("OnValueChanged", function() local val = arg1 self:UpdateOHPanel(val) end)

	upbutt:SetScript("OnClick", function()
		scrollbar:SetValue(offset - NUMROWS + 1)
		PlaySound("UChatScrollButton")
	end)

	downbutt:SetScript("OnClick", function()
		scrollbar:SetValue(offset + NUMROWS - 1)
		PlaySound("UChatScrollButton")
	end)

	--[[ Step rows.

		Each slot carries both of the concept's row models and shows one of
		them. A `.zrow` dot/glyph/title/note, or -- for an ACCEPT or TURNIN
		that is current or done -- the coloured band laid over the whole slot.
	]]
	for i = 1, MAX_ROWS do
		local row = CreateFrame("Button", nil, frame)
		row:SetPoint("TOPLEFT", i == 1 and frame or rows[i - 1],
			i == 1 and "TOPLEFT" or "BOTTOMLEFT", i == 1 and 1 or 0, i == 1 and -CHROME_TOP or 0)
		row:SetPoint("RIGHT", scrollbar, "LEFT", -4, 0)
		row:SetHeight(ROWHEIGHT)

		-- Faint wash on the active step, plus the left accent bar.
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

		local check = Theme:StepCheck(row, DOTSIZE)
		check:SetPoint("LEFT", row, "LEFT", ROWPAD, 0)

		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetWidth(ICONSIZE); icon:SetHeight(ICONSIZE)
		icon:SetPoint("LEFT", check, "RIGHT", 9, 0)

		-- Title over note, both clipped to one line: the concept stacks them,
		-- and a fixed row height is what lets a 268-step guide scroll.
		local text = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(text, "body", 12)
		text:SetPoint("TOPLEFT", icon, "TOPRIGHT", 9, 1)
		text:SetPoint("RIGHT", row, "RIGHT", -ROWPAD, 0)
		text:SetJustifyH("LEFT")
		text:SetHeight(16)
		Theme:TextColor(text, "text")

		local detail = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(detail, "body", 11)
		detail:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
		detail:SetPoint("RIGHT", row, "RIGHT", -ROWPAD, 0)
		detail:SetJustifyH("LEFT")
		detail:SetHeight(15)
		-- #8f8f86 in the concept: dimmer than --text-dim, so the note reads as
		-- support for the title rather than competing with it.
		detail:SetTextColor(0.56, 0.56, 0.52)

		--[[ The band, covering the slot when this step is an ACCEPT or TURNIN
			that is current or done. Its own button so a click anywhere on it
			toggles the step, as the concept has it. ]]
		local band = Theme:Band(row, ROWHEIGHT)
		band:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
		band:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
		band:Hide()

		local bandTag = band:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(bandTag, "body", 9)
		bandTag:SetPoint("RIGHT", band, "RIGHT", -10, 0)
		bandTag:SetTextColor(1, 1, 1)
		band.tag = bandTag

		check:SetScript("OnClick", function()
			self:SetTurnedIn(row.i, this:GetChecked())
		end)

		row:SetScript("OnClick", function() AegisPathfinder:GoToObjective(row.i) end)
		band:SetScript("OnClick", function() AegisPathfinder:GoToObjective(row.i) end)

		row:SetScript("OnEnter", function()
			if this.__tip then
				GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
				GameTooltip:SetText(this.__tip, nil, nil, nil, nil, true)
			end
		end)
		row:SetScript("OnLeave", HideTooltip)

		row.text = text
		row.detail = detail
		row.check = check
		row.icon = icon
		row.band = band
		rows[i] = row
	end

	--[[ The objective meter.

		The concept shows it under the single step in focus mode: what the
		quest wants, how much of it you have, and a bar. This is quest-log
		leaderboard text -- "Kobold Vermin slain: 3/8" -- which the panel used
		to flatten into the step's note line, where the numbers were easy to
		miss. Overview mode still does that, as the concept does.
	]]
	meter = CreateFrame("Frame", nil, frame)
	meter:SetHeight(38)
	meter:SetPoint("TOPLEFT", rows[1], "BOTTOMLEFT", ROWPAD, -2)
	meter:SetPoint("RIGHT", frame, "RIGHT", -ROWPAD, 0)
	Theme:NineSlice(meter, Theme.texture.tabFill, "BACKGROUND", "text", 0.04)
	Theme:NineSlice(meter, Theme.texture.tabBorder, "BORDER", "border")
	meter:Hide()

	local meterLabel = meter:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(meterLabel, "body", 12)
	meterLabel:SetPoint("TOPLEFT", meter, "TOPLEFT", 11, -8)
	meterLabel:SetJustifyH("LEFT")
	Theme:TextColor(meterLabel, "textDim")

	local meterCount = meter:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(meterCount, "body2", 12)
	meterCount:SetPoint("TOPRIGHT", meter, "TOPRIGHT", -11, -8)
	meterCount:SetJustifyH("RIGHT")
	Theme:TextColor(meterCount, "accent")

	local meterBar = Theme:ProgressBar(meter, 6)
	meterBar:SetPoint("BOTTOMLEFT", meter, "BOTTOMLEFT", 11, 8)
	meterBar:SetPoint("BOTTOMRIGHT", meter, "BOTTOMRIGHT", -11, 8)

	meter.label, meter.count, meter.bar = meterLabel, meterCount, meterBar
	frame.meter = meter

	frame:EnableMouseWheel()
	frame:SetScript("OnMouseWheel", function()
		scrollbar:SetValue(offset - arg1)
	end)

	-- Restore saved size and position.
	if self.db.profile.objframewidth then
		frame:SetWidth(self.db.profile.objframewidth)
	end
	if self.db.profile.objframeheight then
		frame:SetHeight(self.db.profile.objframeheight)
	end
	Theme:RestorePosition(frame, "objframe")
	frame.expandChip:SetActive(self.db.char.overviewmode)

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

	self.db.profile.objframewidth = w
	self.db.profile.objframeheight = h

	local contentHeight = h - CHROME_TOP - FOOTER_H
	NUMROWS = math.max(1, math.floor(contentHeight / ROWHEIGHT))
	if NUMROWS > MAX_ROWS then NUMROWS = MAX_ROWS end

	-- Focus mode draws one row whatever the panel's height.
	local shown = self.db.char.overviewmode and NUMROWS or 1
	for i, row in ipairs(rows) do
		if i > shown then row:Hide() end
	end

	if scrollbar and self.actions then
		scrollbar:SetMinMaxValues(0, math.max(table.getn(self.actions) - NUMROWS, 1))
	end

	if frame:IsVisible() and self.current then
		self:UpdateOHPanel()
	end
end


--[[ Which steps the concept renders as a coloured band rather than a row.

	Quest hand-offs, and only those: they are the steps where standing in the
	right place is not enough, and the band is what stops one being scrolled
	past. Everything else is a plain row.
]]
local BANDABLE = { ACCEPT = true, TURNIN = true }

local VERB = {
	ACCEPT = { "Accept", "Accepted" },
	TURNIN = { "Turn in", "Turned in" },
}


--- Flip between showing the one step you are on and showing the whole guide.
function AegisPathfinder:ToggleOverviewMode()
	self.db.char.overviewmode = not self.db.char.overviewmode
	if frame.expandChip then frame.expandChip:SetActive(self.db.char.overviewmode) end
	-- The row count and the scrollbar both depend on the mode.
	self:OnObjectiveFrameResized()
	self:UpdateOHPanel()
end

--[[ A step's quest-log objective, as label and counts.

	The leaderboard text is "Kobold Vermin slain: 3/8"; the meter wants the
	three parts separately. Anything that does not parse is handed back whole
	as the label, with no counts, because a guide can carry objectives that are
	not countable ("Speak to Marshal Dughan").
]]
local function ReadLeaderboard(logi)
	if not logi then return nil end
	for j = 1, GetNumQuestLeaderBoards(logi) do
		local text, _, done = GetQuestLogLeaderBoard(j, logi)
		if text and not done then
			local _, _, label, have, need = string.find(text, "^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
			if label then
				return label, tonumber(have), tonumber(need)
			end
			return text, nil, nil
		end
	end
	return nil
end
AegisPathfinder.ReadLeaderboard = ReadLeaderboard

local accepted = {}
local acceptedDirty = true
function AegisPathfinder:UpdateOHPanel(value)
	if not frame or not frame:IsVisible() then return end

	self:UpdateObjectiveTabs()
	-- The panel can be opened before any guide is parsed; everything below reads
	-- the step list and the current step directly.
	if not self.actions or not self.current then return end

	local total = table.getn(self.actions)
	--[[ Focus mode shows exactly one row: the step you are on.

		Everything below still walks the fixed row slots, so the two modes are
		the same code with a different window onto the step list -- one slot
		starting at the current step, or NUMROWS slots starting at the scroll
		offset. ]]
	local overview = self.db.char.overviewmode and true or false
	local shown = overview and NUMROWS or 1

	if self.guidechanged then
		self.guidechanged = nil
		acceptedDirty = true
		ResetScrollbar()
	end

	if overview then
		if value then offset = math.floor(value) end
		if (offset + NUMROWS) > total then offset = total - NUMROWS end
		if offset < 0 then offset = 0 end

		if offset == 0 then upbutt:Disable() else upbutt:Enable() end
		if offset == (total - NUMROWS) then downbutt:Disable() else downbutt:Enable() end
		scrollbar:Show()
	else
		-- One step, so there is nothing to scroll past.
		offset = self.current - 1
		scrollbar:Hide()
	end

	if not value or acceptedDirty then
		for i in pairs(accepted) do accepted[i] = nil end

		if self.actions then
			for i in pairs(self.actions) do
				local action, name = self:GetObjectiveInfo(i)
				local _, _, quest = string.find(name, L.PART_FIND)
				if quest and not accepted[quest] and not self:GetObjectiveStatus(i) then accepted[quest] = name end
			end
		end
		acceptedDirty = false
	end

	local doneCount = 0

	for i, row in ipairs(rows) do
		if i > shown then row:Hide()
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

			local shortname = string.gsub(name, L.PART_GSUB, "")
			logi = not turnedin and (not accepted[shortname] or (accepted[shortname] == name)) and logi
			complete = not turnedin and (not accepted[shortname] or (accepted[shortname] == name)) and complete
			local checked = turnedin or action == "ACCEPT" and logi or action == "COMPLETE" and complete

			local note = self:GetObjectiveTag("N", idx)

			-- In overview the objective folds into the note line, which is
			-- what the concept does with it there. In focus mode the meter
			-- below carries it instead, so the note stays the note.
			if overview and action == "COMPLETE" and logi and not complete then
				local label, have, need = ReadLeaderboard(logi)
				if label then
					note = need and string.format("%s - %d/%d", label, have, need) or label
				end
			end

			local qid = self:GetObjectiveTag("QID", idx)
			row.__tip = (qid and ("QID " .. qid .. (note and " \194\183 " or "")) or "") .. (note or "")
			if row.__tip == "" then row.__tip = nil end

			--[[ Band or row.

				A quest hand-off you are standing on, or have done, is a band;
				the same step further down the list is an ordinary row, so the
				list does not turn into a wall of colour.
			]]
			if BANDABLE[action] and (checked or isActive) then
				row.bg:Hide()
				row.activebar:Hide()
				row.check:Hide()
				row.icon:Hide()
				row.text:Hide()
				row.detail:Hide()

				local verb = VERB[action][checked and 2 or 1]
				row.band:Show()
				row.band:SetDone(checked)
				row.band.icon:SetTexture(checked and Theme.glyph.tick or Theme.glyph.bang)
				row.band.icon:SetVertexColor(1, 1, 1, 1)
				row.band.label:SetText(string.format("[%d] %s '%s'", idx, verb, name))
				row.band.tag:SetText(optional and "OPTIONAL" or "")
			else
				row.band:Hide()
				row.check:Show()
				row.icon:Show()
				row.text:Show()
				row.detail:Show()

				row.bg:Hide()
				row.activebar:Hide()

				if isActive then
					row.bg:SetVertexColor(1, 1, 1, 0.035)
					row.bg:Show()
					row.activebar:Show()
					Theme:TextColor(row.text, "text")
				elseif checked then
					-- The concept dims a done step rather than hiding it.
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
				row.check:SetChecked(checked)

				row.icon:SetTexture(self.icons[action])
				Theme:Tint(row.icon, checked and "subtle" or "textDim")

				row.text:SetText(string.format("[%d] %s", idx, name)
					.. (optional and L[" |cff808080(Optional)"] or ""))
				row.detail:SetText(note or "")

				if (self.current > idx) and optional and not checked then
					row.text:SetTextColor(0.5, 0.5, 0.5)
					row.check:Disable()
				else
					row.check:Enable()
				end

				if self.db.char.currentguide == "No Guide" then row.check:Disable() end
			end
		end
		end -- i > NUMROWS
	end

	--[[ Nav row and the progress rule.

		Steps behind the current one are the done ones: the addon advances
		past a step only once it is satisfied, which is the same measure the
		panel reported as "% complete" before. Counting them for real would
		mean a GetObjectiveStatus call per step on every scroll tick, and
		these guides run to a few hundred steps.
	]]
	doneCount = self.current - 1

	navStepNum:SetText(tostring(self.current))
	navCount:SetText(string.format("%d of %d \194\183 %d done", self.current, total, doneCount))
	guideProgress:SetProgress(total > 0 and (doneCount / total) or 0)

	--[[ The objective meter, under the single step in focus mode.

		Only for a step whose quest is in the log with countable objectives
		left. A step with nothing to count gets no meter rather than an empty
		one. ]]
	local showMeter = false
	if not overview then
		local action = self:GetObjectiveInfo(self.current)
		local _, logi, complete = self:GetObjectiveStatus(self.current)
		if action == "COMPLETE" and logi and not complete then
			local label, have, need = ReadLeaderboard(logi)
			if label and need and need > 0 then
				meter.label:SetText(label)
				meter.count:SetText(string.format("%d / %d", have, need))
				meter.bar:SetProgress(have / need)
				showMeter = true
			end
		end
	end
	if showMeter then meter:Show() else meter:Hide() end

	--[[ Footer: the current step's quest id, and progress through the guide.

		A data-source warning outranks the id. It is the most likely reason a
		waypoint points at nothing and it otherwise fails silently, so when
		there is one it takes the slot and turns red. ]]
	local qid, meta, isWarning = self:GetStepMeta(self.current)
	if isWarning then
		footerQid:SetText(meta)
		Theme:TextColor(footerQid, "danger")
	elseif qid then
		footerQid:SetText("QID " .. qid)
		Theme:TextColor(footerQid, "accent")
	else
		footerQid:SetText("")
	end
	footerCount:SetText(string.format("%d of %d steps completed", doneCount, total))
end
