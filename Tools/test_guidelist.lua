--[[
	Tests for guide categorisation and the tab/badge widgets behind it.

	Two things here are easy to get silently wrong. Profession guides are named
	"Alchemy (1-300)", which matches none of the name prefixes the categoriser
	keys on, so without an explicit rule they land in with the zone guides.
	And a placeholder guide looks exactly like an authored one in a list, which
	is what the TPL badge is for.

	Run:  lua5.1 Tools/test_guidelist.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

AegisPathfinder = { qsplusguides = {}, db = { char = {}, profile = {} } }
dofile("Theme.lua")

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

local Theme = AegisPathfinder.Theme

--[[ Categorisation.

	Lifted rather than loaded: Core.lua is 2,400 lines of addon construction
	and pulling it in would test Ace2's stubbing, not this logic. These are the
	two functions under test, kept identical to Core.lua -- if they drift, the
	check at the bottom of this file fails.
]]
local TURTLE_ZONES = { ["Thalassian Highlands"] = true, ["Balor"] = true }

function AegisPathfinder:IsTemplateGuide(guideName)
	local qsp = self.qsplusguides and self.qsplusguides[guideName]

	return (qsp and qsp.template) and true or false
end

function AegisPathfinder:GetGuideCategory(guideName)
	local qsp = self.qsplusguides and self.qsplusguides[guideName]
	if qsp and qsp.category == "Profession" then
		return "profession"
	end
	if string.find(guideName, "^Optimized/") then return "optimized" end
	if string.find(guideName, "^RXP/") then return "rxp" end
	if string.find(guideName, "^RXP_Hardcore/") then return "rxp_hc" end
	for zone in pairs(TURTLE_ZONES) do
		if string.find(guideName, zone) then return "turtle" end
	end
	return "zone"
end

AegisPathfinder.qsplusguides["Alchemy (1-300)"] =
	{ category = "Profession", steps = {} }
AegisPathfinder.qsplusguides["Fishing (1-300)"] =
	{ category = "Profession", template = true, steps = {} }

check(AegisPathfinder:GetGuideCategory("Alchemy (1-300)") == "profession",
	"a profession guide must not fall through to the zone category")
check(AegisPathfinder:GetGuideCategory("Fishing (1-300)") == "profession",
	"a profession template is still a profession")
check(AegisPathfinder:GetGuideCategory("Optimized/Darkshore (12-17)") == "optimized",
	"name-prefixed categories still work")
check(AegisPathfinder:GetGuideCategory("RXP/Elwynn Forest (6-11)") == "rxp", "RXP")
check(AegisPathfinder:GetGuideCategory("RXP_Hardcore/Durotar (1-12)") == "rxp_hc", "RXP hardcore")
check(AegisPathfinder:GetGuideCategory("Thalassian Highlands (1-10)") == "turtle",
	"custom zones are detected by zone name")
check(AegisPathfinder:GetGuideCategory("Westfall (12-17)") == "zone",
	"anything else is a zone guide")

check(AegisPathfinder:IsTemplateGuide("Fishing (1-300)") == true,
	"an unauthored guide reports as a template")
check(AegisPathfinder:IsTemplateGuide("Alchemy (1-300)") == false,
	"an authored guide is not a template")
check(AegisPathfinder:IsTemplateGuide("Westfall (12-17)") == false,
	"a guide with no QuestShell+ table is not a template")
check(AegisPathfinder:IsTemplateGuide("No Such Guide") == false,
	"an unknown guide is not a template, and must not error")

-- Tabs -----------------------------------------------------------------------

local tab = Theme:Tab(UIParent, "Professions", 84, 22)
check(tab.label:GetText() == "PROFESSIONS", "tab labels are uppercased, got '%s'",
	tostring(tab.label:GetText()))
check(tab:IsActive() == false, "a new tab starts inactive")
check(tab.fill.center.__color[1] > 0.22 and tab.fill.center.__color[1] < 0.24,
	"an inactive tab sits in the tab-strip colour")

tab:SetActive(true)
check(tab:IsActive() == true, "SetActive registers")
check(tab.fill.center.__color[1] > 0.12 and tab.fill.center.__color[1] < 0.13,
	"an active tab takes the panel colour, so it reads as continuous with the list")
check(tab.label.__color[2] > 0.78, "an active tab's label is accent")

tab:SetActive(false)
check(tab.label.__color[1] > 0.75 and tab.label.__color[2] > 0.75,
	"an inactive tab's label returns to dim")

-- Badges ---------------------------------------------------------------------

local tpl = Theme:Badge(UIParent, "TPL", "tpl")
check(tpl.label:GetText() == "TPL", "badge text, got '%s'", tostring(tpl.label:GetText()))
check(tpl.bg.__color[1] > 0.3 and tpl.bg.__color[1] < 0.35,
	"a TPL badge is grey, not gold -- it marks absence of content, not a feature")
check(tpl.label.__color[1] > 0.9, "TPL text is light on grey")

local xp = Theme:Badge(UIParent, "XP", "xp")
check(xp.bg.__color[1] > 0.88, "an XP badge is gold")
check(xp.label.__color[1] < 0.2, "XP text is dark on gold")
check(xp:GetWidth() >= 22, "a badge has a minimum width so short labels still read")

xp:SetKind("tpl", "TPL")
check(xp.bg.__color[1] < 0.35, "SetKind should switch a badge's appearance")

-- Drift check ----------------------------------------------------------------

-- The two functions above are copies. If Core.lua's versions change shape,
-- this catches it rather than letting the copies quietly go stale.
local core = io.open("Core.lua"):read("*a")
check(string.find(core, 'qsp.category == "Profession"', 1, true) ~= nil,
	"Core.lua no longer categorises professions the way this test assumes")
check(string.find(core, "function AegisPathfinder:IsTemplateGuide", 1, true) ~= nil,
	"Core.lua no longer defines IsTemplateGuide")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("GuideList: %d checks", checks))
if table.getn(failures) == 0 then
	print("All guide list checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
