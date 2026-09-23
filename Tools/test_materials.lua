--[[
	Tests for the materials view.

	The number this panel shows is the whole point of it: reagents for the
	steps still AHEAD of you, not the reference document's total from skill 1.
	Get that wrong and it is worse than no list, because it looks authoritative.

	Run:  lua5.1 Tools/test_materials.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}

AegisPathfinder = {
	actions = {}, quests = {}, tags = {}, turnedin = {},
	current = 1,
	db = { char = { currentguide = "Alchemy (1-300)" }, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder:GetObjectiveStatus(i)
	return self.turnedin[self.quests[i]]
end

dofile("Theme.lua")
dofile("WidgetWarlock.lua")
dofile("Parser.lua")
dofile("Professions.lua")
dofile("MaterialsFrame.lua")

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

-- A three-step craft route sharing a reagent across two of the steps.
AegisPathfinder.actions = { "USE", "USE", "USE" }
AegisPathfinder.quests = { "Craft A@1@", "Craft B@2@", "Craft C@3@" }
AegisPathfinder.tags = {
	"|SKILL|Alchemy 1 63| |CRAFT|40 Minor Healing Potion| |MATS|1x Peacebloom, 1x Silverleaf, 1x Empty Vial|",
	"|SKILL|Alchemy 63 80| |CRAFT|10 Elixir of Minor Agility| |MATS|2x Swiftthistle, 1x Empty Vial|",
	"|SKILL|Alchemy 80 90| |CRAFT|5 Blackmouth Oil| |MATS|2x Oily Blackmouth|",
}

-- Arithmetic -----------------------------------------------------------------

local function totals()
	local out = {}
	for _, e in ipairs(AegisPathfinder:GetRemainingMaterials() or {}) do
		out[e.item] = e.need
	end
	return out
end

local t = totals()
-- 40 crafts x 1 + 10 crafts x 1 = 50 vials across the two steps that use them.
check(t["Empty Vial"] == 50, "a reagent used by two steps should be summed: expected 50, got %s",
	tostring(t["Empty Vial"]))
check(t["Peacebloom"] == 40, "40 crafts x 1 Peacebloom = 40, got %s", tostring(t["Peacebloom"]))
check(t["Swiftthistle"] == 20, "10 crafts x 2 Swiftthistle = 20, got %s", tostring(t["Swiftthistle"]))
check(t["Oily Blackmouth"] == 10, "5 crafts x 2 = 10, got %s", tostring(t["Oily Blackmouth"]))

-- The whole point: completed steps drop out of the total.
AegisPathfinder.turnedin["Craft A@1@"] = true
t = totals()
check(t["Peacebloom"] == nil,
	"a finished step's reagents must leave the list -- you already bought them")
check(t["Empty Vial"] == 10,
	"vials should drop to the 10 the remaining step needs, got %s", tostring(t["Empty Vial"]))

AegisPathfinder.turnedin["Craft B@2@"] = true
AegisPathfinder.turnedin["Craft C@3@"] = true
check(AegisPathfinder:GetRemainingMaterials() == nil,
	"with everything done there is nothing to buy, so the list is nil rather than empty")

AegisPathfinder.turnedin = {}

-- A guide with no |MATS| tags at all.
AegisPathfinder.tags = { "|QID|41187|", "|QID|41188|", "|N|just a note|" }
check(AegisPathfinder:GetRemainingMaterials() == nil,
	"a quest guide has no materials and must not invent an empty list")

AegisPathfinder.tags = {
	"|SKILL|Alchemy 1 63| |CRAFT|40 Minor Healing Potion| |MATS|1x Peacebloom, 1x Silverleaf, 1x Empty Vial|",
	"|SKILL|Alchemy 63 80| |CRAFT|10 Elixir of Minor Agility| |MATS|2x Swiftthistle, 1x Empty Vial|",
	"|SKILL|Alchemy 80 90| |CRAFT|5 Blackmouth Oil| |MATS|2x Oily Blackmouth|",
}

-- A |MATS| tag with no |CRAFT| count means one craft, not zero.
AegisPathfinder.tags[3] = "|MATS|3x Mageweave Cloth|"
t = totals()
check(t["Mageweave Cloth"] == 3,
	"a step with no craft count should count as one craft, got %s",
	tostring(t["Mageweave Cloth"]))

-- Panel ----------------------------------------------------------------------

AegisPathfinder:CreateMaterialsPanel()
local frame = AegisPathfinder.materialsframe
check(frame ~= nil, "the materials panel was not created")
check(not frame:IsShown(), "it starts hidden")

frame:Show()
AegisPathfinder:UpdateMaterialsPanel()
check(string.find(frame.subtitle:GetText(), "Alchemy", 1, true) ~= nil,
	"the subtitle should name the guide, got '%s'", tostring(frame.subtitle:GetText()))

AegisPathfinder:ToggleMaterialsPanel()
check(not frame:IsShown(), "toggle hides a shown panel")
AegisPathfinder:ToggleMaterialsPanel()
check(frame:IsShown(), "toggle shows a hidden one")

-- A guide with nothing to buy says so rather than showing a blank panel.
AegisPathfinder.tags = { "|QID|1|", "|QID|2|", "|QID|3|" }
AegisPathfinder:UpdateMaterialsPanel()
check(string.find(frame.subtitle:GetText(), "no materials", 1, true) ~= nil,
	"an empty list should be explained, got '%s'", tostring(frame.subtitle:GetText()))

-- Updating a hidden panel must be a no-op, not an error.
frame:Hide()
local ok = pcall(function() AegisPathfinder:UpdateMaterialsPanel() end)
check(ok, "updating a hidden panel should be safe")

-- Scrolling --------------------------------------------------------------------

-- More reagents than rows. The bar is the theme's -- UIPanelScrollBarTemplate
-- brought Blizzard's arrows and knob -- and it moves a row at a time.
local many = {}
for i = 1, 25 do table.insert(many, string.format("1x Reagent %02d", i)) end
AegisPathfinder.tags = {
	"|SKILL|Alchemy 1 10| |CRAFT|1 Thing| |MATS|" .. table.concat(many, ", ") .. "|",
	"|QID|2|", "|QID|3|",
}
frame:Show()
AegisPathfinder:UpdateMaterialsPanel()
local bar = frame.slider
check(bar.track ~= nil and bar.up ~= nil and bar.down ~= nil,
	"the list scrolls with the theme's bar")
check(bar:IsShown(), "which shows once the list outgrows the rows")
local _, hi = bar:GetMinMaxValues()
check(hi == 7, "25 reagents in 18 rows scroll by 7, got %s", tostring(hi))

-- The rows are the panel's children carrying a quantity and a name.
local function firstRow()
	for _, r in ipairs({ frame:GetChildren() }) do
		if r.qty and r.name then return r.name:GetText() end
	end
end
check(firstRow() == "Reagent 01", "the list starts at the top, got '%s'", tostring(firstRow()))
bar.down:GetScript("OnClick")()
check(firstRow() == "Reagent 02", "the down caret moves one row, got '%s'", tostring(firstRow()))
arg1 = -1; frame:GetScript("OnMouseWheel")()
check(firstRow() == "Reagent 03", "and so does the wheel, got '%s'", tostring(firstRow()))
for _ = 1, 20 do bar.down:GetScript("OnClick")() end
check(bar:GetValue() == 7, "and neither runs past the end, got %s", tostring(bar:GetValue()))
for _ = 1, 20 do bar.up:GetScript("OnClick")() end
check(bar:GetValue() == 0 and firstRow() == "Reagent 01",
	"or past the top, got %s", tostring(bar:GetValue()))
frame:Hide()

-- End-to-end against the source document ------------------------------------

--[[ The strongest check available offline.

	The reference document publishes its own shopping list per profession,
	totalled over the whole route. Running the real Alchemy guide through the
	real parsers and summing from step one must reproduce it exactly. If the
	converter drops a step, mangles a craft count, or the tag round trip loses
	a reagent, these numbers diverge.
]]
local ALCHEMY_TOTALS = {   -- verbatim from the document's shopping list
	["Empty Vial"] = 120, ["Leaded Vial"] = 47, ["Crystal Vial"] = 61,
	["Peacebloom"] = 40, ["Silverleaf"] = 57, ["Earthroot"] = 45,
	["Swiftthistle"] = 17, ["Bruiseweed"] = 5, ["Wild Steelbloom"] = 7,
	["Stranglekelp"] = 13, ["Kingsblood"] = 15, ["Liferoot"] = 18,
	["Goldthorn"] = 20, ["Arthas\' Tears"] = 23, ["Sungrass"] = 13,
	["Golden Sansam"] = 15, ["Dreamfoil"] = 40, ["Dream Dust"] = 10,
	["Oily Blackmouth"] = 26, ["Deviate Fish"] = 30, ["Firefin Snapper"] = 40,
	["Stonescale Eel"] = 7,
}

AegisPathfinder.guides, AegisPathfinder.guidelist = {}, {}
AegisPathfinder.qsplusguides = {}
AegisPathfinder.turnedin = {}
AegisPathfinder.current = 1
function AegisPathfinder:RegisterGuide(name, nextzone, faction, loader)
	self.guides[name] = loader
	table.insert(self.guidelist, name)
end

dofile("QuestShellPlusParser.lua")
dofile("Guides/Professions/Alchemy.lua")

local guide = AegisPathfinder.qsplusguides["Alchemy (1-300)"]
check(guide ~= nil, "the Alchemy guide did not register")

if guide then
	local aa, qq, tt = AegisPathfinder:ParseQuestShellPlus(guide)
	AegisPathfinder.actions, AegisPathfinder.quests, AegisPathfinder.tags = aa, qq, tt

	local computed = {}
	for _, e in ipairs(AegisPathfinder:GetRemainingMaterials() or {}) do
		computed[e.item] = e.need
	end

	for item, expected in pairs(ALCHEMY_TOTALS) do
		check(computed[item] == expected,
			"Alchemy needs %d %s per the source document, computed %s",
			expected, item, tostring(computed[item]))
	end
	for item, got in pairs(computed) do
		check(ALCHEMY_TOTALS[item] ~= nil,
			"computed a reagent the document never lists: %s (%d)", item, got)
	end
end

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Materials: %d checks", checks))
if table.getn(failures) == 0 then
	print("All materials checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
