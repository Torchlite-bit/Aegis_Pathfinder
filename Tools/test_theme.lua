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
