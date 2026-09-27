--[[
	Tests for the Gear window (GearFrame.lua): the stat weights behind the
	item score, through the real scorer (ItemScore.lua) and its data.

	Run:  lua5.1 Tools/test_gearframe.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}
AegisPathfinder = { db = { char = {}, profile = {} } }
function AegisPathfinder:Print() end
UnitClass = function() return "Paladin", "PALADIN" end
local talents = { { "Holy", 0 }, { "Protection", 0 }, { "Retribution", 0 } }
GetTalentTabInfo = function(tab) return talents[tab][1], "icon", talents[tab][2] end

dofile("Theme.lua")
dofile("ItemScoreData.lua")
dofile("ItemScore.lua")
dofile("GearFrame.lua")
local A, IS, Data = AegisPathfinder, AegisPathfinder.ItemScore, AegisPathfinder.ItemScoreData

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end
local function run(f, script)
	local h = f:GetScript(script)
	assert(h, "no " .. script .. " script")
	local old = this
	this = f
	h()
	this = old
end

A:ToggleGearPanel()
local frame = A.gearframe
run(frame, "OnShow")
check(frame:IsShown(), "the toggle opens the window")

-- The spec picker: Auto, naming what it is now, then every spec.
local items = frame.spec.items
check(items[1].value == "auto" and items[1].label == "Auto (Retribution)",
	"Auto first, naming the levelling spec, got %s", tostring(items[1].label))
check(table.getn(items) == 4, "then the three Paladin specs, got %d", table.getn(items))
check(frame.spec:GetValue() == "auto", "Auto chosen until you pick")
check(string.find(frame.note:GetText(), "levelling spec", 1, true), "the note says where the spec came from")
check(string.find(frame.note:GetText(), "default weights", 1, true), "and that the weights are the defaults")

-- The weights listed: the spec's, then all of them.
local function shown()
	local n = 0
	for _, cell in pairs(frame.cells) do if cell:IsShown() then n = n + 1 end end
	return n
end
local weighted = 0
for _, w in pairs(Data.weights.PALADIN.Retribution) do if w ~= 0 then weighted = weighted + 1 end end
check(shown() == weighted, "the stats Retribution weighs are listed (%d of %d)", shown(), weighted)
run(frame.showAll, "OnClick")
check(shown() == table.getn(Data.stats), "Show all stats lists every one, got %d", shown())
local _, over = frame.bar:GetMinMaxValues()
check(over > 0, "and the list scrolls")
run(frame.showAll, "OnClick")

-- Editing a weight.
local str = A:GearCell("STRENGTH")
check(str.label:GetText() == "Strength", "stats named for people, got %s", tostring(str.label:GetText()))
check(A:GearCell("DPS").label:GetText() == "Weapon DPS", "DPS stays DPS")
check(str.box:GetText() == "1.2", "the box shows the weight, got %s", tostring(str.box:GetText()))
str.box:SetText("3.5")
run(str.box, "OnEnterPressed")
check(IS:Weights().STRENGTH == 3.5, "Enter puts the new weight into effect")
check(string.find(frame.note:GetText(), "your own weights", 1, true), "and the note says they are yours now")
str.box:SetText("lots")
run(str.box, "OnEditFocusLost")
check(IS:Weights().STRENGTH == 3.5 and str.box:GetText() == "3.5", "text that is not a number is put back")
str.box:SetText("9")
run(str.box, "OnEscapePressed")
check(IS:Weights().STRENGTH == 3.5 and str.box:GetText() == "3.5", "Escape puts back the weight it had")

-- Export, import, reset.
run(frame.export, "OnClick")
check(frame.share:GetText() == "OPW1:PALADIN:Retribution:*STRENGTH:3.5", "export fills the box, got %s",
	tostring(frame.share:GetText()))
check(string.find(frame.note:GetText(), "Ctrl+C", 1, true), "and says how to copy it")
run(frame.reset, "OnClick")
check(IS:Weights().STRENGTH == 1.2 and str.box:GetText() == "1.2", "reset goes back to the defaults")
run(frame.import, "OnClick")
check(IS:Weights().STRENGTH == 3.5, "import brings the exported weights back")
frame.share:SetText("OPW1:MAGE:Frost:*")
run(frame.import, "OnClick")
check(string.find(frame.note:GetText(), "MAGE", 1, true), "a refused import says why, got %s", frame.note:GetText())

-- Picking a spec.
local protRow
for _, row in ipairs(frame.spec.rows) do if row.value == "Protection" then protRow = row end end
run(protRow, "OnClick")
check(IS:Spec() == "Protection", "picking a spec scores as it")
check(frame.spec:GetValue() == "Protection", "and the picker shows it")
check(string.find(frame.note:GetText(), "the spec you picked", 1, true), "and the note says you picked it")
check(str.box:GetText() == "0.9", "the boxes show that spec's weights, got %s", tostring(str.box:GetText()))

-- Talents change what Auto means.
IS:SetSpec(nil)
talents[1][2] = 21
IS:Changed()
check(frame.spec.items[1].label == "Auto (Holy)", "Auto follows your talents, got %s", frame.spec.items[1].label)

run(frame, "OnHide")
A:ToggleGearPanel()
check(not frame:IsShown(), "the toggle closes it again")

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end
print(string.format("GearFrame: %d checks", checks))
if table.getn(failures) == 0 then
	print("All gear window checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
