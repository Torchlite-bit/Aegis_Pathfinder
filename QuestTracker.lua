-- QuestTracker.lua
-- Quest log scanning and completion detection for TurtleGuide

local TurtleGuide = TurtleGuide
local L = TurtleGuide.Locale


-- QUEST_ACCEPTED and QUEST_TURNED_IN are synthesized by ClassicAPI (a hard
-- requirement, enforced in Core.lua OnEnable)
TurtleGuide.TrackEvents = {
	"UI_INFO_MESSAGE", "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM",
	"QUEST_WATCH_UPDATE", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED",
	"ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "MINIMAP_ZONE_CHANGED",
	"ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "ADDON_LOADED",
	"CRAFT_SHOW", "PLAYER_DEAD", "SKILL_LINES_CHANGED", "SPELLS_CHANGED",
	"QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "HEARTHSTONE_BOUND",
	"BAG_UPDATE_DELAYED", "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL",
	"QUEST_PROGRESS", "QUEST_COMPLETE"
}


-- AceEvent-2.0 passes event args directly (no event name); the event itself
-- is available as self.currentEvent when needed
function TurtleGuide:ADDON_LOADED(addon)
	if addon ~= "Blizzard_TrainerUI" then return end

	self:UnregisterEvent("ADDON_LOADED")

	local f = CreateFrame("Frame", nil, ClassTrainerFrame)
	f:SetScript("OnShow", function()
		if self:GetObjectiveInfo() == "TRAIN" then self:SetTurnedIn() end
	end)
end

function TurtleGuide:SKILL_LINES_CHANGED()
	self:ScheduleStatusUpdate()
end

function TurtleGuide:SPELLS_CHANGED()
	self:ScheduleStatusUpdate()
end

function TurtleGuide:PLAYER_LEVEL_UP(newlevel)
	local level = tonumber((self:GetObjectiveTag("LV")))
	self:Debug("PLAYER_LEVEL_UP", newlevel, level)
	if level and newlevel >= level then self:SetTurnedIn() end
end

function TurtleGuide:ZONE_CHANGED(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19,
								  a20)
	local zonetext, subzonetext, subzonetag, action, quest = GetZoneText(), GetSubZoneText(), self:GetObjectiveTag("SZ"),
		self:GetObjectiveInfo()
	if (action == "RUN" or action == "FLY" or action == "HEARTH" or action == "BOAT") and (subzonetext == quest or subzonetext == subzonetag or zonetext == quest or zonetext == subzonetag) then
		self:Debug(string.format("Detected zone change %q - %q", action, quest))
		self:SetTurnedIn()
	end
end

TurtleGuide.ZONE_CHANGED_INDOORS = TurtleGuide.ZONE_CHANGED
TurtleGuide.MINIMAP_ZONE_CHANGED = TurtleGuide.ZONE_CHANGED
TurtleGuide.ZONE_CHANGED_NEW_AREA = TurtleGuide.ZONE_CHANGED


-- Fires on the bind-point update packet (ClassicAPI); no payload, re-read
-- GetBindLocation() for the new home
function TurtleGuide:HEARTHSTONE_BOUND()
	local loc = GetBindLocation()
	local action, quest = self:GetObjectiveInfo()
	self:Debug(string.format("Detected setting hearth to %q", loc))
	self.db.char.hearth = loc
	if action == "SETHEARTH" and loc == quest then self:SetTurnedIn() end
end

function TurtleGuide:CHAT_MSG_SYSTEM(msg)
	local action, quest = self:GetObjectiveInfo()

	if action == "PET" then
		local _, _, text = string.find(msg, L["You have learned a new spell: (.*)."])
		local nextEntry = table.getn(self.db.char.petskills) + 1
		self.db.char.petskills[nextEntry] = text
		if text and quest == text then
			self:Debug(string.format("Detected pet skill train %q", quest))
			return self:SetTurnedIn()
		end
	end
end

function TurtleGuide:QUEST_WATCH_UPDATE(event)
	if self:GetObjectiveInfo() == "COMPLETE" then self:ScheduleStatusUpdate() end
end

function TurtleGuide:QUEST_LOG_UPDATE(event)
	local action = self:GetObjectiveInfo()
	local _, logi, complete = self:GetObjectiveStatus()

	self:Debug("QUEST_LOG_UPDATE", action, logi, complete)

	-- UpdateStatusFrame gates on the delayed step itself, so run it whenever a
	-- delayed update is pending; checking the current step's logi here would
	-- miss turnins recorded for a step other than the current one
	if self.updatedelay or action == "ACCEPT" or action == "COMPLETE" then self:ScheduleStatusUpdate() end

	if action == "KILL" or action == "NOTE" then
		local quest, questtext = self:GetObjectiveTag("Q"), self:GetObjectiveTag("QO")
		if not quest or not questtext then return end

		local qi = self:GetQuestLogIndexByName(quest)
		for i = 1, GetNumQuestLeaderBoards(qi) do
			if GetQuestLogLeaderBoard(i, qi) == questtext then self:SetTurnedIn() end
		end
	elseif action == "COMPLETE" then
		local skipNext = self:GetObjectiveTag("S")
		if self.db.char.skipfollowups and skipNext and QuestFrame:IsVisible() then
			CloseQuest()
			TurtleGuide:Print(L["Automatically skipping the follow-up"])
		end
	end
end

function TurtleGuide:UNIT_QUEST_LOG_CHANGED(unit)
	if unit ~= "player" then return end
	local action = self:GetObjectiveInfo()
	if action == "COMPLETE" then
		self:ScheduleStatusUpdate()
	end
end

-- Legacy BUY steps without an |L| tag can only be matched by looted item
-- name; |L|-tagged collect steps are counted in BAG_UPDATE_DELAYED instead
function TurtleGuide:CHAT_MSG_LOOT(msg)
	local action, quest = self:GetObjectiveInfo()
	if action ~= "BUY" or self:GetObjectiveTag("L") then return end

	local _, _, _, name = string.find(msg, L["^You .*Hitem:(%d+).*(%[.+%])"])
	if name and string.sub(name, 2, -2) == quest then
		self:Debug(string.format("Detected buy %q", quest))
		self:SetTurnedIn()
	end
end

-- Fires once per bag-content batch (ClassicAPI): loot, mail, trade, vendor,
-- AH. Count |L|-tagged collect steps by itemID instead of parsing loot
-- messages; this also catches items that never produce a loot message.
function TurtleGuide:BAG_UPDATE_DELAYED()
	local action = self:GetObjectiveInfo()
	if action ~= "BUY" and action ~= "KILL" and action ~= "NOTE" and action ~= "COMPLETE" then return end

	local lootitem, lootqty = self:GetLootRequirement()
	if not lootitem then return end

	if C_Item.GetItemCount(lootitem) >= lootqty then
		self:Debug(string.format("Detected item count met %s x%d", lootitem, lootqty))
		self:SetTurnedIn()
	end
end

function TurtleGuide:PLAYER_DEAD()
	if self:GetObjectiveInfo() == "DIE" then
		self:Debug("Player has died")
		self:SetTurnedIn()
	end
end

function TurtleGuide:UI_INFO_MESSAGE(msg)
	if msg == ERR_NEWTAXIPATH and self:GetObjectiveInfo() == "GETFLIGHTPOINT" then
		self:Debug("Discovered flight point")
		self:SetTurnedIn()
	end
end

-- Detect NPC interaction for GETFLIGHTPOINT objectives
local flightEventFrame = CreateFrame("Frame")
flightEventFrame:RegisterEvent("TAXIMAP_OPENED")
flightEventFrame:RegisterEvent("GOSSIP_SHOW")
flightEventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
flightEventFrame:SetScript("OnEvent", function()
	if TurtleGuide:GetObjectiveInfo() ~= "GETFLIGHTPOINT" then return end

	if event == "TAXIMAP_OPENED" or event == "GOSSIP_SHOW" then
		TurtleGuide:Debug(event .. " - completing GETFLIGHTPOINT")
		TurtleGuide:SetTurnedIn()
	elseif event == "PLAYER_TARGET_CHANGED" then
		-- Check if targeting a friendly NPC (likely the flight master)
		if UnitExists("target") and not UnitIsPlayer("target") and not UnitCanAttack("player", "target") then
			TurtleGuide:Debug("Targeted friendly NPC - completing GETFLIGHTPOINT")
			TurtleGuide:SetTurnedIn()
		end
	end
end)


function TurtleGuide:CRAFT_SHOW()
	if not GetCraftName() == "Beast Training" then return end
	for i = 1, GetNumCrafts() do
		local name, rank = GetCraftInfo(i)
		self.db.char.petskills[name .. (rank == "" and "" or (" (" .. rank .. ")"))] = true
	end
	if self:GetObjectiveInfo() == "PET" then self:UpdateStatusFrame() end
end

-- During NPC interaction self.current lags behind: the advance past a
-- just-finished step happens on the next quest log update, often after the
-- follow-up QUEST_DETAIL or reopened gossip has already fired. Resolve the
-- first step at or after current that is not already turned in, so automation
-- never keys off a stale step.
local function PendingStep()
	local i = TurtleGuide.current
	if not i or not TurtleGuide.actions then return end
	while TurtleGuide.actions[i] and TurtleGuide:GetObjectiveStatus(i) do
		i = i + 1
	end
	if TurtleGuide.actions[i] then return i end
end

-- Returns the clean quest name and step index when the pending step matches
-- the action
local function CurrentStepName(action)
	local i = PendingStep()
	if not i then return end
	local a, quest = TurtleGuide:GetObjectiveInfo(i)
	if a ~= action or not quest then return end
	return (string.gsub(quest, L.PART_GSUB, "")), i
end

-- Quest accept detection. QUEST_ACCEPTED carries the questID, so ACCEPT steps
-- match by |QID| tag instead of parsing the "Quest accepted:" system message.
function TurtleGuide:QUEST_ACCEPTED(questLogIndex, questID)
	questID = tonumber(questID)
	self:Debug("QUEST_ACCEPTED", questLogIndex, questID)
	if not questID then return end

	local quest, i = CurrentStepName("ACCEPT")
	if not quest then return end

	local qid = tonumber((self:GetObjectiveTag("QID", i)))
	if qid then
		if qid == questID then
			self:Debug(string.format("Detected quest accept by QID %d %q", questID, quest))
			self:UpdateStatusFrame()
		end
		return
	end

	-- Step has no |QID| tag; compare titles instead
	local title = C_QuestLog.GetTitleForQuestID(questID)
	if title and quest == title then
		self:Debug(string.format("Detected quest accept %q", quest))
		self:UpdateStatusFrame()
	end
end

-- Quest turnin tracking. QUEST_TURNED_IN fires on server confirmation and
-- carries the questID, so it also catches turnins for quests outside the
-- loaded guide.
function TurtleGuide:QUEST_TURNED_IN(questID, xpReward, moneyReward)
	questID = tonumber(questID)
	self:Debug("QUEST_TURNED_IN", questID, xpReward, moneyReward)
	if not questID then return end

	self.db.char.completedquestsbyid[questID] = true

	if not self:CompleteQuestByQid(questID, true) then
		-- No |QID| match in the guide; track and match by title instead
		local title = C_QuestLog.GetTitleForQuestID(questID)
		if title then
			self.db.char.completedquests[title] = true
			self:CompleteQuest(title, true)
		end
	end

	-- The quest is usually still in the log here; the removal arrives via
	-- the follow-up log update and fires QUEST_REMOVED, which advances.
	-- This covers the other ordering, should a server remove it inline.
	if self.current and not C_QuestLog.IsOnQuest(questID) then
		self:UpdateStatusFrame()
	end
end

-- Quest left the log (ClassicAPI event; fires for turn-ins and abandons).
-- For turn-ins it follows QUEST_TURNED_IN, so the step is already marked
-- and the removal is the moment the delayed update can advance. A removal
-- with no turn-in confirmation is an abandon: rescan so the guide routes
-- back to the abandoned quest's accept step.
function TurtleGuide:QUEST_REMOVED(questID)
	questID = tonumber(questID)
	self:Debug("QUEST_REMOVED", questID)
	if not questID then return end

	if self.db.char.completedquestsbyid[questID] then
		if self.current then self:UpdateStatusFrame() end
		return
	end

	-- Grace period in case a late QUEST_TURNED_IN is still in flight
	C_Timer.After(0.5, function()
		if not self.current or not self.actions then return end
		if self.db.char.completedquestsbyid[questID] then return end
		self:Debug(string.format("QID %d abandoned - rescanning", questID))
		self:UpdateStatusFrame()
	end)
end


---------------------------------
--  Quest automation           --
---------------------------------

-- Hold SHIFT while talking to an NPC to suspend automation
local function AutomationSuspended()
	return not TurtleGuide.db.char.autoquest or IsShiftKeyDown()
end

-- Quest frame titles may carry a [level] prefix depending on server settings
local function QuestFrameTitle()
	return (string.gsub(GetTitleText() or "", "%[[0-9%+%-]+]%s", ""))
end

-- Auto-select the pending step's quest from the gossip list, matched by QID
-- (by title for untagged steps)
function TurtleGuide:GOSSIP_SHOW()
	if AutomationSuspended() then return end

	local name, i = CurrentStepName("ACCEPT")
	if name then
		local qid = tonumber((self:GetObjectiveTag("QID", i)))
		for _, q in ipairs(C_GossipInfo.GetAvailableQuests()) do
			if qid == q.questID or (not qid and q.title == name) then
				self:Debug(string.format("Auto-selecting available quest %d %q", q.questID, q.title))
				return C_GossipInfo.SelectAvailableQuest(q.questID)
			end
		end
		return
	end

	name, i = CurrentStepName("TURNIN")
	if name then
		local qid = tonumber((self:GetObjectiveTag("QID", i)))
		for _, q in ipairs(C_GossipInfo.GetActiveQuests()) do
			if q.isComplete and (qid == q.questID or (not qid and q.title == name)) then
				self:Debug(string.format("Auto-selecting active quest %d %q", q.questID, q.title))
				return C_GossipInfo.SelectActiveQuest(q.questID)
			end
		end
	end
end

-- Greeting panel (quest NPCs without gossip text). The greeting API is
-- index-based and carries no questIDs, so titles are the only match key.
function TurtleGuide:QUEST_GREETING()
	if AutomationSuspended() then return end

	local name = CurrentStepName("ACCEPT")
	if name then
		for i = 1, GetNumAvailableQuests() do
			if GetAvailableTitle(i) == name then
				self:Debug(string.format("Auto-selecting available quest (greeting) %q", name))
				return SelectAvailableQuest(i)
			end
		end
		return
	end

	name = CurrentStepName("TURNIN")
	if name then
		for i = 1, GetNumActiveQuests() do
			if GetActiveTitle(i) == name then
				self:Debug(string.format("Auto-selecting active quest (greeting) %q", name))
				return SelectActiveQuest(i)
			end
		end
	end
end

function TurtleGuide:QUEST_DETAIL()
	if not AutomationSuspended() then
		local name = CurrentStepName("ACCEPT")
		if name and QuestFrameTitle() == name then
			self:Debug(string.format("Auto-accepting %q", name))
			AcceptQuest()
		end
	end
	self:UpdateStatusFrame()
end

function TurtleGuide:QUEST_PROGRESS()
	if AutomationSuspended() then return end
	local name = CurrentStepName("TURNIN")
	if name and QuestFrameTitle() == name and IsQuestCompletable() then
		self:Debug(string.format("Auto-completing %q", name))
		CompleteQuest()
	end
end

-- Claim the reward only when there is no choice to make
function TurtleGuide:QUEST_COMPLETE()
	if not AutomationSuspended() then
		local name = CurrentStepName("TURNIN")
		if name and QuestFrameTitle() == name and GetNumQuestChoices() <= 1 then
			self:Debug(string.format("Auto-claiming reward for %q", name))
			GetQuestReward(GetNumQuestChoices())
		end
	end
	self:UpdateStatusFrame()
end

-- The quest windows outlive the step that opened them: a follow-up
-- QUEST_DETAIL or reopened gossip arrives before the status frame advances
-- past the finished step, and no further event fires once it does. Called
-- from UpdateStatusFrame after the step advances to feed the still-open
-- window back through the handlers above.
local redriving
function TurtleGuide:RedriveQuestAutomation()
	if redriving or AutomationSuspended() then return end
	redriving = true
	if GossipFrame and GossipFrame:IsVisible() then
		self:GOSSIP_SHOW()
	elseif QuestFrame and QuestFrame:IsVisible() then
		if QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsVisible() then
			self:QUEST_GREETING()
		elseif QuestFrameDetailPanel:IsVisible() then
			self:QUEST_DETAIL()
		elseif QuestFrameProgressPanel:IsVisible() then
			self:QUEST_PROGRESS()
		elseif QuestFrameRewardPanel:IsVisible() then
			self:QUEST_COMPLETE()
		end
	end
	redriving = false
end


-- Hook UseContainerItem to detect USE objective completion
local origUseContainerItem = UseContainerItem
UseContainerItem = function(bag, slot, ...)
	local action = TurtleGuide:GetObjectiveInfo()
	local useitem = TurtleGuide:GetObjectiveTag("U")

	if action == "USE" and useitem and C_Container.GetContainerItemID(bag, slot) == tonumber(useitem) then
		TurtleGuide:Debug("Detected USE item from bag: " .. useitem)
		-- Delay slightly to allow the item use to complete
		C_Timer.After(0.3, function()
			if TurtleGuide:GetObjectiveInfo() == "USE" then
				TurtleGuide:Debug("Completing USE objective after item use")
				TurtleGuide:SetTurnedIn()
			end
		end)
	end

	return origUseContainerItem(bag, slot, unpack(arg))
end


-- Distance-based arrival detection for travel objectives. Runs for every
-- waypoint provider: only TomTom offers arrival callbacks of its own, and this
-- check is cheap enough to run alongside them.
local ARRIVAL_CHECK_INTERVAL = 0.5 -- Check every 0.5 seconds
local ARRIVAL_DISTANCE = 0.005     -- Map coordinate distance threshold (~15-18 yards)

-- Zone name to continent/zone index lookup (built from Navigation.lua pattern)
local zonei, zonec = {}, {}
for ci, c in pairs({ GetMapContinents() }) do
	for zi, z in pairs({ GetMapZones(ci) }) do
		zonei[z], zonec[z] = zi, ci
	end
end

-- Check if current objective completion conditions are already met
local function RecheckCurrentObjective()
	if not TurtleGuide.current or not TurtleGuide.actions then return end

	local action = TurtleGuide:GetObjectiveInfo()
	if not action then return end

	TurtleGuide:Debug("Rechecking completion for: " .. action)

	-- GETFLIGHTPOINT: Check if targeting friendly NPC
	if action == "GETFLIGHTPOINT" then
		if UnitExists("target") and not UnitIsPlayer("target") and not UnitCanAttack("player", "target") then
			TurtleGuide:Debug("Recheck: Already targeting friendly NPC - completing GETFLIGHTPOINT")
			TurtleGuide:SetTurnedIn()
			return
		end
	end

	-- Travel objectives: Will be caught by the distance check below
end

C_Timer.NewTicker(ARRIVAL_CHECK_INTERVAL, function()
	-- Flush an expired delayed update even when no quest events arrive;
	-- UpdateStatusFrame clears updatedelay once its gate passes
	if TurtleGuide.updatedelay and GetTime() - (TurtleGuide.updatedelaytime or 0) >= 3 then
		TurtleGuide:ScheduleStatusUpdate()
	end

	-- Check if we need to re-evaluate after rewind
	if TurtleGuide.recheckCompletion then
		TurtleGuide.recheckCompletion = nil
		RecheckCurrentObjective()
	end

	-- Only check if guide is loaded
	if not TurtleGuide.current or not TurtleGuide.actions then return end

	local action, quest = TurtleGuide:GetObjectiveInfo()
	if not action then return end

	-- Only check for travel/arrival objectives
	if action ~= "RUN" and action ~= "FLY" and action ~= "HEARTH" and action ~= "BOAT" and action ~= "GETFLIGHTPOINT" then return end

	-- Get target coordinates from note
	local note = TurtleGuide:GetObjectiveTag("N")
	if not note then return end

	local targetX, targetY
	for x, y in string.gfind(note, L.COORD_MATCH) do
		targetX, targetY = tonumber(x) / 100, tonumber(y) / 100
		break -- Use first coordinate found
	end

	if not targetX or not targetY then return end

	-- Get target zone
	local targetZone = TurtleGuide:GetObjectiveTag("Z") or TurtleGuide.zonename

	-- Get player position safely without interrupting the map view if open
	local playerC, playerZ, playerX, playerY
	local wasShown = WorldMapFrame:IsShown()

	if wasShown then
		-- If map is open, check if it's currently showing the player's zone
		local currentZoneName = GetRealZoneText()
		local playerZC, playerZI = zonec[currentZoneName], zonei[currentZoneName]
		local mapC, mapZ = GetCurrentMapContinent(), GetCurrentMapZone()

		if playerZC and playerZI and mapC == playerZC and mapZ == playerZI then
			playerC, playerZ = mapC, mapZ
			playerX, playerY = GetPlayerMapPosition("player")
		else
			-- Player is looking at a different map or zoomed out, skip check to avoid resetting their view
			return
		end
	else
		-- Map is hidden, safe to set to current zone and get position
		SetMapToCurrentZone()
		playerC, playerZ = GetCurrentMapContinent(), GetCurrentMapZone()
		playerX, playerY = GetPlayerMapPosition("player")
	end

	-- If target zone is specified, check we're in the right zone
	if targetZone then
		local targetZI, targetZC = zonei[targetZone], zonec[targetZone]
		if targetZC and targetZI and (playerC ~= targetZC or playerZ ~= targetZI) then
			return -- Not in target zone yet
		end
	end

	-- Skip if we couldn't get player position
	if playerX == 0 and playerY == 0 then return end

	-- Calculate distance (simple Euclidean in map coordinates)
	local dx, dy = playerX - targetX, playerY - targetY
	local distance = math.sqrt(dx * dx + dy * dy)

	if distance <= ARRIVAL_DISTANCE then
		TurtleGuide:Debug(string.format("Arrived at destination: %.3f from target (threshold %.3f)", distance,
			ARRIVAL_DISTANCE))
		TurtleGuide:SetTurnedIn()
	end
end)
