--[[
	Tests for the Active Items and Active Targets windows.

	The two small windows RestedXP hangs beside its guide: a button per item
	the guide wants used, and a button per NPC or enemy it wants found, which
	targets them and marks them -- a star for a friend, a skull (then a cross)
	for an enemy.

	What matters most is that each window offers the right things: an item
	you do not carry, or one for a quest you have finished, is a dead button;
	a target taken from the wrong quest sends you after the wrong mob.

	Run:  lua5.1 Tools/test_activeframes.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

UISpecialFrames = {}

local now = 100
GetTime = function() return now end

-- The world: who is near enough to target, and what the target is.
local world = { near = {}, hostile = {} }
local marks, used, tooltip = {}, {}, {}
local target
TargetByName = function(name, exact)
	world.lastExact = exact
	if world.near[name] then target = name end
end
UnitExists = function(unit) return unit == "target" and target ~= nil end
UnitName = function(unit) if unit == "target" then return target end end
UnitCanAttack = function(_, unit) return unit == "target" and world.hostile[target] or false end
GetRaidTargetIndex = function(unit) return unit == "target" and marks[target] or nil end
SetRaidTarget = function(unit, index)
	world.setCount = (world.setCount or 0) + 1
	if unit == "target" then marks[target] = index end
end
UseContainerItem = function(bag, slot) table.insert(used, { bag, slot }) end
GameTooltip.SetOwner = function(_, owner) tooltip.owner = owner end
GameTooltip.SetBagItem = function(_, bag, slot) tooltip.bag, tooltip.slot = bag, slot end
GameTooltip.Hide = function() tooltip.owner = nil end

local printed = {}
local turnedIn = {}
AegisPathfinder = {
	actions = {}, quests = {}, tags = {}, turnedin = {},
	current = 1,
	db = { char = {}, profile = {} },
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print(msg) table.insert(printed, msg) end
function AegisPathfinder.trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder:GetObjectiveInfo(i)
	i = i or self.current
	return self.actions[i], self.quests[i]
end
-- Which quests are in the log, and which of those are complete.
local log = {}
function AegisPathfinder:GetObjectiveStatus(i)
	local qid = tonumber((self:GetObjectiveTag("QID", i)))
	local q = qid and log[qid]
	return self.turnedin[self.quests[i]], q and q.index, q and q.complete
end
function AegisPathfinder:SetTurnedIn() table.insert(turnedIn, self.current) end

dofile("Theme.lua")
dofile("WidgetWarlock.lua")
dofile("Parser.lua")
local guide = CreateFrame("Frame", "AegisPathfinderObjectives", UIParent)
guide:SetWidth(396); guide:SetHeight(300)
guide:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -180)
AegisPathfinder.objectiveframe = guide
dofile("ActiveFrames.lua")
local Theme = AegisPathfinder.Theme
local MARK = AegisPathfinder.RAID_MARKS

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end
local function lastPrint() return printed[table.getn(printed)] or "" end

local items = AegisPathfinder.activeitemsframe
local targets = AegisPathfinder.activetargetsframe

-- The windows ---------------------------------------------------------------------

check(items ~= nil and getglobal("AegisPathfinderActiveItems") == items, "the Active Items window is built")
check(targets ~= nil and getglobal("AegisPathfinderActiveTargets") == targets, "and the Active Targets one")
check(not items:IsShown() and not targets:IsShown(), "both start hidden")
check(items.label:GetText() == "ACTIVE ITEMS" and targets.label:GetText() == "ACTIVE TARGETS",
	"titled as RestedXP's are, got '%s' and '%s'", items.label:GetText(), targets.label:GetText())
check(not items.header.wordmark:IsShown(), "a title, not the wordmark, on a window this small")
check(AegisPathfinder.activeEvents.__events["BAG_UPDATE"] and AegisPathfinder.activeEvents.__events["PLAYER_TARGET_CHANGED"],
	"they listen for the bags and the target")

-- Active items ---------------------------------------------------------------------

AegisPathfinder.actions = { "USE", "COMPLETE", "COMPLETE", "COMPLETE", "ACCEPT", "COMPLETE" }
AegisPathfinder.quests = { "Use it@1@", "Kill a@2@", "Kill b@3@", "Kill c@4@", "Take d@5@", "Kill e@6@" }
AegisPathfinder.tags = {
	"|QID|10| |U|5001|",
	"|QID|20| |U|5002|",
	"|QID|30| |U|5003|",     -- in the log, but done
	"|QID|40| |U|5004|",     -- not in the log
	"|QID|50| |U|5005|",     -- an item that starts a quest: only while current
	"|QID|60| |U|9999|",     -- in the log, but the item is not in the bags
}
log = { [10] = { index = 1 }, [20] = { index = 2 }, [30] = { index = 3, complete = true },
	[60] = { index = 4 } }
stub.bags = {
	[0] = { [1] = { id = 5001, name = "Rod", count = 1, texture = "rod" },
	        [4] = { id = 5002, name = "Horn", count = 2, texture = "horn" },
	        [5] = { id = 5003, name = "Totem", count = 1, texture = "totem" },
	        [6] = { id = 5004, name = "Flask", count = 1, texture = "flask" },
	        [7] = { id = 5005, name = "Letter", count = 1, texture = "letter" } },
	[1] = { [2] = { id = 5002, name = "Horn", count = 3, texture = "horn" } },
}

local list = AegisPathfinder:GetActiveItems()
local ids = {}
for _, e in ipairs(list) do table.insert(ids, e.id) end
check(table.concat(ids, ",") == "5001,5002",
	"the current step's item, then any active quest's: expected 5001,5002, got %s", table.concat(ids, ","))
check(list[2].count == 5, "stacks across bags add up: 2 + 3, got %s", tostring(list[2].count))
check(list[1].texture == "rod", "the icon is the bag's")

AegisPathfinder.current = 5
ids = {}
for _, e in ipairs(AegisPathfinder:GetActiveItems()) do table.insert(ids, e.id) end
check(ids[1] == 5005, "a quest-starting item shows while its step is current, got %s", tostring(ids[1]))
AegisPathfinder.turnedin["Kill a@2@"] = true
ids = {}
for _, e in ipairs(AegisPathfinder:GetActiveItems()) do table.insert(ids, e.id) end
check(table.concat(ids, ",") == "5005,5001",
	"a finished step's item goes; the active quest's stays: got %s", table.concat(ids, ","))
AegisPathfinder.turnedin = {}
AegisPathfinder.current = 1

-- One button per item, however many steps want it; six at most.
do
	local a, q, tg, l, b = AegisPathfinder.actions, AegisPathfinder.quests, AegisPathfinder.tags, log, stub.bags
	AegisPathfinder.actions, AegisPathfinder.quests, AegisPathfinder.tags = {}, {}, {}
	log, stub.bags = {}, { [2] = {} }
	for i = 1, 9 do
		AegisPathfinder.actions[i] = "COMPLETE"
		AegisPathfinder.quests[i] = "Q" .. i .. "@" .. i .. "@"
		-- Steps 1 and 2 share an item.
		local id = i == 2 and 7001 or 7000 + i
		AegisPathfinder.tags[i] = "|QID|" .. (700 + i) .. "| |U|" .. id .. "|"
		log[700 + i] = { index = i }
		stub.bags[2][i] = { id = 7000 + i, name = "Thing " .. i, count = 1 }
	end
	local got = AegisPathfinder:GetActiveItems()
	check(table.getn(got) == 6, "six items at most, got %d", table.getn(got))
	check(got[1].id == 7001 and got[2].id == 7003, "an item two steps want is one button, got %s then %s",
		tostring(got[1].id), tostring(got[2].id))
	AegisPathfinder.actions, AegisPathfinder.quests, AegisPathfinder.tags, log, stub.bags = a, q, tg, l, b
end

-- The window: one tile each, sized to fit.
AegisPathfinder:PaintActiveFrames()
check(items:IsShown(), "items to use show the window")
local shown = 0
for _, b in ipairs(items.tiles) do if b:IsShown() then shown = shown + 1 end end
check(shown == 2, "one tile per item, got %d", shown)
check(items:GetWidth() >= 6 * 2 + 32 * 2 + 4, "the window is as wide as its tiles, got %s", items:GetWidth())
check(items.tiles[1].icon:GetTexture() == "rod", "each tile shows its item")
check(items.tiles[2].count:GetText() == "5", "a stack shows its count, got '%s'", items.tiles[2].count:GetText())
check(items.tiles[1].count:GetText() == "", "one of something shows no count")
check(items.tiles[1].icon.__texcoord and items.tiles[1].icon.__texcoord[1] > 0,
	"with the game's bevel cropped off the icon")

-- Hanging under the guide until dragged.
local p, rel, rp = items:GetPoint()
check(p == "TOPRIGHT" and rel == guide and rp == "BOTTOMRIGHT", "Items hangs under the guide, got %s %s", tostring(p), tostring(rp))

-- Using one.
this = items.tiles[2]
items.tiles[2]:GetScript("OnClick")()
check(used[1] and used[1][1] == 0 and used[1][2] == 4, "a click uses the item from the bags")
check(table.getn(turnedIn) == 0, "another quest's item does not tick the current step")
this = items.tiles[1]
items.tiles[1]:GetScript("OnClick")()
check(table.getn(turnedIn) == 1, "the current USE step's own item ticks it")
items.tiles[1]:GetScript("OnEnter")()
check(tooltip.owner == items.tiles[1] and tooltip.bag == 0 and tooltip.slot == 1,
	"hovering shows the item's own tooltip")
items.tiles[1]:GetScript("OnLeave")()

-- Gone from the bags between the paint and the click.
stub.bags[0][1] = nil
used = {}
check(AegisPathfinder:UseActiveItem(1) == false and table.getn(used) == 0,
	"an item that has left the bags is not used")
check(string.find(lastPrint(), "no longer in your bags", 1, true) ~= nil, "and says so, got '%s'", lastPrint())
stub.bags[0][1] = { id = 5001, name = "Rod", count = 1, texture = "rod" }

-- Nothing to use hides it; so does the setting.
AegisPathfinder.db.char.showactiveitems = false
AegisPathfinder:PaintActiveFrames()
check(not items:IsShown(), "switched off in the options, it hides")
AegisPathfinder.db.char.showactiveitems = nil
AegisPathfinder:PaintActiveFrames()
check(items:IsShown(), "and is on unless switched off")
local saved = stub.bags
stub.bags = {}
AegisPathfinder:PaintActiveFrames()
check(not items:IsShown(), "with nothing in the bags to use, it hides")
stub.bags = saved
check(AegisPathfinder:UseActiveItem(1) == false, "and the key binding has nothing to use")

-- Active targets --------------------------------------------------------------------

-- pfQuest's shape: quests by id with start/end/obj lists, units by id with a
-- faction string for the friendly ones, items by id with drop chances.
pfDB = {
	quests = { data = {
		[100] = { start = { U = { 1 } }, ["end"] = { U = { 2 } } },
		[200] = { obj = { U = { 10, 11 }, I = { 900 } } },
		[300] = { obj = { I = { 901 } } },
	} },
	units = {
		loc = { [1] = "Marshal Dughan", [2] = "Deputy Willem", [10] = "Kobold Vermin",
			[11] = "Kobold Worker", [12] = "Kobold Laborer", [13] = "Defias Thug",
			[14] = "Kobold Tunneler", [15] = "Murloc Streamrunner" },
		data = { [1] = { fac = "A" }, [2] = { fac = "AH" }, [10] = {}, [11] = {}, [12] = {}, [13] = {},
			[14] = {}, [15] = {} },
	},
	items = { data = {
		[900] = { U = { [12] = 20.5, [11] = 50, [13] = 60 } },
		[901] = { U = { [15] = 30, [14] = 30 } },
	} },
}

local function names(t)
	local out = {}
	for _, e in ipairs(t) do table.insert(out, e.name) end
	return table.concat(out, ", ")
end

AegisPathfinder.actions = { "ACCEPT", "TURNIN", "COMPLETE", "TRAIN", "RUN", "COMPLETE", "ACCEPT" }
AegisPathfinder.quests = { "A@1@", "T@2@", "C@3@", "Learn@4@", "Run@5@", "C2@6@", "Unknown@7@" }
AegisPathfinder.tags = {
	"|QID|100|", "|QID|100|", "|QID|200| |U|5001|",
	"|NPC|Telina Shadehand;Milla Fairancora|", "|N|Go somewhere|", "|QID|300|", "|QID|99999|",
}

local t = AegisPathfinder:GetActiveTargets(1)
check(names(t) == "Marshal Dughan", "an ACCEPT step's target is who gives the quest, got '%s'", names(t))
check(t[1].kind == "npc" and t[1].mark == MARK.STAR, "a friendly NPC, marked with a star")
t = AegisPathfinder:GetActiveTargets(2)
check(names(t) == "Deputy Willem", "a TURNIN step's is who takes it, got '%s'", names(t))

t = AegisPathfinder:GetActiveTargets(3)
check(names(t) == "Kobold Vermin, Kobold Worker, Defias Thug, Kobold Laborer",
	"a COMPLETE step's are what it wants killed, then what drops what it wants, likeliest first, got '%s'", names(t))
check(t[1].kind == "enemy" and t[1].mark == MARK.SKULL, "the first enemy gets a skull")
check(t[2].mark == MARK.CROSS and t[4].mark == MARK.CROSS, "the rest a cross")

t = AegisPathfinder:GetActiveTargets(6)
check(names(t) == "Kobold Tunneler, Murloc Streamrunner",
	"equal drop chances are in a steady order, got '%s'", names(t))

t = AegisPathfinder:GetActiveTargets(4)
check(names(t) == "Telina Shadehand, Milla Fairancora", "a profession step's |NPC| names, got '%s'", names(t))
check(t[1].mark == MARK.STAR and t[2].mark == MARK.STAR, "trainers are friends")
check(table.getn(AegisPathfinder:GetActiveTargets(5)) == 0, "a travel step has nobody to target")
check(table.getn(AegisPathfinder:GetActiveTargets(7)) == 0, "nor does a quest pfQuest does not know")

-- Four at most.
pfDB.quests.data[200].obj.U = { 10, 11, 12, 13, 14, 15 }
check(table.getn(AegisPathfinder:GetActiveTargets(3)) == 4, "four targets at most")
pfDB.quests.data[200].obj.U = { 10, 11 }

-- Without pfQuest, only a step that names its NPCs has targets.
local pf = pfDB
pfDB = nil
check(table.getn(AegisPathfinder:GetActiveTargets(1)) == 0, "no pfQuest, no quest giver")
check(table.getn(AegisPathfinder:GetActiveTargets(4)) == 2, "but |NPC| steps still work")
pfDB = pf

-- A Horde character sees Alliance NPCs as enemies.
UnitFactionGroup = function() return "Horde" end
check(AegisPathfinder:GetActiveTargets(1)[1].kind == "enemy", "faction decides who is a friend")
check(AegisPathfinder:GetActiveTargets(2)[1].kind == "npc", "an NPC friendly to both is a friend to both")
UnitFactionGroup = function() return "Alliance" end

-- Targeting and marking --------------------------------------------------------------

AegisPathfinder.current = 3
AegisPathfinder:PaintActiveFrames()
check(targets:IsShown(), "targets show the window")
local tp, trel, trp = targets:GetPoint()
check(tp == "TOPRIGHT" and trel == items and trp == "BOTTOMRIGHT",
	"Targets hangs under Items, got %s %s", tostring(tp), tostring(trp))

local tile = targets.tiles[1]
check(tile.icon:GetTexture() == Theme.actionIcon.K, "an enemy tile shows the kill glyph")
check(tile.mark:IsShown(), "and the mark it will get in its corner")
local tc = tile.mark.__texcoord
check(tc and tc[1] == 0.75 and tc[3] == 0.25, "a skull is the sheet's eighth icon, got %s,%s",
	tostring(tc and tc[1]), tostring(tc and tc[3]))

world.near["Kobold Vermin"], world.hostile["Kobold Vermin"] = true, true
this = tile
tile:GetScript("OnClick")()
check(target == "Kobold Vermin" and world.lastExact == true, "a click targets by exact name")
check(marks["Kobold Vermin"] == MARK.SKULL, "and marks an enemy with a skull")
local sets = world.setCount
tile:GetScript("OnClick")()
check(world.setCount == sets, "an existing mark is left alone rather than toggled off")

-- Relit on the target changing.
event = "PLAYER_TARGET_CHANGED"
this = AegisPathfinder.activeEvents
AegisPathfinder.activeEvents:GetScript("OnEvent")()
check(tile.border.tl.__color[1] == Theme.color.accent[1], "the targeted one's tile lights up")
check(targets.tiles[2].border.tl.__color[1] == Theme.color.subtle[1], "and only that one")

-- Out of range.
this = targets.tiles[2]
targets.tiles[2]:GetScript("OnClick")()
check(target == "Kobold Vermin", "someone out of range is not targeted")
check(string.find(lastPrint(), "Kobold Worker isn't close enough", 1, true) ~= nil,
	"and it says so, got '%s'", lastPrint())

-- The client knows better than the database: a friend who turns out to be
-- attackable gets a skull, an enemy who is not gets a star.
AegisPathfinder.current = 1
AegisPathfinder:PaintActiveFrames()
world.near["Marshal Dughan"] = true
world.hostile["Marshal Dughan"] = true
AegisPathfinder:TargetActive(AegisPathfinder:GetActiveTargets(1)[1])
check(marks["Marshal Dughan"] == MARK.SKULL, "an attackable 'friend' gets a skull")
world.hostile["Marshal Dughan"] = nil
marks = {}
AegisPathfinder:TargetActive(AegisPathfinder:GetActiveTargets(1)[1])
check(marks["Marshal Dughan"] == MARK.STAR, "a friend gets a star")
check(targets.tiles[1].icon:GetTexture() == Theme.actionIcon.A, "a quest giver's tile is the accept glyph")

-- /apg target: the next one after whoever is targeted, round and round.
AegisPathfinder.current = 3
AegisPathfinder:PaintActiveFrames()
world.near = { ["Kobold Vermin"] = true, ["Kobold Laborer"] = true, ["Defias Thug"] = true }
world.hostile = { ["Kobold Vermin"] = true, ["Kobold Laborer"] = true, ["Defias Thug"] = true }
target = "Kobold Vermin"
AegisPathfinder:TargetNextActive()
check(target == "Defias Thug", "it moves on to the next one in range, got %s", tostring(target))
AegisPathfinder:TargetNextActive()
check(target == "Kobold Laborer", "and the next, got %s", tostring(target))
AegisPathfinder:TargetNextActive()
check(target == "Kobold Vermin", "and back round, got %s", tostring(target))
check(marks["Kobold Laborer"] == MARK.CROSS, "the second kind of enemy gets a cross")
world.near = {}
target = nil
local before = table.getn(printed)
check(AegisPathfinder:TargetNextActive() == false, "nobody in range is a no")
check(table.getn(printed) == before + 1, "said once, not once per target")
AegisPathfinder.current = 5
AegisPathfinder:PaintActiveFrames()
check(not targets:IsShown(), "a step with nobody to find hides the window")
check(AegisPathfinder:TargetNextActive() == false, "and /apg target has nobody to target")

-- Targets moves up under the guide while Items is empty.
stub.bags = {}
AegisPathfinder.current = 3
AegisPathfinder:PaintActiveFrames()
tp, trel = targets:GetPoint()
check(not items:IsShown() and trel == guide, "with no items, Targets takes Items' place under the guide")
stub.bags = saved

-- Where they go ---------------------------------------------------------------------

-- Dragged, a window stays where it was put.
local header = items.header
this = header
header:GetScript("OnDragStart")()
check(items.moving, "a drag is under way")
-- The client moves it with the cursor, by an anchor of its own choosing.
items:ClearAllPoints()
items:SetPoint("CENTER", UIParent, "CENTER", 10, 10)
AegisPathfinder:PaintActiveFrames()
local dragPoint = items:GetPoint()
check(dragPoint == "CENTER", "a repaint mid-drag does not snap it back under the guide, got %s", tostring(dragPoint))
header:GetScript("OnDragStop")()
check(not items.moving, "and then it is not")
check(AegisPathfinder.db.profile.activeitemspoint == "TOPLEFT", "the drop is saved, got %s",
	tostring(AegisPathfinder.db.profile.activeitemspoint))
AegisPathfinder:PaintActiveFrames()
p, rel = items:GetPoint()
check(p == "TOPLEFT" and rel == UIParent, "and kept on the next paint, got %s", tostring(p))

AegisPathfinder:ResetActiveFrames()
p, rel = items:GetPoint()
check(rel == guide and AegisPathfinder.db.profile.activeitemspoint == nil,
	"Reset Panels puts it back under the guide")

-- Keeping up --------------------------------------------------------------------------

local driver = AegisPathfinder.activeDriver
local function tick()
	this = driver
	if driver:IsShown() then driver:GetScript("OnUpdate")() end
end
stub.bags = {}
AegisPathfinder:PaintActiveFrames()
check(not items:IsShown(), "empty to start")
stub.bags = saved
AegisPathfinder:RefreshActiveFrames()
tick()
check(items:IsShown(), "a step change repaints on the next frame")

-- Bag updates in a burst are one repaint, a moment later.
stub.bags = {}
event = "BAG_UPDATE"
this = AegisPathfinder.activeEvents
for _ = 1, 5 do AegisPathfinder.activeEvents:GetScript("OnEvent")() end
tick()
check(items:IsShown(), "not straight away")
now = now + 1
tick()
check(not items:IsShown(), "but once the burst has passed")
check(not driver:IsShown(), "and then it rests")
stub.bags = saved

-- Commands and key bindings -----------------------------------------------------------

check(BINDING_HEADER_AEGISPATHFINDER ~= nil, "the key bindings have a header")
local xml = io.open("Bindings.xml"):read("*a")
local bound = 0
for name, body in string.gfind(xml, '<Binding name="([^"]+)"[^>]*>(.-)</Binding>') do
	bound = bound + 1
	check(_G["BINDING_NAME_" .. name] ~= nil, "binding %s has a label", name)
	local _, _, fn = string.find(body, "AegisPathfinder:(%w+)%(")
	check(fn and type(AegisPathfinder[fn]) == "function", "binding %s calls a real function (%s)", name, tostring(fn))
end
check(bound == 2, "two bindings: use the item, target the target -- got %d", bound)

-- Report ---------------------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("ActiveFrames: %d checks", checks))
if table.getn(failures) == 0 then
	print("All active frame checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
