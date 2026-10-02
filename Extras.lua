--[[ Extras.lua -- the options' Extras page: what it adds to chat.

	  * Detailed reputation gains: when a reputation goes up, where it stands
	    and how far it is to the next rank -- "Stormwind +25: Honored 4,350 /
	    12,000, 7,650 to Revered" -- after the client's own line.
	  * Level-up announcements: an emote others nearby see, on until unticked
	    ("<name> Pathfinder: I just leveled up from 22 to 23! (2 hours 1
	    minute)"), and the same news to your party and guild, each off until
	    ticked ("Pathfinder: I leveled up from 22 to 23! (2 hours 1
	    minute)"). The time is how long you spent at the level just left,
	    from the guide browser's level tracker, and only when it counted all
	    of it.

	  * Show Pathfinder chat messages: AegisPathfinder:Say, below, which the
	    routine lines go through.
]]

local AegisPathfinder = AegisPathfinder

local Extras = {}
AegisPathfinder.Extras = Extras

-- How long after the client's reputation line its figures are read: the
-- standing and the line come from the same message, in either order.
local REP_DELAY = 0.2

local function Char() return AegisPathfinder.db and AegisPathfinder.db.char end

--- A routine chat line -- a flight taken, greys sold, an upgrade put on --
--- left out while "Show Pathfinder chat messages" is off. Errors, warnings
--- and replies to what the player clicked or typed use Print and always
--- show.
function AegisPathfinder:Say(msg)
	local char = Char()
	if char and char.chatmessages == false then return end
	return self:Print(msg)
end

--[[ Words -------------------------------------------------------------------------- ]]

--- 7650 as "7,650".
function Extras.Thousands(n)
	local s = tostring(math.floor(n))
	local sign = ""
	if string.sub(s, 1, 1) == "-" then sign, s = "-", string.sub(s, 2) end
	while true do
		local done
		s, done = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
		if done == 0 then break end
	end
	return sign .. s
end

local function Count(n, word)
	return n .. " " .. word .. (n == 1 and "" or "s")
end

--- Seconds as "2 hours 1 minute", "1 minute", "less than a minute": hours
--- only from an hour up.
function Extras.Duration(secs)
	local mins = math.floor(secs / 60)
	local hours = math.floor(mins / 60)
	mins = mins - hours * 60
	if hours > 0 then
		return Count(hours, "hour") .. (mins > 0 and (" " .. Count(mins, "minute")) or "")
	elseif mins > 0 then
		return Count(mins, "minute")
	end
	return "less than a minute"
end

--[[ Reputation --------------------------------------------------------------------- ]]

-- A client format string ("Reputation with %s increased by %d.") as a
-- pattern capturing its %s and %d.
local function Pattern(fmt)
	local p = string.gsub(fmt, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
	p = string.gsub(p, "%%s", "(.+)")
	p = string.gsub(p, "%%d", "(%%d+)")
	return "^" .. p .. "$"
end

--- The faction and the gain in a reputation line; nil for any other line,
--- a loss included.
function Extras.ParseGain(msg)
	local fmt = FACTION_STANDING_INCREASED or "Reputation with %s increased by %d."
	local _, _, faction, amount = string.find(msg or "", Pattern(fmt))
	if faction then return faction, tonumber(amount) end
end

-- The faction's row, if the list shows it: standing, bottom, top, value.
local function FindRow(faction)
	for i = 1, GetNumFactions() do
		local name, _, standing, bottom, top, value, _, _, isHeader = GetFactionInfo(i)
		if name == faction and not isHeader then return standing, bottom, top, value end
	end
end

--- Where a faction stands: its standing (1 to 8) and how far through that
--- rank, as the reputation panel gives them. A faction under a collapsed
--- header is looked for with the headers opened, and they are closed again.
function Extras.Standing(faction)
	local standing, bottom, top, value = FindRow(faction)
	if standing or not (ExpandFactionHeader and CollapseFactionHeader) then return standing, bottom, top, value end
	local opened = {}
	-- From the bottom up, so opening one does not move those still to open.
	for i = GetNumFactions(), 1, -1 do
		local name, _, _, _, _, _, _, _, isHeader, isCollapsed = GetFactionInfo(i)
		if isHeader and isCollapsed then
			ExpandFactionHeader(i)
			opened[name] = true
		end
	end
	standing, bottom, top, value = FindRow(faction)
	for i = GetNumFactions(), 1, -1 do
		local name, _, _, _, _, _, _, _, isHeader, isCollapsed = GetFactionInfo(i)
		if isHeader and not isCollapsed and opened[name] then CollapseFactionHeader(i) end
	end
	return standing, bottom, top, value
end

local function RankName(standing)
	return getglobal("FACTION_STANDING_LABEL" .. standing) or ("Rank " .. standing)
end

--- "Stormwind +25: Honored 4,350 / 12,000, 7,650 to Revered"; just the gain
--- when the faction cannot be found.
function Extras.ReputationLine(faction, amount)
	local head = faction .. " +" .. Extras.Thousands(amount)
	local standing, bottom, top, value = Extras.Standing(faction)
	if not standing then return head end
	local into, size = value - bottom, top - bottom
	local line = string.format("%s: %s %s / %s", head, RankName(standing), Extras.Thousands(into), Extras.Thousands(size))
	local nextName = getglobal("FACTION_STANDING_LABEL" .. (standing + 1))
	if nextName and standing < 8 then
		line = line .. string.format(", %s to %s", Extras.Thousands(top - value), nextName)
	end
	return line
end

--[[ Level-ups ---------------------------------------------------------------------- ]]

--- What each channel says for a level up from `from` to `to`, after `secs`
--- at the level (nil: not known).
function Extras.LevelMessages(from, to, secs)
	local time = secs and (" (" .. Extras.Duration(secs) .. ")") or ""
	return "Pathfinder: I just leveled up from " .. from .. " to " .. to .. "!" .. time,
		"Pathfinder: I leveled up from " .. from .. " to " .. to .. "!" .. time
end

--- Announce a level up to `level` where it is ticked: the emote (ticked
--- until unticked), and the party and guild when you are in one. Returns
--- how many went out.
function Extras:AnnounceLevel(level)
	local char = Char()
	if not char or not level then return 0 end
	local from = level - 1
	local secs, whole = AegisPathfinder:TimeAtLevel(from)
	local emote, group = Extras.LevelMessages(from, level, whole and secs or nil)
	local sent = 0
	if char.levelemote ~= false then
		SendChatMessage(emote, "EMOTE")
		sent = sent + 1
	end
	if char.levelparty and GetNumPartyMembers() > 0 then
		SendChatMessage(group, "PARTY")
		sent = sent + 1
	end
	if char.levelguild and IsInGuild() then
		SendChatMessage(group, "GUILD")
		sent = sent + 1
	end
	return sent
end

--[[ Events ------------------------------------------------------------------------- ]]

local frame = CreateFrame("Frame")
Extras.frame = frame
Extras.pending = {}
frame:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:SetScript("OnEvent", function()
	local char = Char()
	if not char then return end
	if event == "PLAYER_LEVEL_UP" then
		Extras:AnnounceLevel(tonumber(arg1))
	elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" and char.repdetail then
		local faction, amount = Extras.ParseGain(arg1)
		if faction then
			table.insert(Extras.pending, { faction = faction, amount = amount, wait = REP_DELAY })
		end
	end
end)
-- The pending reputation lines, said once their figures have settled.
frame:SetScript("OnUpdate", function()
	local list = Extras.pending
	if table.getn(list) == 0 then return end
	local i = 1
	while i <= table.getn(list) do
		local p = list[i]
		p.wait = p.wait - (arg1 or 0)
		if p.wait <= 0 then
			table.remove(list, i)
			AegisPathfinder:Print(Extras.ReputationLine(p.faction, p.amount))
		else
			i = i + 1
		end
	end
end)
