--[[ TalentWindow.lua -- the Talent Advisor, on Blizzard's talent window.

	Laid over the client's own window (Blizzard_TalentUI, loaded when it is
	first opened), and over pfUI's skin of it:

	  * a strip above the window: the build followed, as a menu to pick
	    another, where the next point goes, and how many points are off the
	    build -- or why the build is not followed;
	  * on each talent of the tree shown, a badge with the points the build
	    puts there: filled while some are still to take, quiet once you have
	    them all, amber "+N" for points the build does not put there;
	  * a glow and "NEXT" over the talent the next point goes to, and a dot on
	    its tree's tab. The window opens on that tree;
	  * a line on the talent's tooltip.

	It only marks; the points are yours to spend. What it shows is
	TalentAdvisor.lua's; this is the drawing of it.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme
local TA = AegisPathfinder.TalentAdvisor

local TW = {}
TA.Window = TW

-- Layout, in one table: see the 32-upvalue note in CONTRIBUTING.md.
local G = {
	PAD = 10, ROW1 = -9, DROP = -24, NOTE = -60, WARN = -76, HEIGHT = 80, WARN_HEIGHT = 96,
	-- Where the strip sits on the client's window art: over its frame's top
	-- edge, as wide as the frame. pfUI's backdrop is the frame there.
	ART_LEFT = 12, ART_RIGHT = -34, ART_TOP = -10,
	BADGE_H = 16, GLOW = 64, NEXT_W = 38, NEXT_H = 13, DOT = 8,
	-- "+N": the mock-up's amber, and the dark text on it.
	AMBER = { 0.94, 0.71, 0.24 }, ON_AMBER = { 0.10, 0.07, 0.02 }, ON_ACCENT = { 0.04, 0.04, 0.04 },
	QUIET = { 0.04, 0.04, 0.04 },
}

local BADGE_GEOM = { corner = 8 }

--[[ The strip ---------------------------------------------------------------- ]]

local function Text(parent, role, size, color)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(fs, role, size)
	fs:SetJustifyH("LEFT")
	Theme:TextColor(fs, color)
	return fs
end

function TW:BuildStrip()
	local strip = CreateFrame("Frame", "AegisPathfinderTalentStrip", TalentFrame)
	strip:SetHeight(G.HEIGHT)
	strip:SetFrameLevel(TalentFrame:GetFrameLevel() + 6)
	strip:EnableMouse(true)
	Theme:CapStrip(strip, "panel2", "top")

	local brand = Text(strip, "display", 12, "accentGlow")
	brand:SetPoint("TOPLEFT", strip, "TOPLEFT", G.PAD, G.ROW1)
	brand:SetText("PATHFINDER")
	local following = Text(strip, "body", 12, "textDim")
	following:SetPoint("LEFT", brand, "RIGHT", 8, 0)
	following:SetText("Following")

	local drop = Theme:Dropdown(strip, 200, function(value) TW:Choose(value) end)
	drop:SetPoint("TOPLEFT", strip, "TOPLEFT", G.PAD, G.DROP)
	drop:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -G.PAD, G.DROP)

	local note = Text(strip, "body", 12, "text")
	note:SetPoint("TOPLEFT", strip, "TOPLEFT", G.PAD, G.NOTE)
	note:SetPoint("RIGHT", strip, "RIGHT", -G.PAD, 0)
	note:SetHeight(14)
	local warn = Text(strip, "body", 11, G.AMBER)
	warn:SetPoint("TOPLEFT", strip, "TOPLEFT", G.PAD, G.WARN)
	warn:SetPoint("RIGHT", strip, "RIGHT", -G.PAD, 0)
	warn:SetHeight(14)

	strip.drop, strip.note, strip.warn = drop, note, warn
	self.strip = strip
	strip:Hide()
	return strip
end

--- Over the window's frame, or pfUI's backdrop of it; the menu's list as
--- wide as the strip.
function TW:Place()
	local strip, bd = self.strip, TalentFrame.backdrop
	strip:ClearAllPoints()
	if bd then
		strip:SetPoint("BOTTOMLEFT", bd, "TOPLEFT", 0, 1)
		strip:SetPoint("BOTTOMRIGHT", bd, "TOPRIGHT", 0, 1)
	else
		strip:SetPoint("BOTTOMLEFT", TalentFrame, "TOPLEFT", G.ART_LEFT, G.ART_TOP)
		strip:SetPoint("BOTTOMRIGHT", TalentFrame, "TOPRIGHT", G.ART_RIGHT, G.ART_TOP)
	end
	local w = strip:GetWidth()
	if w and w > 0 then strip.drop.list:SetWidth(w - 2 * G.PAD) end
end

function TW:PaintStrip(state)
	local strip = self.strip
	strip.drop:SetItems(TA:BuildItems(state))
	strip.drop:SetValue(state.choice or "auto")
	local line, warn = TA:StripLines(state)
	strip.note:SetText(line or "")
	strip.warn:SetText(warn or "")
	-- Without a line, the warning takes its place.
	strip.warn:ClearAllPoints()
	strip.warn:SetPoint("TOPLEFT", strip, "TOPLEFT", G.PAD, line and G.WARN or G.NOTE)
	strip.warn:SetPoint("RIGHT", strip, "RIGHT", -G.PAD, 0)
	strip:SetHeight((line and warn) and G.WARN_HEIGHT or G.HEIGHT)
	strip:Show()
end

--- A build picked from the strip's menu: the same setting as the options'.
function TW:Choose(value)
	local s = TA:Settings()
	if not s then return end
	s.talentbuild = value
	self:Repaint()
	AegisPathfinder:RefreshConfigPanel()
end

--[[ The marks ---------------------------------------------------------------- ]]

--- A talent button's marks, made the first time: the badge at its top
--- right (its rank is at the bottom right), the glow and "NEXT" over it.
function TW:Marks(button)
	if button.apMarks then return button.apMarks end
	local m = CreateFrame("Frame", nil, button)
	m:SetAllPoints(button)
	m:SetFrameLevel(button:GetFrameLevel() + 3)

	local glow = m:CreateTexture(nil, "OVERLAY")
	glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	glow:SetBlendMode("ADD")
	glow:SetWidth(G.GLOW); glow:SetHeight(G.GLOW)
	glow:SetPoint("CENTER", button, "CENTER", 0, 0)
	Theme:Tint(glow, "accent")

	local tag = CreateFrame("Frame", nil, m)
	tag:SetWidth(G.NEXT_W); tag:SetHeight(G.NEXT_H)
	tag:SetPoint("BOTTOM", button, "TOP", 0, 3)
	Theme:Strip(tag, "accent")
	local tagText = tag:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(tagText, "display", 10)
	tagText:SetPoint("CENTER", tag, "CENTER", 0, 0)
	tagText:SetTextColor(G.ON_ACCENT[1], G.ON_ACCENT[2], G.ON_ACCENT[3])
	tagText:SetText("NEXT")

	local badge = CreateFrame("Frame", nil, m)
	badge:SetHeight(G.BADGE_H)
	badge:SetPoint("CENTER", button, "TOPRIGHT", -1, -1)
	badge.fill = Theme:NineSlice(badge, Theme.texture.pillFill, "BACKGROUND", "accentDeep", nil, BADGE_GEOM)
	badge.border = Theme:NineSlice(badge, Theme.texture.pillBorder, "BORDER", "accent", nil, BADGE_GEOM)
	badge.text = badge:CreateFontString(nil, "OVERLAY")
	Theme:SetFont(badge.text, "display", 11)
	badge.text:SetPoint("CENTER", badge, "CENTER", 0, 0)

	m.glow, m.tag, m.badge = glow, tag, badge
	button.apMarks = m
	return m
end

-- Each kind of badge: its fill, its edge, its text.
local BADGE = {
	todo = { "accentDeep", "accent", "text" },
	done = { G.QUIET, "accentDeep", "accentGlow" },
	off = { G.AMBER, G.AMBER, G.ON_AMBER },
}

function TW:PaintMark(button, state, name)
	local m = self:Marks(button)
	local kind, text, isNext
	if name and button:IsShown() then kind, text, isNext = TA.Mark(state, name) end
	local badge = m.badge
	if kind then
		local look = BADGE[kind]
		badge.fill:SetTint(look[1])
		badge.border:SetTint(look[2])
		Theme:TextColor(badge.text, look[3])
		badge.text:SetText(text)
		badge:SetWidth(math.max(G.BADGE_H, badge.text:GetStringWidth() + 10))
		badge:Show()
	else
		badge:Hide()
	end
	if isNext then m.glow:Show(); m.tag:Show() else m.glow:Hide(); m.tag:Hide() end
	m:Show()
end

--- The dot on the tab of the tree the next point goes to, left of its name.
function TW:PaintDot(tab, on)
	if not tab.apDot then
		local dot = tab:CreateTexture(nil, "OVERLAY")
		dot:SetTexture(Theme.texture.circleFill)
		dot:SetWidth(G.DOT); dot:SetHeight(G.DOT)
		local label = getglobal(tab:GetName() .. "Text")
		if label then dot:SetPoint("RIGHT", label, "LEFT", -3, 0) else dot:SetPoint("LEFT", tab, "LEFT", 6, 0) end
		Theme:Tint(dot, "accent")
		tab.apDot = dot
	end
	if on then tab.apDot:Show() else tab.apDot:Hide() end
end

function TW:Clear()
	for i = 1, (MAX_NUM_TALENTS or 20) do
		local button = getglobal("TalentFrameTalent" .. i)
		if button and button.apMarks then button.apMarks:Hide() end
	end
	for i = 1, (MAX_TALENT_TABS or 5) do
		local tab = getglobal("TalentFrameTab" .. i)
		if tab and tab.apDot then tab.apDot:Hide() end
	end
end

--[[ Painting ----------------------------------------------------------------- ]]

--- The advisor's state while it is on and has a build for your class.
local function Current()
	local s = TA:Settings()
	if not (s and s.talentadvisor) then return nil end
	return TA:State()
end

--- Mark the window as it is now: after the client has drawn it.
function TW:Paint()
	if not (self.strip and TalentFrame and TalentFrame:IsShown()) then return end
	local state = Current()
	if not state then
		self.strip:Hide()
		return self:Clear()
	end
	self:Place()
	self:PaintStrip(state)
	if not state.fits then return self:Clear() end
	local tab = PanelTemplates_GetSelectedTab(TalentFrame) or 1
	local count = GetNumTalents(tab) or 0
	for i = 1, (MAX_NUM_TALENTS or 20) do
		local button = getglobal("TalentFrameTalent" .. i)
		if button then
			local name = i <= count and GetTalentInfo(tab, i) or nil
			self:PaintMark(button, state, name)
		end
	end
	local t = state.next and state.tree.talent[state.next]
	for i = 1, (MAX_TALENT_TABS or 5) do
		local tabButton = getglobal("TalentFrameTab" .. i)
		if tabButton then self:PaintDot(tabButton, t and t.tab == i) end
	end
end

--- Draw it all again, the client's part too, if the window is open.
function TW:Repaint()
	if TalentFrame and TalentFrame:IsShown() and TalentFrame_Update then TalentFrame_Update() end
end

--- Open on the tree the next point goes to.
function TW:ShowNextTree()
	local state = Current()
	local t = state and state.fits and state.next and state.tree.talent[state.next]
	if t then PanelTemplates_SetTab(TalentFrame, t.tab) end
end

--- The talent's tooltip: the advisor's lines under the client's.
function TW:AddTip(tip, tab, index)
	local name = GetTalentInfo(tab, index)
	local state = name and Current()
	if not (state and state.fits) then return end
	local lines = TA:TipLines(state, name)
	if table.getn(lines) == 0 then return end
	local c = Theme.color.accentGlow
	tip:AddLine(" ")
	for _, line in ipairs(lines) do tip:AddLine(line, c[1], c[2], c[3], 1) end
	tip:Show()
end

--[[ Hooks -------------------------------------------------------------------- ]]

--[[ The client's window calls its functions by name -- on showing, on a tab
	clicked, on points spent -- so each is wrapped where it is kept. Once:
	when Blizzard_TalentUI has loaded. ]]
function TW:Hook()
	if self.hooked or not (TalentFrame and TalentFrame_Update) then return end
	self.hooked = true
	self:BuildStrip()
	local update, onShow = TalentFrame_Update, TalentFrame_OnShow
	TalentFrame_Update = function()
		update()
		TW:Paint()
	end
	TalentFrame_OnShow = function()
		TW:ShowNextTree()
		onShow()
	end
end

-- The tooltip is the client's own, for every talent; the line is added after.
local setTalent = GameTooltip.SetTalent
GameTooltip.SetTalent = function(tip, tab, index)
	setTalent(tip, tab, index)
	TW:AddTip(tip, tab, index)
end

local events = CreateFrame("Frame")
TW.events = events
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function()
	if arg1 == "Blizzard_TalentUI" then TW:Hook() end
end)
-- Another addon may have loaded it already.
if IsAddOnLoaded and IsAddOnLoaded("Blizzard_TalentUI") then TW:Hook() end

--- Open the talent window, as its key does: from level 10.
function TA:OpenWindow()
	if (UnitLevel("player") or 0) < TA.FIRST_LEVEL then
		return AegisPathfinder:Print("Talents come at level " .. TA.FIRST_LEVEL .. ".")
	end
	if ToggleTalentFrame then ToggleTalentFrame() end
end
