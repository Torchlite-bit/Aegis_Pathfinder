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

--[[ Size.

	The concept's panel is as tall as what it shows, up to a max-height of
	min(70vh, 600px); its grip sets the width and that cap, never the height
	itself. So a step with a long note makes the panel taller, overview fills
	the cap, and nothing the player drags can leave the panel a size its
	content does not fit.
]]
local DEFAULT_WIDTH = 396                                      -- .panel{width:396px}
local OLD_DEFAULT_WIDTH = 630
local DEFAULT_ANCHOR = { "TOPRIGHT", "TOPRIGHT", -40, -180 }  -- top:180px; right:40px
local MIN_WIDTH, MAX_WIDTH = 320, 1200                         -- makeResizable minWidth
local DEFAULT_CAP, MIN_CAP = 600, 260                          -- max-height, minHeight
local NOTE_TOP = 31      -- where the note starts in a row: title's top, its line, a gap
local NOTE_BOTTOM = 8
local MAX_ROWS = 30
local NUMROWS = 1


local offset = 0
local rows = {}
local scrollbar, upbutt, downbutt
local navStepNum, navCount, guideProgress
local footerQid, footerCount, meter
local guideTabs = {}

--[[ Tab sizing.

	The bar shows at most VISIBLE_TABS guides at once -- fewer on a panel too
	narrow to give each TAB_W_MIN -- and a ‹ › pair scrolls through the rest.
	Squeezing every open guide into the bar instead is what reduced five of
	them to "Optim... North... Gilnea...".

	The tabs that are shown share the room, up to the concept's .tab
	max-width; below BADGE_MIN a tab drops its XP/TPL badge so the width goes
	to the name.
]]
local MAX_TABS = AegisPathfinder.MAX_GUIDE_TABS or 8
local VISIBLE_TABS = 4
local TAB_W_MAX = 190      -- .tab{max-width:190px}
local TAB_W_MIN = 100      -- narrower and the name is mostly ellipsis
local TAB_GAP = 2
local BADGE_MIN = 130
local ADD_W = TABBAR_H - 9
local ARROW_W = 16

-- The first tab in view, and what the bar last showed: the view follows the
-- active tab when that changes, and otherwise stays where the arrows put it.
local tabFirst, shownActive, shownCount = 1, nil, nil


local frame = CreateFrame("Frame", "AegisPathfinderObjectives", UIParent)
AegisPathfinder.objectiveframe = frame
frame:SetFrameStrata("DIALOG")
frame:SetWidth(DEFAULT_WIDTH)
frame:SetHeight(CHROME_TOP + ROWHEIGHT + FOOTER_H)
-- The concept parks it at top:180px; right:40px. There is no status card to
-- hang off any more, so it anchors to the screen.
frame:SetPoint(DEFAULT_ANCHOR[1], UIParent, DEFAULT_ANCHOR[2], DEFAULT_ANCHOR[3], DEFAULT_ANCHOR[4])
AegisPathfinder.objectiveskin = Theme:Panel(frame, "panel")
frame:Hide()
frame:SetScript("OnShow", function() AegisPathfinder:UpdateObjectivePanel() end)
table.insert(UISpecialFrames, "AegisPathfinderObjectives")
-- Stacks with the other windows rather than interleaving with them.
Theme:RegisterWindow(frame)

--- The tallest the panel may be: what the player set with the grip, or the
--- concept's min(70vh, 600px).
function AegisPathfinder:GetPanelCap()
	local cap = self.db.profile.objframemaxheight
	local screen = UIParent:GetHeight()
	if not cap then cap = math.min(DEFAULT_CAP, math.floor(screen * 0.7)) end
	return math.max(MIN_CAP, math.min(cap, screen - 20))
end


--[[ Resize grip.

	One generated texture rather than six placed dots: the cluster keeps its
	spacing, and hover is a single tint instead of a loop.

	Dragging it sideways sets the width; dragging it down or up sets the
	panel's height cap, which is the concept's grip exactly -- it writes
	`maxHeight`, not `height`. The panel's actual height is always what its
	content needs, up to that cap.

	It does its own sizing rather than calling StartSizing. The client's
	sizing re-anchors the frame as it sees fit, and a panel left anchored by
	its top and its bottom ignores SetHeight: that is how the panel got stuck
	at the size it had been dragged to, unable to follow the step or be moved.
]]
local grip = CreateFrame("Frame", nil, frame)
grip:SetWidth(14)
grip:SetHeight(14)
grip:SetPoint("BOTTOMRIGHT", -4, 4)
grip:EnableMouse(true)
grip:SetFrameLevel(frame:GetFrameLevel() + 4)
frame.grip = grip

local gripTex = grip:CreateTexture(nil, "OVERLAY")
gripTex:SetTexture(Theme.texture.grip)
gripTex:SetAllPoints(grip)
Theme:Tint(gripTex, "textDim", 0.55)

-- Cursor position in the panel's own units.
local function Cursor()
	local scale = frame:GetEffectiveScale()
	local x, y = GetCursorPosition()
	return x / scale, y / scale
end

local function StopSizing()
	grip.sizing = nil
	grip:SetScript("OnUpdate", nil)
	Theme:Tint(gripTex, "textDim", 0.55)
end

local function Sizing()
	local s = grip.sizing
	if not s then return end
	-- A button released somewhere the grip never heard about still ends it --
	-- where the client can say so (see OnMouseDown).
	if s.poll and not IsMouseButtonDown("LeftButton") then return StopSizing() end
	local x, y = Cursor()
	local db = AegisPathfinder.db.profile
	local w = math.max(MIN_WIDTH, math.min(MAX_WIDTH, math.floor(s.w + x - s.x + 0.5)))
	-- Screen y grows upward, so dragging down is a smaller y and a taller cap.
	local cap = math.max(MIN_CAP, math.min(UIParent:GetHeight() - 20, math.floor(s.cap + s.y - y + 0.5)))
	db.objframemaxheight = cap
	if w ~= frame:GetWidth() then
		db.objframewidth = w
		frame:SetWidth(w)          -- OnSizeChanged repaints
	else
		AegisPathfinder:UpdateOHPanel()
	end
end

grip:SetScript("OnMouseDown", function()
	Theme:Tint(gripTex, "accentGlow", 1)
	-- Grow right and down from where the panel is, whatever it was anchored by.
	Theme:AnchorTopLeft(frame)
	local x, y = Cursor()
	grip.sizing = {
		x = x, y = y, w = frame:GetWidth(), cap = AegisPathfinder:GetPanelCap(),
		-- Only poll the button if the client reports it down now, while it
		-- is: an IsMouseButtonDown that is missing or reads buttons some
		-- other way must not end every drag the moment it starts.
		poll = IsMouseButtonDown and IsMouseButtonDown("LeftButton") and true or false,
	}
	grip:SetScript("OnUpdate", Sizing)
end)
grip:SetScript("OnMouseUp", function()
	Sizing()
	StopSizing()
end)
grip:SetScript("OnEnter", function()
	Theme:Tint(gripTex, "accent", 1)
	Theme:ShowTip(this, "LEFT", "Drag to set the width and the tallest the panel may grow")
end)
grip:SetScript("OnLeave", function()
	if not grip.sizing then Theme:Tint(gripTex, "textDim", 0.55) end
	Theme:HideTip(this)
end)

--[[ Row anchors.

	Rows reach the scrollbar in overview, and the panel's edge in focus mode,
	where there is no scrollbar: anchored to a hidden one they left a strip of
	dead panel down the right-hand side.
]]
local rowsOverview
local function AnchorRows(overview)
	if rowsOverview == overview then return end
	rowsOverview = overview
	for i, row in ipairs(rows) do
		row:ClearAllPoints()
		if i == 1 then
			row:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -CHROME_TOP)
		else
			row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, 0)
		end
		if overview then
			row:SetPoint("RIGHT", scrollbar, "LEFT", -4, 0)
		else
			row:SetPoint("RIGHT", frame, "RIGHT", -1, 0)
		end
	end
end

-- The width a focus-mode note wraps to: the row, less the dot, the glyph and
-- the padding either side of the text.
local function NoteWidth()
	return frame:GetWidth() - 2 - (ROWPAD + DOTSIZE + 9 + ICONSIZE + 9) - ROWPAD
end

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
end


local function HideTooltip()
	Theme:HideTip(this)
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
		-- Beside the guide, not instead of it: the concept puts #options at
		-- right:456px and #objectives at right:40px, both on screen at once.
		AegisPathfinder:ToggleConfigPanel()
	end)
	menuChip:SetScript("OnEnter", function()
		this.fill:SetTint("text", 0.10)
		Theme:Tint(this.glyph, "text")
		Theme:ShowTip(this, "BOTTOM", L["Config"])
	end)
	menuChip:SetScript("OnLeave", function()
		this.fill:SetTint("text", 0.04)
		Theme:Tint(this.glyph, "textDim")
		Theme:HideTip(this)
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
		Theme:ShowTip(this, "BOTTOM", AegisPathfinder.db.char.overviewmode
			and "Show one step at a time" or "Show all steps")
	end)
	expandChip:SetScript("OnLeave", function()
		if not this.__active then
			this.fill:SetTint("text", 0.04)
			Theme:Tint(this.glyph, "textDim")
		end
		Theme:HideTip(this)
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

		One tab per open guide. Tab 1 is the main route -- what auto-advance
		follows -- and anything after it is a guide opened beside it. Clicking a tab switches to it, resuming where
		you left it; the ✕ closes it; the + opens another.

		Tabs are built once as a pool, one per possible guide, and the bar
		shows a window onto them -- as many as fit at a readable width, four
		at most -- with ‹ › to scroll the rest into view. Switching guides
		never creates a frame.

		The badge marks whether a guide is authored (XP) or a placeholder
		(TPL) -- the same signal the guide list carries, in the one place you
		are looking while you follow it.
	]]
	local tabbar = CreateFrame("Frame", nil, frame)
	tabbar:SetHeight(TABBAR_H)
	tabbar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
	tabbar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
	Theme:Strip(tabbar, "tabbg")
	Theme:Divider(tabbar, tabbar, "BOTTOMLEFT", 0, 0)

	local function MakeTab(index)
		local t = CreateFrame("Button", nil, tabbar)
		t:SetHeight(TABBAR_H - 5)
		t:SetWidth(TAB_W_MAX)
		t.index = index
		t.fill = Theme:NineSlice(t, Theme.texture.tabFill, "BACKGROUND", "tabbg")

		t.badge = Theme:Badge(t, "XP", "xp")
		t.badge:SetPoint("LEFT", t, "LEFT", 7, 0)

		t.label = t:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(t.label, "body", 11)
		t.label:SetJustifyH("LEFT")
		Theme:TextColor(t.label, "textDim")

		--- Show or drop the badge, and let the name take the room either way.
		function t:SetBadgeShown(shown)
			self.label:ClearAllPoints()
			if shown then
				self.badge:Show()
				self.label:SetPoint("LEFT", self.badge, "RIGHT", 6, 0)
			else
				self.badge:Hide()
				self.label:SetPoint("LEFT", self, "LEFT", 8, 0)
			end
			self.label:SetPoint("RIGHT", self, "RIGHT", -18, 0)
		end
		t:SetBadgeShown(true)

		-- Every tab closes, the first included. Closing the last leaves the
		-- panel empty, waiting for a guide to be chosen.
		t.close = Theme:GlyphButton(t, "close", 8, 14)
		t.close:SetPoint("RIGHT", t, "RIGHT", -4, 0)
		t.close.index = index
		t.close:SetScript("OnClick", function()
			AegisPathfinder:CloseTab(this.index)
			AegisPathfinder:UpdateObjectiveTabs()
		end)
		t.close:SetScript("OnEnter", function()
			Theme:Tint(this.glyph, "text")
			Theme:ShowTip(this, "BOTTOM", "Close this guide")
		end)
		t.close:SetScript("OnLeave", function()
			Theme:Tint(this.glyph, "textDim")
			Theme:HideTip(this)
		end)

		function t:SetActive(active)
			if active then
				self.fill:SetTint("panel")
				Theme:TextColor(self.label, "text")
			else
				self.fill:SetTint("tabbg")
				Theme:TextColor(self.label, "textDim")
			end
		end

		t:SetScript("OnClick", function()
			AegisPathfinder:SwitchToTab(this.index)
			AegisPathfinder:UpdateObjectiveTabs()
		end)
		t:SetScript("OnEnter", function()
			local tab = AegisPathfinder.db.char.tabs and AegisPathfinder.db.char.tabs[this.index]
			if not tab then return end
			Theme:ShowTip(this, "BOTTOM", this.index == 1
				and ("Main route: " .. tab.guide)
				or ("Switch to " .. tab.guide))
		end)
		t:SetScript("OnLeave", function() Theme:HideTip(this) end)

		t:Hide()
		return t
	end

	-- Anchored as they are shown, by UpdateObjectiveTabs: which tab sits
	-- first depends on where the bar is scrolled to.
	for i = 1, MAX_TABS do
		guideTabs[i] = MakeTab(i)
	end

	--[[ Scrolling the bar.

		‹ at the left edge, › after the last tab in view, both only while
		there are more guides open than the bar shows. Each moves the view by
		one tab and dims at its end. The wheel over the bar does the same.
	]]
	local function TabArrow(glyphName, delta, tip)
		local b = Theme:GlyphButton(tabbar, glyphName, 9, ARROW_W)
		b:SetScript("OnClick", function()
			if this.__disabled then return end
			AegisPathfinder:ScrollObjectiveTabs(delta)
		end)
		b:SetScript("OnEnter", function()
			if this.__disabled then return end
			Theme:Tint(this.glyph, "accent")
			Theme:ShowTip(this, "BOTTOM", tip)
		end)
		b:SetScript("OnLeave", function()
			Theme:Tint(this.glyph, this.__disabled and "subtle" or "textDim")
			Theme:HideTip(this)
		end)
		function b:SetEnabled(on)
			self.__disabled = not on
			Theme:Tint(self.glyph, on and "textDim" or "subtle")
		end
		function b:IsEnabled() return not self.__disabled end
		b:Hide()
		return b
	end
	local tabLeft = TabArrow("chevronLeft", -1, "Earlier guides")
	local tabRight = TabArrow("chevronRight", 1, "Later guides")
	-- Centred on the tabs, which sit on the bar's bottom edge.
	tabLeft:SetPoint("LEFT", tabbar, "BOTTOMLEFT", 8, (TABBAR_H - 5) / 2)

	tabbar:EnableMouseWheel(true)
	tabbar:SetScript("OnMouseWheel", function()
		AegisPathfinder:ScrollObjectiveTabs(-(arg1 or 0))
	end)

	local addTab = Theme:GlyphButton(tabbar, "plus", 10, TABBAR_H - 9)
	Theme:NineSlice(addTab, Theme.texture.tabBorder, "BORDER", "subtle")
	addTab:SetScript("OnClick", function()
		-- Opens beside the guide, not instead of it.
		AegisPathfinder.guidelistframe:Show()
	end)
	addTab:SetScript("OnEnter", function()
		Theme:Tint(this.glyph, "accent")
		Theme:ShowTip(this, "BOTTOM", "Open another guide")
	end)
	addTab:SetScript("OnLeave", function()
		Theme:Tint(this.glyph, "textDim")
		Theme:HideTip(this)
	end)

	frame.tabbar = tabbar
	frame.guideTabs, frame.addTab = guideTabs, addTab
	frame.tabLeft, frame.tabRight = tabLeft, tabRight
	-- The first tab is the main route; plenty of older code still reaches for
	-- it by this name.
	frame.mainTab = guideTabs[1]

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
			Theme:ShowTip(this, "BOTTOM", tip)
		end)
		btn:SetScript("OnLeave", function()
			Theme:Tint(this.glyph, "textDim")
			Theme:HideTip(this)
		end)
	end
	ArrowTip(prevArrow, "Previous objective")
	ArrowTip(nextArrow, "Skip to next objective")
	ArrowTip(doneArrow, "Mark complete and advance")
	navrow.stepControls = { prevArrow, nextArrow, doneArrow }

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

	footerCount = footer:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(footerCount, "body", 10)
	footerCount:SetPoint("RIGHT", footer, "RIGHT", -ROWPAD, 0)
	footerCount:SetJustifyH("RIGHT")
	Theme:TextColor(footerCount, "textDim")

	-- Up to the count and no further, on one line: a data-source warning is
	-- longer than a 396px footer has room for beside the count, and the
	-- whole of it is on the footer's tooltip.
	footerQid = footer:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(footerQid, "body", 10)
	footerQid:SetPoint("LEFT", footer, "LEFT", ROWPAD, 0)
	footerQid:SetPoint("RIGHT", footerCount, "LEFT", -8, 0)
	footerQid:SetHeight(12)
	footerQid:SetJustifyH("LEFT")
	Theme:TextColor(footerQid, "accent")

	footer:EnableMouse(true)
	footer:SetScript("OnEnter", function()
		if not this.warning then return end
		Theme:ShowTip(this, "TOP", this.warning, nil, "danger")
	end)
	footer:SetScript("OnLeave", function() Theme:HideTip(this) end)

	--[[ The shopping list opens from here, on a guide that has one. It says
		so in words: a bare icon in a footer is easy to miss, and on a craft
		step there is no quest id beside it to crowd. ]]
	local materials = Theme:GlyphButton(footer, Theme.actionIcon.B, 11, 18)
	materials:SetPoint("LEFT", footer, "LEFT", ROWPAD - 4, 0)
	materials.glyph:ClearAllPoints()
	materials.glyph:SetPoint("LEFT", materials, "LEFT", 4, 0)
	local matsLabel = materials:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(matsLabel, "display", 10)
	matsLabel:SetPoint("LEFT", materials.glyph, "RIGHT", 4, 0)
	matsLabel:SetText("SHOPPING LIST")
	Theme:TextColor(matsLabel, "textDim")
	materials.label = matsLabel
	materials:SetWidth(4 + 11 + 4 + math.ceil(matsLabel:GetStringWidth()) + 4)
	materials:SetScript("OnClick", function() AegisPathfinder:ToggleMaterialsPanel() end)
	materials:SetScript("OnEnter", function()
		Theme:Tint(this.glyph, "accent")
		Theme:TextColor(this.label, "accent")
		Theme:ShowTip(this, "TOP", "Reagents for this craft and the rest of the guide")
	end)
	materials:SetScript("OnLeave", function()
		Theme:Tint(this.glyph, "textDim")
		Theme:TextColor(this.label, "textDim")
		Theme:HideTip(this)
	end)
	materials:Hide()
	footer.materials = materials

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

		-- Top-aligned, as the concept's flex-start row is: a row that grows
		-- for a long note keeps its dot, glyph and title where they were.
		local check = Theme:StepCheck(row, DOTSIZE)
		check:SetPoint("TOPLEFT", row, "TOPLEFT", ROWPAD, -(ROWHEIGHT - DOTSIZE) / 2)

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

		--[[ The same note, in full. Focus mode shows one step, so it has the
			room to show all of it and grows to fit; the one-line version
			above is for the list, where a fixed row height is what lets a
			268-step guide scroll. Anchored by one corner and given a width,
			so its height is the wrapped text's and can be read back. ]]
		local note = row:CreateFontString(nil, "OVERLAY")
		Theme:SetFont(note, "body", 11)
		note:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
		note:SetJustifyH("LEFT")
		note:SetJustifyV("TOP")
		note:SetTextColor(0.56, 0.56, 0.52)
		note:Hide()

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
				Theme:ShowTip(this, "RIGHT", this.__tip)
			end
		end)
		row:SetScript("OnLeave", HideTooltip)

		row.text = text
		row.detail = detail
		row.note = note
		row.check = check
		row.icon = icon
		row.band = band
		rows[i] = row
	end
	AnchorRows(self.db.char.overviewmode and true or false)

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

	local empty = CreateFrame("Button", nil, frame)
	empty:SetHeight(ROWHEIGHT)
	empty:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -CHROME_TOP)
	empty:SetPoint("RIGHT", frame, "RIGHT", -1, 0)
	local emptyText = empty:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(emptyText, "body", 12)
	emptyText:SetPoint("CENTER", empty, "CENTER", 0, 0)
	emptyText:SetText("Click here to load a guide")
	Theme:TextColor(emptyText, "textDim")
	empty:SetScript("OnClick", function() AegisPathfinder.guidelistframe:Show() end)
	empty:SetScript("OnEnter", function() Theme:TextColor(emptyText, "accent") end)
	empty:SetScript("OnLeave", function() Theme:TextColor(emptyText, "textDim") end)
	empty.text = emptyText
	empty:Hide()
	frame.emptyState = empty

	frame:EnableMouseWheel()
	frame:SetScript("OnMouseWheel", function()
		scrollbar:SetValue(offset - arg1)
	end)

	-- Restore saved width and position. The height is never restored: it is
	-- whatever the content needs. A height saved by an older version was the
	-- overview height the player dragged to, which is what the cap now is.
	local profile = self.db.profile
	if profile.objframeheight then
		profile.objframemaxheight = profile.objframemaxheight or profile.objframeheight
		profile.objframeheight = nil
	end
	-- Earlier versions saved the width on every resize, the first layout
	-- included, so the old 630px default is stored for nearly everyone
	-- whether or not they chose it. Only a width set with the grip is kept.
	if profile.objframewidth == OLD_DEFAULT_WIDTH then profile.objframewidth = nil end
	if profile.objframewidth then
		frame:SetWidth(math.max(MIN_WIDTH, math.min(MAX_WIDTH, profile.objframewidth)))
	end
	Theme:RestorePosition(frame, "objframe")
	frame.expandChip:SetActive(self.db.char.overviewmode)

	self:OnObjectiveFrameResized()

	frame:SetScript("OnShow", OnShow)
	ww.SetFadeTime(frame, 0.5)
	OnShow(frame)
	return frame
end


--- Redraw the tab bar from the list of open guides.
function AegisPathfinder:UpdateObjectiveTabs()
	if not frame.guideTabs or not frame.guideTabs[1] then return end

	local tabs = self:EnsureTabs()
	local count = math.min(table.getn(tabs), MAX_TABS)
	local active = self.db.char.activetab or 1

	-- How many tabs fit at a readable width: 8px in from the left, the + and
	-- its gap on the right, and room for the arrows once they are needed.
	local function fit(room)
		local n = math.floor((room + TAB_GAP) / (TAB_W_MIN + TAB_GAP))
		return math.max(1, math.min(VISIBLE_TABS, n))
	end
	local room = frame:GetWidth() - 2 - 8 - (ADD_W + 4) - 8
	local overflow = count > fit(room)
	if overflow then room = room - 2 * (ARROW_W + 2) end
	local visible = math.min(count, fit(room))

	-- Follow the active tab when it changes -- a switch, an open, a close --
	-- and otherwise leave the view where the arrows put it, so a repaint does
	-- not yank it back.
	if active ~= shownActive or count ~= shownCount then
		if active < tabFirst then
			tabFirst = active
		elseif active > tabFirst + visible - 1 then
			tabFirst = active - visible + 1
		end
		shownActive, shownCount = active, count
	end
	tabFirst = math.max(1, math.min(tabFirst, count - visible + 1))
	local lastShown = tabFirst + visible - 1

	local width = TAB_W_MAX
	if visible > 0 then
		width = math.floor((room - (visible - 1) * TAB_GAP) / visible)
		if width > TAB_W_MAX then width = TAB_W_MAX end
	end

	local prev
	for i = 1, MAX_TABS do
		local button = frame.guideTabs[i]
		local tab = tabs[i]
		if not tab or i < tabFirst or i > lastShown then
			button:Hide()
		else
			button:ClearAllPoints()
			if prev then
				button:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", TAB_GAP, 0)
			else
				button:SetPoint("BOTTOMLEFT", frame.tabbar, "BOTTOMLEFT",
					overflow and (8 + ARROW_W + 2) or 8, 0)
			end
			button:Show()
			button:SetWidth(width)
			button:SetBadgeShown(width >= BADGE_MIN)
			-- The pack prefix ("Optimized/") is the same on every tab and
			-- costs a third of a narrow one; the tooltip keeps the full name.
			button.label:SetText((string.gsub(tab.guide, "^.*/", "")))
			button.badge:SetKind(self:IsTemplateGuide(tab.guide) and "tpl" or "xp",
				self:IsTemplateGuide(tab.guide) and "TPL" or "XP")
			button:SetActive(i == active)
			prev = button
		end
	end

	if overflow then
		frame.tabLeft:Show()
		frame.tabRight:Show()
		frame.tabLeft:SetEnabled(tabFirst > 1)
		frame.tabRight:SetEnabled(lastShown < count)
		frame.tabRight:ClearAllPoints()
		frame.tabRight:SetPoint("LEFT", prev, "RIGHT", 2, 0)
	else
		frame.tabLeft:Hide()
		frame.tabRight:Hide()
	end

	-- The + follows whatever is last, rather than floating where a closed
	-- tab used to be.
	frame.addTab:ClearAllPoints()
	if overflow then
		frame.addTab:SetPoint("LEFT", frame.tabRight, "RIGHT", 4, 0)
	elseif prev then
		frame.addTab:SetPoint("LEFT", prev, "RIGHT", 4, 0)
	else
		frame.addTab:SetPoint("LEFT", frame.tabbar, "LEFT", 8, 0)
	end

	-- Past MAX_TABS there is nowhere to put another tab, so stop offering.
	if table.getn(tabs) >= MAX_TABS then frame.addTab:Hide() else frame.addTab:Show() end
end

--- Move the tab bar's view by `delta` tabs. Only the view: the guide you are
--- reading stays the one you are reading until you click a tab.
function AegisPathfinder:ScrollObjectiveTabs(delta)
	tabFirst = tabFirst + (delta or 0)
	self:UpdateObjectiveTabs()
end

--[[ The panel with every guide closed.

	The rows, the meter and the counts all describe a guide, so they go, and
	the list area becomes one line inviting the player to pick one. It is a
	button: clicking it opens the guide list, which is where a guide comes
	from.
]]
function AegisPathfinder:ShowEmptyState(empty)
	if not frame.emptyState then return end
	if empty then
		for _, row in ipairs(rows) do row:Hide() end
		meter:Hide()
		scrollbar:Hide()
		navStepNum:SetText("")
		navCount:SetText("")
		guideProgress:SetProgress(0)
		footerQid:SetText("")
		footerCount:SetText("")
		frame.footer.materials:Hide()
		frame.emptyState:Show()
	else
		frame.emptyState:Hide()
	end
	-- Stepping through a guide needs a guide.
	for _, b in ipairs(frame.navrow.stepControls) do
		if empty then b:Hide() else b:Show() end
	end
end

--[[ Size the panel to what it shows.

	The concept's panel is height:auto under a max-height: focus mode is as
	tall as the one step (its note in full) and the meter under it; overview
	is as tall as the list, which for any real guide means the cap. Nothing
	here is saved -- the cap is the player's, the height is the content's.

	The panel is pinned by a top corner before its height changes, so it
	grows and shrinks from the bottom edge rather than moving its header.
]]
function AegisPathfinder:PanelContentHeight()
	if self:HasNoGuide() then return ROWHEIGHT + 6 end
	if self.db.char.overviewmode then
		local total = self.actions and table.getn(self.actions) or 0
		return math.max(1, math.min(total, MAX_ROWS)) * ROWHEIGHT + 2
	end
	local h = rows[1] and rows[1]:GetHeight() or ROWHEIGHT
	if frame.meter and frame.meter:IsShown() then
		h = h + 2 + frame.meter:GetHeight()
	end
	return h + 8
end

function AegisPathfinder:LayoutPanelHeight()
	if not frame.footer then return end
	-- SetHeight fires OnSizeChanged, which resizes, which repaints, which
	-- lands back here; without this guard the first layout never returns.
	if frame.layoutlock then return end

	local h = CHROME_TOP + self:PanelContentHeight() + FOOTER_H
	h = math.min(h, self:GetPanelCap())

	frame.layoutlock = true
	local point = frame:GetPoint(1)
	if frame:GetNumPoints() ~= 1 or not point or not string.find(point, "^TOP") then
		Theme:AnchorTopLeft(frame)
	end
	frame:SetHeight(h)
	frame.layoutlock = nil
end

--[[ How many step rows to draw right now.

	Focus mode draws exactly one whatever the panel's height. Overview draws
	as many as fit. Derived from the panel's current size on every call rather
	than cached, because the mode and the height both change and a cached count
	left the list a paint behind whichever changed last.
]]
function AegisPathfinder:VisibleRowCount()
	if not self.db.char.overviewmode then return 1 end
	local fits = math.floor((frame:GetHeight() - CHROME_TOP - FOOTER_H) / ROWHEIGHT)
	return math.max(1, math.min(fits, MAX_ROWS))
end

function AegisPathfinder:OnObjectiveFrameResized()
	-- Mid-layout the panel is already being told what size to be.
	if frame.layoutlock then return end
	-- The width is saved by the grip, which is the player choosing it; a
	-- resize for any other reason is not a choice worth remembering.

	NUMROWS = self:VisibleRowCount()
	for i, row in ipairs(rows) do
		if i > NUMROWS then row:Hide() end
	end
	-- Tabs share the bar's width, so a narrower panel narrows them.
	self:UpdateObjectiveTabs()

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
	-- The panel's height, the row count and the scrollbar all follow the mode.
	self:LayoutPanelHeight()
	self:OnObjectiveFrameResized()
	self:UpdateOHPanel()
end

--[[ Put every window back where it opens by default, at its default size.

	The way out when a window has ended up somewhere unusable. Positions and
	the panel's width and cap are forgotten; the guide goes back to the
	concept's top-right spot, the arrow to the top of the screen, and the
	panels that snap beside the guide do so again when next opened.
]]
local WINDOW_KEYS = {
	"objframe", "optionsframe", "guidelistframe", "materialsframe",
	"errorlogframe", "startzoneframe", "navcallout", "creditsframe",
}

function AegisPathfinder:ResetWindowLayout()
	for _, key in ipairs(WINDOW_KEYS) do Theme:ForgetPosition(key) end
	local profile = self.db.profile
	profile.objframewidth, profile.objframemaxheight, profile.objframeheight = nil, nil, nil

	frame:ClearAllPoints()
	frame:SetPoint(DEFAULT_ANCHOR[1], UIParent, DEFAULT_ANCHOR[2], DEFAULT_ANCHOR[3], DEFAULT_ANCHOR[4])
	frame:SetWidth(DEFAULT_WIDTH)
	self:LayoutPanelHeight()
	self:UpdateOHPanel()

	if self.navcallout then
		self.navcallout:ClearAllPoints()
		self.navcallout:SetPoint("TOP", UIParent, "TOP", 0, -120)
	end
	if self.ResetItemButton then self:ResetItemButton() end
	-- By name: any of these may not have been built yet.
	for _, key in ipairs({ "errorLogFrame", "startingZoneSelectorFrame", "creditsframe" }) do
		local w = self[key]
		if w then
			w:ClearAllPoints()
			w:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
	end
	-- These place themselves beside the guide as they open.
	for _, key in ipairs({ "optionsframe", "guidelistframe", "materialsframe" }) do
		local w = self[key]
		if w and w:IsShown() then w:Hide(); w:Show() end
	end
	-- Resizing the panel above saves its width as it goes; forget it again.
	profile.objframewidth = nil
	self:Print("Windows reset to where they open by default.")
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

	local empty = self:HasNoGuide()
	self:ShowEmptyState(empty)
	if empty then
		self:LayoutPanelHeight()
		return
	end

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
	AnchorRows(overview)

	--[[ The meter, then the height, then the row count -- in that order.

		Focus mode's height depends on whether the meter is showing, and how
		many rows fit depends on the height, so settling them in any other
		order leaves the list a paint behind whichever changed last.

		The meter is only for a step whose quest is in the log with countable
		objectives left; a step with nothing to count gets no meter rather
		than an empty one.
	]]
	local showMeter = false
	if not overview then
		local curAction = self:GetObjectiveInfo(self.current)
		local _, curLogi, curComplete = self:GetObjectiveStatus(self.current)
		if curAction == "COMPLETE" and curLogi and not curComplete then
			local label, have, need = ReadLeaderboard(curLogi)
			if label and need and need > 0 then
				meter.label:SetText(label)
				meter.count:SetText(string.format("%d / %d", have, need))
				meter.bar:SetProgress(have / need)
				showMeter = true
			end
		end
	end
	if showMeter then meter:Show() else meter:Hide() end
	self:LayoutPanelHeight()

	local shown = self:VisibleRowCount()
	NUMROWS = shown

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
				row:SetHeight(ROWHEIGHT)
				row.note:Hide()
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

				-- The list keeps every row one height; the one step in focus
				-- mode shows its whole note and grows to fit it.
				if overview then
					row.note:Hide()
					row.detail:Show()
					row:SetHeight(ROWHEIGHT)
				else
					row.detail:Hide()
					row.note:SetWidth(NoteWidth())
					row.note:SetText(note or "")
					row.note:Show()
					local noteH = 0
					if note and note ~= "" then
						noteH = row.note:GetHeight() or 0
						-- A client that will not measure wrapped text: estimate
						-- the lines from the unwrapped width.
						if noteH < 1 then
							noteH = math.ceil(row.note:GetStringWidth() / NoteWidth()) * 14
						end
					end
					row:SetHeight(math.max(ROWHEIGHT, NOTE_TOP + noteH + NOTE_BOTTOM))
				end

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

	-- Focus mode's height is the step's, which is only known once it is
	-- painted.
	if not overview then self:LayoutPanelHeight() end

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

	--[[ Footer: the current step's quest id, and progress through the guide.

		A data-source warning outranks the id. It is the most likely reason a
		waypoint points at nothing and it otherwise fails silently, so when
		there is one it takes the slot and turns red. ]]
	local qid, meta, isWarning = self:GetStepMeta(self.current)
	frame.footer.warning = isWarning and meta or nil

	local materials = frame.footer.materials
	footerQid:ClearAllPoints()
	if self:GuideHasMaterials() then
		materials:Show()
		footerQid:SetPoint("LEFT", materials, "RIGHT", 6, 0)
	else
		materials:Hide()
		footerQid:SetPoint("LEFT", frame.footer, "LEFT", ROWPAD, 0)
	end
	footerQid:SetPoint("RIGHT", footerCount, "LEFT", -8, 0)
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
