--[[
	Executes Theme.lua against the stub API and asserts the results.

	This is the closest thing to a test the addon can have off-client: it does
	not prove the UI looks right, but it proves every Theme entry point runs,
	builds the regions it claims to, and stays inside the API's contract.

	Run:  lua5.1 Tools/test_theme.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

AegisPathfinder = {}
dofile("Theme.lua")
local Theme = AegisPathfinder.Theme

local failures, checks = {}, 0

local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local function countRegions(frame, kind)
	local n = 0
	for _, r in ipairs(frame.__regions) do
		if r.__kind == kind then n = n + 1 end
	end
	return n
end

-- Palette -------------------------------------------------------------------

check(Theme.color.accent[1] > 0.32 and Theme.color.accent[1] < 0.33,
	"accent red channel should be 82/255, got %s", tostring(Theme.color.accent[1]))
check(Theme.color.accent[2] > 0.78 and Theme.color.accent[2] < 0.79,
	"accent green channel should be 199/255, got %s", tostring(Theme.color.accent[2]))
for name, c in pairs(Theme.color) do
	check(type(c) == "table" and table.getn(c) == 3, "colour '%s' is not an rgb triple", name)
	for i = 1, 3 do
		check(type(c[i]) == "number" and c[i] >= 0 and c[i] <= 1,
			"colour '%s' channel %d out of range: %s", name, i, tostring(c[i]))
	end
end

-- Every action code in the guide DSL needs an icon.
local CODES = { "A", "T", "C", "N", "R", "H", "h", "F", "f", "B", "b", "K", "G", "U", "t", "D", "P" }
for _, code in ipairs(CODES) do
	check(Theme.actionIcon[code] ~= nil, "no icon mapped for action code '%s'", code)
end

-- Texture paths must be extensionless (the client appends its own).
for name, path in pairs(Theme.texture) do
	check(not string.find(path, "%.tga$"), "texture '%s' carries a file extension", name)
end

-- Nine-slice -----------------------------------------------------------------

local frame = CreateFrame("Frame", nil, UIParent)
local slice = Theme:NineSlice(frame, Theme.texture.panelFill, "BACKGROUND", "panel")
check(countRegions(frame, "Texture") == 9, "nine-slice should build 9 textures, built %d",
	countRegions(frame, "Texture"))
for _, part in ipairs({ "tl", "tr", "bl", "br", "top", "bottom", "left", "right", "center" }) do
	check(slice[part] ~= nil, "nine-slice missing '%s'", part)
end
check(slice.tl.__texcoord[1] == 0 and slice.tl.__texcoord[3] == 0,
	"top-left slice should sample the texture's top-left corner")
check(slice.br.__texcoord[2] == 1 and slice.br.__texcoord[4] == 1,
	"bottom-right slice should sample the texture's bottom-right corner")
check(slice.tl.__width == Theme.CORNER, "corner width should be %d, got %s",
	Theme.CORNER, tostring(slice.tl.__width))
slice:SetTint("accent")
check(slice.center.__color[2] > 0.78, "SetTint should recolour every slice")

-- The panel's shadow: a ring outside the panel's edge, not a blob across it.
-- It shares the fill's layer and 1.12 does not order textures within one, so
-- a shadow with anything in its middle can draw straight through the panel.
local shadowed = CreateFrame("Frame", nil, UIParent)
local skin = Theme:Panel(shadowed, "panel")
check(skin.shadow.center == nil, "the shadow has no middle piece to draw over the panel")
check(skin.shadow.tl.__texture == Theme.texture.shadow, "it is the shadow texture")
local _, _, _, sx, sy = skin.shadow.tl:GetPoint()
check(sx == -7 and sy == 7, "and it sits 7px outside the panel's corner, got %s,%s",
	tostring(sx), tostring(sy))
local _, _, _, bx, by = skin.shadow.br:GetPoint()
check(bx == 7 and by == -7, "on every side, got %s,%s", tostring(bx), tostring(by))
check(skin.shadow.tl.__width == 18, "its corners hold the whole corner arc, got %s",
	tostring(skin.shadow.tl.__width))

-- Tooltip --------------------------------------------------------------------

-- The addon's own card, not GameTooltip -- which is shared with the whole UI,
-- so restyling it would restyle every other addon's tooltips too.
local owner = CreateFrame("Button", nil, UIParent)
owner:SetWidth(20); owner:SetHeight(20)
owner:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
Theme:ShowTip(owner, "BOTTOM", "Close this guide")
local tip = Theme.tip
check(tip ~= nil and tip:IsShown(), "ShowTip shows the themed card")
check(tip.__strata == "TOOLTIP", "above every window")
check(tip.lines[1]:GetText() == "Close this guide", "carrying the hint")
check(tip.lines[1].__color and tip.lines[1].__color[1] > 0.9, "in the theme's text colour")
local tp, towner, trel = tip:GetPoint(1)
check(tp == "TOP" and towner == owner and trel == "BOTTOM", "opening under its owner")
local short = tip:GetWidth()
check(short < 150, "as wide as a short hint needs, got %s", short)

Theme:ShowTip(owner, "RIGHT", "Elwynn Forest (1-10)",
	{ "Left-click: Open in a new tab", "Right-click: Load in the current tab" })
check(tip.lines[2]:IsShown() and tip.lines[3]:IsShown(), "detail lines follow the hint")
check(tip.lines[2].__color[1] < tip.lines[1].__color[1], "dimmer than it")
check(tip:GetHeight() > 3 * 12, "and the card grows to hold them, got %s", tip:GetHeight())
Theme:ShowTip(owner, "BOTTOM", string.rep("A long note about where to go next. ", 20))
check(tip:GetWidth() <= 260 + 16, "a long hint wraps rather than running off, %s wide", tip:GetWidth())
check(not tip.lines[2]:IsShown(), "and lines from the last tip are not left behind")
Theme:ShowTip(owner, "TOP", "Guide data: OctoWoW", nil, "danger")
check(tip.lines[1].__color[1] > 0.85 and tip.lines[1].__color[2] < 0.5, "a warning can take the danger colour")

local other = CreateFrame("Button", nil, UIParent)
Theme:HideTip(other)
check(tip:IsShown(), "another frame's OnLeave does not hide a tip it does not own")
Theme:HideTip(owner)
check(not tip:IsShown(), "its owner's does")

-- An owner hidden under the cursor -- a tab closed by its own button -- gets
-- no OnLeave; the card notices and goes.
Theme:ShowTip(owner, "BOTTOM", "Close this guide")
owner:Hide()
local old = this
this = tip
tip:GetScript("OnUpdate")()
this = old
check(not tip:IsShown(), "a tooltip does not outlive its owner")

-- Progress bar ---------------------------------------------------------------

local bar = Theme:ProgressBar(UIParent, 5)
bar:SetWidth(100)
bar:SetProgress(0.5)
check(bar.fill:GetWidth() == 50, "50%% of a 100px bar should be 50px, got %s",
	tostring(bar.fill:GetWidth()))
bar:SetProgress(0)
check(not bar.fill:IsShown(), "a zero-progress fill should be hidden, not zero-width")
bar:SetProgress(1)
check(bar.fill:GetWidth() == 100, "full progress should fill the bar")
bar:SetProgress(5)
check(bar.fill:GetWidth() == 100, "out-of-range progress should clamp, got %s",
	tostring(bar.fill:GetWidth()))
bar:SetProgress(-1)
check(not bar.fill:IsShown(), "negative progress should clamp to empty")
bar:SetProgress(nil)
check(not bar.fill:IsShown(), "nil progress should be treated as empty, not error")

-- Step check -----------------------------------------------------------------

local chk = Theme:StepCheck(UIParent, 15)
check(chk.__kind == "CheckButton",
	"the step check must be a CheckButton so it keeps the widget API the old "
	.. "Blizzard checkbox exposed, got %s", tostring(chk.__kind))
check(not chk.fill:IsShown(), "a new step check starts unchecked")
check(chk:GetChecked() == false, "a new step check reports unchecked")
chk:SetChecked(true)
check(chk.fill:IsShown(), "SetChecked(true) should reveal the fill")
check(chk:GetChecked() == true, "SetChecked(true) should be readable back")
chk:SetChecked(false)
check(not chk.fill:IsShown(), "SetChecked(false) should hide the fill")

check(not chk.halo:IsShown(), "the auto-detect halo starts hidden")
chk:SetAutoEligible(true)
check(chk.halo:IsShown(), "SetAutoEligible(true) should reveal the halo")
-- A completed step has nothing left to auto-detect, so the halo must go.
chk:SetChecked(true)
chk:SetAutoEligible(true)
check(not chk.halo:IsShown(), "a checked step should not advertise auto-detection")
chk:SetChecked(false)
chk:SetAutoEligible(false)
check(not chk.halo:IsShown(), "SetAutoEligible(false) should hide the halo")

-- Pill -----------------------------------------------------------------------

local pill = Theme:Pill(UIParent, "RestedXP", 90, 22)
check(pill.label:GetText() == "RESTEDXP", "pill labels are uppercased, got '%s'",
	tostring(pill.label:GetText()))
pill:SetActive(true)
check(pill.fill.center.__color[2] > 0.78, "an active pill fills with accent")

-- Band -----------------------------------------------------------------------

local band = Theme:Band(UIParent, 26)
check(band.bg.__color[1] > 0.48 and band.bg.__color[1] < 0.49,
	"an outstanding band is band-red")
band:SetDone(true)
check(band.bg.__color[2] > 0.52 and band.bg.__color[2] < 0.53,
	"a satisfied band is band-green")

-- Fonts ----------------------------------------------------------------------

local fs = UIParent:CreateFontString(nil, "OVERLAY")
check(Theme:SetFont(fs, "display", 16), "the bundled display face should load")
check(fs.__font == Theme.font.display, "SetFont should apply the requested face")

stub.missingFonts = { [Theme.font.display] = true }
local fs2 = UIParent:CreateFontString(nil, "OVERLAY")
check(Theme:SetFont(fs2, "display", 16) == false,
	"SetFont should report failure when the face is rejected")
check(fs2.__font == STANDARD_TEXT_FONT,
	"a rejected face must fall back to the client font, got '%s'", tostring(fs2.__font))
stub.missingFonts = nil

local fs3 = UIParent:CreateFontString(nil, "OVERLAY")
Theme:SetFont(fs3, "nosuchrole", 12)
check(fs3.__font == STANDARD_TEXT_FONT, "an unknown role must fall back, not error")

-- Action icons ---------------------------------------------------------------

local icon = UIParent:CreateTexture(nil, "ARTWORK")
Theme:SetActionIcon(icon, "A")
check(icon:GetTexture() == Theme.actionIcon.A, "SetActionIcon should apply the mapped icon")
Theme:SetActionIcon(icon, "ZZZ")
check(icon:GetTexture() == Theme.actionIcon.N,
	"an unknown action code should fall back to the note glyph")

--[[ The frames index icons by parsed action name, not by DSL letter, so the
	name-keyed table is the one that actually gets drawn. It was missing until
	the panels were still rendering Blizzard quest art over a themed panel. ]]
local ACTION_NAMES = {
	"ACCEPT", "TURNIN", "COMPLETE", "NOTE", "RUN", "HEARTH", "SETHEARTH",
	"FLY", "GETFLIGHTPOINT", "BUY", "BOAT", "KILL", "GRIND", "USE", "TRAIN",
	"DIE", "PET",
}
for _, name in ipairs(ACTION_NAMES) do
	local path = Theme.actionIconByName[name]
	check(path ~= nil, "no glyph mapped for action '%s'", name)
	check(path == nil or string.find(path, "Aegis_Pathfinder", 1, true) ~= nil,
		"action '%s' should draw an addon glyph, got '%s'", name, tostring(path))
end

-- Chrome glyphs ---------------------------------------------------------------

-- The concept draws its chrome with characters the 1.12 font cannot render,
-- so each one has to exist as a mask.
local GLYPHS = {
	"menu", "close", "plus", "arrowLeft", "arrowRight",
	"chevronLeft", "chevronRight", "tick", "bang", "pin",
}
for _, name in ipairs(GLYPHS) do
	local path = Theme.glyph[name]
	check(path ~= nil, "chrome glyph '%s' is not declared", name)
	check(path == nil or not string.find(path, "%.tga$"),
		"chrome glyph '%s' carries a file extension", name)
end

-- Panel chrome ----------------------------------------------------------------

local win = CreateFrame("Frame", nil, UIParent)
win:SetWidth(300); win:SetHeight(200)
local header, sub = Theme:Chrome(win, "Config")
check(header ~= nil and sub ~= nil, "Chrome should build a header and a subhead")
check(win:IsMovable(), "Chrome should make its window movable")
check(header.__dragButton == "LeftButton",
	"Chrome should register the header for left-button drag")
check(sub.label:GetText() == "CONFIG",
	"the subhead uppercases like the concept's CSS, got '%s'",
	tostring(sub.label:GetText()))
check(header.wordmark:GetTexture() == Theme.texture.wordmark,
	"the header carries the pre-rendered wordmark")

-- Position round-trip: what PositionSaver stores, RestorePosition must apply.
AegisPathfinder.db = { profile = {} }
win:ClearAllPoints()
win:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 60)
Theme:PositionSaver("testwin")(win)
check(AegisPathfinder.db.profile.testwinpoint == "BOTTOMRIGHT",
	"PositionSaver should record the anchor point, got '%s'",
	tostring(AegisPathfinder.db.profile.testwinpoint))

local other = CreateFrame("Frame", nil, UIParent)
check(Theme:RestorePosition(other, "testwin") == true,
	"RestorePosition should report that it placed the frame")
check(other:GetPoint() == "BOTTOMRIGHT", "and should apply the saved point")
check(other:GetRight() == 1024 - 40 and other:GetBottom() == 60,
	"in the same place, got right %s bottom %s", tostring(other:GetRight()), tostring(other:GetBottom()))

-- A dragged window is pinned by its top-left, wherever the client left it.
local moved = CreateFrame("Frame", nil, UIParent)
moved:SetWidth(200); moved:SetHeight(100)
Theme:Chrome(moved, "Moved")
moved:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -10, 10)
moved.header:GetScript("OnDragStop")()
local mp, _, mrel, mx, my = moved:GetPoint(1)
check(moved:GetNumPoints() == 1 and mp == "TOPLEFT" and mrel == "BOTTOMLEFT"
	and mx == 1024 - 10 - 200 and my == 10 + 100,
	"dropping a window pins it by its top-left where it lies, got %s/%s %s,%s",
	tostring(mp), tostring(mrel), tostring(mx), tostring(my))
check(moved.__clamped == true, "windows are kept on screen")
check(Theme:RestorePosition(other, "neversaved") == false,
	"with nothing saved it should leave the frame's own anchors alone")

-- Report ---------------------------------------------------------------------

local apiErrors = stub.report()
for _, e in ipairs(apiErrors) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Theme: %d checks", checks))
if table.getn(failures) == 0 then
	print("All theme checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
