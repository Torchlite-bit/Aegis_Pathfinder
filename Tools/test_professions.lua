--[[
	End-to-end test for the profession guide pipeline.

	Loads the generated guides, runs them through the real QuestShell+ parser,
	and checks that the trade-skill tags survive the round trip into the
	accessors Professions.lua reads them back with. This exercises the actual
	shipped code paths, not a reimplementation of them.

	Run:  lua5.1 Tools/test_professions.lua
]]

package.path = "Tools/?.lua;" .. package.path
local stub = require("wow_stub")
stub.install(_G)

-- Minimum addon surface the parsers touch.
AegisPathfinder = {
	guides = {}, guidelist = {}, nextzones = {}, qsplusguides = {},
	myfaction = "Alliance",
	tags = {}, actions = {}, quests = {}, turnedin = {},
	current = 1,
}
function AegisPathfinder:Debug() end
function AegisPathfinder:Print() end
function AegisPathfinder.trim(s)
	return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end
function AegisPathfinder.select(index, ...)
	if index == "#" then return table.getn(arg) end
	return arg[index]
end
function AegisPathfinder:RegisterGuide(name, nextzone, faction, loader)
	self.guides[name] = loader
	self.nextzones[name] = nextzone
	table.insert(self.guidelist, name)
end
function AegisPathfinder:GetObjectiveStatus() return nil end
function AegisPathfinder:SetTurnedIn() self.__turnedIn = true end
function AegisPathfinder:UpdateStatusFrame() end
function AegisPathfinder:RegisterEvent() end

dofile("Parser.lua")
dofile("QuestShellPlusParser.lua")
dofile("Professions.lua")

local failures, checks = {}, 0
local function check(cond, fmt, ...)
	checks = checks + 1
	if not cond then table.insert(failures, string.format(fmt, ...)) end
end

-- Load every generated guide -------------------------------------------------

local AUTHORED = {
	"Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering", "First_Aid",
	"Fishing", "Herbalism", "Jewelcrafting", "Leatherworking", "Mining", "Skinning",
	"Survival", "Tailoring",
}
local GATHERED = { "Herbalism", "Skinning", "Fishing" }
local FACTIONS = { "Alliance", "Horde" }

for _, name in ipairs(AUTHORED) do
	dofile("Guides/Professions/" .. name .. ".lua")
end

check(table.getn(AegisPathfinder.guidelist) == 14,
	"expected 14 profession guides registered, got %d",
	table.getn(AegisPathfinder.guidelist))

-- Structural checks over every authored guide --------------------------------

for _, key in ipairs(AegisPathfinder.guidelist) do
	local guide = AegisPathfinder.qsplusguides[key]
	check(guide ~= nil, "%s did not register a QuestShell+ table", key)
	if guide then
		check(guide.faction == "Both", "%s should be faction Both", key)
		check(guide.category == "Profession", "%s should be category Profession", key)
		check(table.getn(guide.steps) > 0, "%s has no steps", key)
	end
end

-- Skill ranges must tile 1..300 without gaps, in every authored guide, as
-- each faction sees it: a gathering guide's bands are one per faction.
for _, name in ipairs(AUTHORED) do
	local display = string.gsub(name, "_", " ") .. " (1-300)"
	local guide = AegisPathfinder.qsplusguides[display]
	check(guide ~= nil, "no guide registered as '%s'", display)
	check(guide and not guide.template, "%s is authored, not a placeholder", display)
	for _, fac in ipairs(FACTIONS) do
		local cursor, seen = nil, 0
		for _, step in ipairs(guide and guide.steps or {}) do
			if step.skill and (not step.faction or step.faction == fac) then
				seen = seen + 1
				if cursor == nil then
					check(step.skill.from == 1, "%s (%s): first range starts at %d, not 1",
						display, fac, step.skill.from)
				else
					check(step.skill.from == cursor,
						"%s (%s): range starts at %d but previous ended at %d",
						display, fac, step.skill.from, cursor)
				end
				check(step.skill.to > step.skill.from,
					"%s: range %d-%d does not advance",
					display, step.skill.from, step.skill.to)
				cursor = step.skill.to
			end
		end
		check(seen > 0, "%s has no skill steps for %s", display, fac)
		check(cursor == 300, "%s (%s): route ends at %s, not 300", display, fac, tostring(cursor))
	end
end

-- Gathering guides ------------------------------------------------------------

-- Each band says where to go, and each faction is sent only to its own side
-- of the map: no Horde starting zone or capital for an Alliance player, and
-- the reverse.
local OTHER_SIDE = {
	Alliance = { "Durotar", "Mulgore", "Tirisfal Glades", "Orgrimmar", "Thunder Bluff", "Undercity" },
	Horde = { "Elwynn Forest", "Dun Morogh", "Teldrassil", "Stormwind City", "Ironforge", "Darnassus" },
}
for _, name in ipairs(GATHERED) do
	local guide = AegisPathfinder.qsplusguides[name .. " (1-300)"]
	for _, fac in ipairs(FACTIONS) do
		local caps, bands = {}, 0
		for _, s in ipairs(guide.steps) do
			if not s.faction or s.faction == fac then
				if s.skill then
					bands = bands + 1
					check(string.find(s.note, "Best: ", 1, true) or string.find(s.note, "Fish anywhere", 1, true),
						"%s (%s): %d-%d names no place", name, fac, s.skill.from, s.skill.to)
				end
				if s.rank then caps[s.rank.cap] = (caps[s.rank.cap] or 0) + 1 end
				for _, zone in ipairs(OTHER_SIDE[fac]) do
					check(not string.find(s.note or "", zone, 1, true),
						"%s: %s is sent to %s (%s)", name, fac, zone, s.title)
				end
			end
		end
		check(bands >= 4, "%s (%s): only %d bands", name, fac, bands)
		-- Every rank is reached, once each for this faction -- Fishing's
		-- Artisan by trainer or Nat Pagle's quest, whichever the side has.
		for _, cap in ipairs({ 75, 150, 225 }) do
			check(caps[cap] == 1, "%s (%s): the rank to %d is reached %s time(s)", name, fac, cap, tostring(caps[cap]))
		end
		check(caps[300] and caps[300] >= 1, "%s (%s): nothing reaches 300", name, fac)
	end
end

local fishing = AegisPathfinder.qsplusguides["Fishing (1-300)"]
local book, pagle
for _, s in ipairs(fishing.steps) do
	if s.type == "BUY" and s.rank and s.rank.cap == 225 then book = s end
	if s.rank and s.rank.cap == 300 and s.npcs and s.npcs[1] == "Nat Pagle" then pagle = s end
end
check(book and string.find(book.title, "Expert Fishing", 1, true), "Expert Fishing is a book you buy")
check(pagle and not pagle.faction, "Nat Pagle's hand-in raises the cap to 300 for either side")

-- Engineering, authored from CraftRoute's route --------------------------------

local eng = AegisPathfinder.qsplusguides["Engineering (1-300)"]
check(eng and not eng.template, "Engineering is authored, not a placeholder")
if eng then
	local ranks, crafts, reagentless, trainers = {}, 0, 0, {}
	local lastSkill = 1
	for _, s in ipairs(eng.steps) do
		if s.skill then
			crafts = crafts + 1
			if not s.reagents or table.getn(s.reagents) == 0 then reagentless = reagentless + 1 end
			lastSkill = s.skill.to
		end
		if s.rank then
			ranks[s.rank.cap] = (ranks[s.rank.cap] or 0) + 1
			-- Each rank is trained once the skill it needs is reached and
			-- before the old cap stops you: 50, 125 and 200.
			local needs = { [75] = 1, [150] = 50, [225] = 125, [300] = 200 }
			check(lastSkill >= needs[s.rank.cap] and lastSkill <= s.rank.cap - 75 or s.rank.cap == 75,
				"Engineering: the rank to %d comes at skill %d", s.rank.cap, lastSkill)
			for _, n in ipairs(s.npcs or {}) do trainers[n] = true end
		end
	end
	check(crafts == 22, "Engineering has CraftRoute's 22 craft steps (%d)", crafts)
	check(reagentless == 0, "every Engineering craft lists its reagents")
	for _, cap in ipairs({ 75, 150, 225, 300 }) do
		check(ranks[cap] == 2, "Engineering trains the rank to %d, once per faction (%s)", cap, tostring(ranks[cap]))
	end
	check(trainers["Buzzek Bracketswing"] and trainers["Roxxik"] and trainers["Springspindle Fizzlegear"],
		"Engineering's rank steps name their trainers")
end

-- Tag round trip -------------------------------------------------------------

local actions, quests, tags = AegisPathfinder:ParseQuestShellPlus(
	AegisPathfinder.qsplusguides["Alchemy (1-300)"])
check(table.getn(actions) > 0, "Alchemy produced no parsed steps")

AegisPathfinder.actions, AegisPathfinder.quests, AegisPathfinder.tags = actions, quests, tags

local craftIndex
for i = 1, table.getn(tags) do
	if string.find(tags[i], "|CRAFT|40 Minor Healing Potion|", 1, true) then
		craftIndex = i
		break
	end
end
check(craftIndex ~= nil, "no step emitted |CRAFT|40 Minor Healing Potion|")

if craftIndex then
	local profession, from, to = AegisPathfinder:GetObjectiveTag("SKILL", craftIndex)
	check(profession == "Alchemy", "SKILL profession round-tripped as '%s'", tostring(profession))
	check(from == 1 and to == 63, "SKILL range round-tripped as %s-%s",
		tostring(from), tostring(to))

	local item, count = AegisPathfinder:GetObjectiveTag("CRAFT", craftIndex)
	check(item == "Minor Healing Potion", "CRAFT item round-tripped as '%s'", tostring(item))
	check(count == 40, "CRAFT count round-tripped as %s", tostring(count))

	local src = AegisPathfinder:GetObjectiveTag("SRC", craftIndex)
	check(src == "Auto-learned", "SRC round-tripped as '%s'", tostring(src))

	local reagents = AegisPathfinder:GetStepReagents(craftIndex)
	check(reagents ~= nil and table.getn(reagents) == 3,
		"expected 3 reagents, got %s", reagents and table.getn(reagents) or "nil")
	if reagents then
		check(reagents[1].item == "Peacebloom", "first reagent is '%s'", reagents[1].item)
		-- 40 crafts x 1 Peacebloom each
		check(reagents[1].need == 40, "Peacebloom need should be 40, got %d", reagents[1].need)
	end
end

-- A profession name containing a space must survive the SKILL tag.
local faActions, faQuests, faTags = AegisPathfinder:ParseQuestShellPlus(
	AegisPathfinder.qsplusguides["First Aid (1-300)"])
AegisPathfinder.actions, AegisPathfinder.quests, AegisPathfinder.tags =
	faActions, faQuests, faTags
local found
for i = 1, table.getn(faTags) do
	local profession = AegisPathfinder:GetObjectiveTag("SKILL", i)
	if profession then found = profession break end
end
check(found == "First Aid",
	"a two-word profession should round-trip intact, got '%s'", tostring(found))

-- Faction filtering ----------------------------------------------------------

local function trainerCountFor(faction)
	AegisPathfinder.myfaction = faction
	local a, q, t = AegisPathfinder:ParseQuestShellPlus(
		AegisPathfinder.qsplusguides["Alchemy (1-300)"])
	local n = 0
	for i = 1, table.getn(q) do
		if string.find(q[i], "Alchemy %(") and a[i] == "TRAIN" then n = n + 1 end
	end
	return n
end

local alliance = trainerCountFor("Alliance")
local horde = trainerCountFor("Horde")
check(alliance > 0, "Alliance sees no Alchemy trainer steps")
check(horde > 0, "Horde sees no Alchemy trainer steps")

AegisPathfinder.myfaction = "Alliance"
local a2, q2, t2 = AegisPathfinder:ParseQuestShellPlus(
	AegisPathfinder.qsplusguides["Alchemy (1-300)"])
local sawHordeTrainer = false
for i = 1, table.getn(q2) do
	-- Whuut is Horde-only (Orgrimmar); an Alliance player must never see him.
	if string.find(q2[i], "Whuut", 1, true) or string.find(t2[i] or "", "Whuut", 1, true) then
		sawHordeTrainer = true
	end
end
check(not sawHordeTrainer, "an Alliance player was shown a Horde-only trainer")

-- Skill tracking -------------------------------------------------------------

local ranks = {}
GetNumSkillLines = function() return table.getn(ranks) end
GetSkillLineInfo = function(i)
	local r = ranks[i]
	return r.name, r.header, false, r.rank
end

ranks = { { name = "Alchemy", header = nil, rank = 40 } }
check(AegisPathfinder:GetSkillRank("Alchemy") == 40, "GetSkillRank should read the skill line")
check(AegisPathfinder:GetSkillRank("Tailoring") == nil,
	"GetSkillRank should return nil for a profession the player lacks")

-- Mining's skill line is "Mining" while guides may say "Smelting".
ranks = { { name = "Mining", header = nil, rank = 150 } }
check(AegisPathfinder:GetSkillRank("Smelting") == 150,
	"Smelting should resolve to the Mining skill line")

-- Headers must never be matched as a skill.
ranks = { { name = "Professions", header = 1, rank = 0 },
          { name = "Cooking", header = nil, rank = 75 } }
check(AegisPathfinder:GetSkillRank("Professions") == nil,
	"a skill-list header is not a profession")
check(AegisPathfinder:GetSkillRank("Cooking") == 75, "Cooking rank should be found")

-- Auto-completion fires only once the target is reached.
AegisPathfinder.actions, AegisPathfinder.quests, AegisPathfinder.tags = actions, quests, tags
AegisPathfinder.current = craftIndex
ranks = { { name = "Alchemy", header = nil, rank = 62 } }
AegisPathfinder.__turnedIn = nil
AegisPathfinder:CheckSkillObjective()
check(AegisPathfinder.__turnedIn == nil,
	"a step must not complete one point short of its target")

ranks = { { name = "Alchemy", header = nil, rank = 63 } }
AegisPathfinder:CheckSkillObjective()
check(AegisPathfinder.__turnedIn == true, "reaching the target should complete the step")

-- Progress reporting.
ranks = { { name = "Alchemy", header = nil, rank = 32 } }
local ratio = AegisPathfinder:GetSkillProgress(craftIndex)
check(ratio > 0.49 and ratio < 0.51, "skill 32 of 1-63 should read ~50%%, got %s",
	tostring(ratio))
ranks = {}
check(AegisPathfinder:GetSkillProgress(craftIndex) == nil,
	"progress should be nil when the player lacks the profession")

-- Report ---------------------------------------------------------------------

for _, e in ipairs(stub.report()) do table.insert(failures, "API misuse: " .. e) end

print(string.format("Professions: %d checks across %d guides",
	checks, table.getn(AegisPathfinder.guidelist)))
if table.getn(failures) == 0 then
	print("All profession checks passed.")
	os.exit(0)
end
print(string.format("\n%d failure(s):", table.getn(failures)))
for _, f in ipairs(failures) do print("  - " .. f) end
os.exit(1)
