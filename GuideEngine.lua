--[[ GuideEngine.lua -- where the guide is actually followed.

	This file used to be StatusFrame.lua and drew the compact status card. The
	concept deleted that surface, but almost none of what lived here was the
	card: UpdateStatusFrame is the scan that walks the step list, decides which
	step you are on, auto-completes the ones ClassicAPI can resolve, drives the
	waypoint and loads the next guide when one runs out. The objectives panel
	renders; this decides what there is to render.

	The use-item button that used to live here is the Active Items window now,
	in ActiveFrames.lua.

	UpdateStatusFrame keeps its name despite no status frame existing: it is
	called from twenty-eight places and renaming it would bury this change in
	churn. Worth doing on its own.
]]

local professions = {
	["mining"] = true,
	["herbalism"] = true,
	["skinning"] = true,
	["alchemy"] = true,
	["blacksmithing"] = true,
	["enchanting"] = true,
	["engineering"] = true,
	["leatherworking"] = true,
	["tailoring"] = true,
	["cooking"] = true,
	["first aid"] = true,
	["fishing"] = true,
}

local AegisPathfinder = AegisPathfinder

--- Show or hide the objectives panel. It is the addon's only window now, so
--- this is what a bare /apg does and what the minimap icon toggles.
function AegisPathfinder:ToggleObjectivePanel()
	if self.objectiveframe:IsVisible() then
		HideUIPanel(self.objectiveframe)
	else
		ShowUIPanel(self.objectiveframe)
	end
end

--[[ Which steps the addon can complete without the player ticking anything.

	ClassicAPI gives real, id-keyed quest events, so accepting, completing and
	turning in a quest, binding a hearthstone, and collecting a tagged item all
	resolve themselves. Travel steps resolve on arrival when a waypoint
	provider is active. Profession steps resolve off skill events.

	Everything else -- a note to read, a vendor to visit, a mob to grind for XP
	-- only the player can confirm. Saying which is which is the point of the
	concept's halo: it tells you when not to bother reaching for the checkbox.
]]
local AUTO_DETECTABLE = {
	ACCEPT = true, TURNIN = true, COMPLETE = true, SETHEARTH = true,
	RUN = true, FLY = true, BOAT = true, HEARTH = true, GETFLIGHTPOINT = true,
}

function AegisPathfinder:IsAutoDetectable(action, i)
	if not action then return false end
	if AUTO_DETECTABLE[action] then
		-- Travel only resolves itself if something is tracking position.
		if action == "RUN" or action == "FLY" or action == "BOAT"
			or action == "HEARTH" or action == "GETFLIGHTPOINT" then
			return self:GetWaypointProvider() ~= nil
		end
		return true
	end
	if i and self:IsSkillObjective(i) then return true end
	-- Rank steps complete on the skill cap, level gates on the level.
	if i and self:GetObjectiveTag("RANK", i) then return true end
	if i and action == "GRIND" and self:GetObjectiveTag("LV", i) then return true end
	if i and self:GetObjectiveTag("L", i) then return true end

	return false
end

--[[ What a step has to say about itself, beyond its title and note.

	The quest id, a profession step's live skill range, and any coordinates
	buried in the note. This used to paint the status card's meta row directly;
	it now returns the pieces and lets whichever surface wants them decide how
	to show them -- the objectives panel puts the id in its footer.

	Returns: qid, meta string (nil if there is nothing to say), and whether that
	string is a data-source warning rather than ordinary metadata.
]]
function AegisPathfinder:GetStepMeta(i, note)
	note = note or self:GetObjectiveTag("N", i)

	-- A guide whose data was authored for another server is the most likely
	-- cause of a waypoint pointing at nothing, and it fails silently
	-- otherwise. It outranks anything else this row could carry.
	local warning = self:GetDataSourceWarning()
	if warning then return nil, warning, true end

	local bits = {}
	local qid = self:GetObjectiveTag("QID", i)
	if qid then table.insert(bits, "QID " .. qid) end

	local profession, from, to = self:GetObjectiveTag("SKILL", i)
	if profession and to then
		local _, rank = self:GetSkillProgress(i)
		if rank then
			table.insert(bits, string.format("%s %d/%d", profession, rank, to))
		else
			table.insert(bits, string.format("%s %d-%d", profession, from or 0, to))
		end
	end

	if note then
		local _, _, x, y = string.find(note, "%(([%d%.]+)%s*,%s*([%d%.]+)%)")
		if x and y then table.insert(bits, x .. ", " .. y) end
	end

	if table.getn(bits) == 0 then return qid, nil, false end
	return qid, table.concat(bits, "  -  "), false
end

--- The step's note with any inline coordinates stripped out, since they are
--- reported separately by GetStepMeta.
function AegisPathfinder:GetStepProse(note)
	if not note or note == "" then return nil end
	local prose = self.trim(string.gsub(note, "%s*%([%d%.]+%s*,%s*[%d%.]+%)", ""))
	if prose == "" then return nil end
	return prose
end

function AegisPathfinder:SetStatusText(i)
	self.current = i
	local action, quest = self:GetObjectiveInfo(i)
	local note = self:GetObjectiveTag("N")
	-- Check for unmet prerequisites from other zones (only for ACCEPT actions)
	-- Only warn once per objective to avoid spam
	if action == "ACCEPT" and self.lastPrereqWarning ~= i then
		local unmetPrereqs = self:GetUnmetPrerequisites(i)
		for _, prereq in ipairs(unmetPrereqs) do
			-- Only warn if prerequisite is NOT in current guide (i.e., from another zone)
			if not prereq.guideStep then
				self:Print(string.format(
				"|cffff6600Warning:|r Quest requires prerequisite from another zone: |cffffd700%s|r", prereq.name))
				self.lastPrereqWarning = i
			end
		end
	end

	-- Auto-track quest for COMPLETE objectives
	self:TrackCurrentQuest()

	if self.UpdateFubarPlugin then self.UpdateFubarPlugin(quest, self.icons[action], note) end
end

-- Coalesce bursty refresh requests. UpdateStatusFrame does a full guide scan
-- (and restarts itself as it auto-completes steps), and several events
-- (QUEST_LOG_UPDATE, SPELLS_CHANGED, SKILL_LINES_CHANGED, ...) fire many times
-- in a single frame while game state syncs on login. Running the scan per
-- event spikes CPU and floods vanilla's fixed Lua string pool -> lmemPool
-- crash. Collapse a burst into a single deferred scan.
function AegisPathfinder:ScheduleStatusUpdate()
	if self.statusupdatescheduled then return end
	self.statusupdatescheduled = true
	C_Timer.After(0.1, function()
		self.statusupdatescheduled = nil
		self:UpdateStatusFrame()
	end)
end

local lastmapped, lastmappedaction, lastmappedquest
function AegisPathfinder:UpdateStatusFrame()
	--[[ Nothing to scan until a guide has been parsed. At login the guide
		loads only once every guide file has registered, a few frames and a
		half-second settle in, and events land in that gap -- SKILL_LINES_CHANGED
		always does, which is how a skill event reached the loop below with
		no step list. Whatever happened meanwhile is picked up when the guide
		loads, which scans from scratch. ]]
	if not self.actions or not self.quests or not self.turnedin then return end

	self:Debug("UpdateStatusFrame", self.current)
	local oldcurrent = self.current

	if self.updatedelay then
		local _, logi = self:GetObjectiveStatus(self.updatedelay)
		self:Debug("Delayed update", self.updatedelay, logi)
		-- Safety valve: a quest that unexpectedly stays in the log must not
		-- freeze status updates for good
		if logi and GetTime() - (self.updatedelaytime or 0) < 3 then return end
	end

	local nextstep
	self.updatedelay = nil

	for i in ipairs(self.actions) do
		local name = self.quests[i]
		if not self.turnedin[name] and not nextstep then
			local action, name, quest = self:GetObjectiveInfo(i)
			local turnedin, logi, complete, skippednotinlog = self:GetObjectiveStatus(i)

			-- A turn-in being passed over because the quest was never
			-- accepted is how the guide silently jumps ahead; say so once
			if skippednotinlog and i >= (oldcurrent or 1) and not self.turninskipwarned[self.quests[i]] then
				self.turninskipwarned[self.quests[i]] = true
				self:Print(string.format("|cffff9900Skipping turn-in %q - quest is not in your log.|r", name))
			end
			local note, useitem, optional, prereq = self:GetObjectiveTag("N", i),
				self:GetObjectiveTag("U", i), self:GetObjectiveTag("O", i), self:GetObjectiveTag("PRE", i)
			local lootitem, lootqty = self:GetLootRequirement(i)
			self:Debug("UpdateStatusFrame", i, action, name, note, logi, complete, turnedin, quest, useitem, optional,
				lootitem, lootqty, lootitem and C_Item.GetItemCount(tonumber(lootitem)) or 0)
			local level = tonumber((self:GetObjectiveTag("LV", i)))
			local needlevel = level and level > UnitLevel("player")
			local hasuseitem = useitem and self:FindBagSlot(useitem)
			local haslootitem = lootitem and C_Item.GetItemCount(tonumber(lootitem)) >= lootqty
			local prereqturnedin = false
			if prereq then
				if self.turnedin[prereq] then
					prereqturnedin = true
				else
					for k, v in pairs(self.turnedin) do
						if v and string.sub(k, 1, string.len(prereq) + 1) == prereq .. "@" then
							prereqturnedin = true
							break
						end
					end
				end
			end

			-- Test for completed objectives and mark them done
			if action == "SETHEARTH" and self.db.char.hearth == name then return self:SetTurnedIn(i, true) end

			local zonetext, subzonetext, subzonetag = GetZoneText(), GetSubZoneText(), self:GetObjectiveTag("SZ")
			if (action == "RUN" or action == "FLY" or action == "HEARTH" or action == "BOAT") and (subzonetext == name or subzonetext == subzonetag or zonetext == name or zonetext == subzonetag) then return
				self:SetTurnedIn(i, true) end

			if action == "KILL" or action == "NOTE" or action == "COMPLETE" or action == "BUY" then
				if haslootitem then return self:SetTurnedIn(i, true) end

				if action == "KILL" or action == "NOTE" then
					local quest, questtext = self:GetObjectiveTag("Q", i), self:GetObjectiveTag("QO", i)
					if quest and questtext then
						local qi = self:GetQuestLogIndexByName(quest)
						for lbi = 1, GetNumQuestLeaderBoards(qi) do
							self:Debug(quest, questtext, qi, GetQuestLogLeaderBoard(lbi, qi))
							if GetQuestLogLeaderBoard(lbi, qi) == questtext then return self:SetTurnedIn(i, true) end
						end
					end
				end
			end

			--[[ Profession steps complete on the numbers the client reports,
				whatever their action: a rank step when the skill cap reaches
				it -- training, a secondary profession's tome and its Artisan
				quest all raise the cap -- and a skill step when the skill
				does. A step reached with the number already there is done. ]]
			local rankProf, rankCap = self:GetObjectiveTag("RANK", i)
			if rankProf and rankCap and self.GetSkillCap then
				local cap = self:GetSkillCap(rankProf)
				if cap and cap >= rankCap then return self:SetTurnedIn(i, true) end
			end
			local skillProf, _, skillTo = self:GetObjectiveTag("SKILL", i)
			if skillProf and skillTo and self.GetSkillRank then
				local rank = self:GetSkillRank(skillProf)
				if rank and rank >= skillTo then return self:SetTurnedIn(i, true) end
			end

			if action == "TRAIN" and not rankProf and self:IsTrainingCompleted(name) then
				return self:SetTurnedIn(i, true)
			end

			if action == "PET" and self.db.char.petskills[name] then return self:SetTurnedIn(i, true) end

			if action == "ACCEPT" or action == "COMPLETE" or action == "TURNIN" or action == "RUN" then
				local qid = self:GetObjectiveTag("QID", i)
				local cleanQuest = string.gsub(name, AegisPathfinder.Locale.PART_GSUB, "")
				if (qid and self:IsQuestCompletedOnServer(qid)) or (not qid and self.db.char.completedquests[cleanQuest]) then
					return self:SetTurnedIn(i, true)
				end
			end

			local incomplete
			if turnedin then
				incomplete = false
			elseif action == "ACCEPT" then
				incomplete = (not optional or hasuseitem or haslootitem or prereqturnedin) and not logi
			elseif action == "TURNIN" then
				incomplete = not optional or logi
			elseif action == "COMPLETE" then
				incomplete = not complete and (not optional or logi)
			elseif action == "NOTE" or action == "KILL" then
				incomplete = not optional or haslootitem
			elseif action == "GRIND" then
				-- A level gate waits on the level; a gathering step on the
				-- skill, which is not there yet or it would have completed.
				incomplete = needlevel or (skillProf and skillTo and true) or false
			elseif action == "TRAIN" then
				incomplete = rankProf and true or not self:IsTrainingCompleted(name)
			else
				incomplete = not logi
			end

			if incomplete then nextstep = i end

			if action == "COMPLETE" and logi and self.db.char.trackquests then
				local j = i
				repeat
					action = self:GetObjectiveInfo(j)
					turnedin, logi, complete = self:GetObjectiveStatus(j)
					if action == "COMPLETE" and logi and not complete then
						if not IsQuestWatched(logi) then AddQuestWatch(logi) end
					elseif action == "COMPLETE" and logi then
						RemoveQuestWatch(logi)
					end
					j = j + 1
				until action ~= "COMPLETE"
			end
		end
	end
	QuestLog_Update()
	QuestWatch_Update()

	-- Check if we're on a branch and it's complete
	if not nextstep and self.db.char.isbranching then
		self:Print("Branch guide complete! Returning to main route.")
		self:ReturnFromBranch()
		return
	end

	if not nextstep and self:LoadNextGuide() then return self:UpdateStatusFrame() end

	-- Chain resolved (found work, or LoadNextGuide stopped): clear the guard.
	self.autoadvancecount = nil

	-- The shopping list, and Aegis: Exchange if it was sent there, follow the
	-- step -- including off the end of the guide, when there is nothing left.
	if not nextstep then
		if self.RefreshShoppingList then self:RefreshShoppingList() end
		if self.RefreshActiveFrames then self:RefreshActiveFrames() end
		return
	end

	self:SetStatusText(nextstep)
	self.current = nextstep
	if self.RefreshShoppingList then self:RefreshShoppingList() end
	-- The Active Items and Active Targets windows follow the step too.
	if self.RefreshActiveFrames then self:RefreshActiveFrames() end
	local action, quest, fullquest = self:GetObjectiveInfo(nextstep)
	local turnedin, logi, complete = self:GetObjectiveStatus(nextstep)
	local note, useitem, optional, qid = self:GetObjectiveTag("N", nextstep), self:GetObjectiveTag("U", nextstep),
		self:GetObjectiveTag("O", nextstep), self:GetObjectiveTag("QID", nextstep)
	local zonename = self:GetObjectiveTag("Z", nextstep) or self.zonename
	self:Debug(string.format("Progressing to objective \"%s %s\"", action, quest))

	-- Mapping / Navigation
	local shouldUpdateWaypoint = (lastmappedquest ~= fullquest or lastmappedaction ~= action) or self.waypointForced
	if self:GetWaypointProvider() and shouldUpdateWaypoint then
		lastmappedaction, lastmappedquest = action, fullquest
		lastmapped = quest
		self.waypointForced = nil
		self:ParseAndMapCoords(qid, action, note, quest, zonename, self:GetObjectiveTag("NPC", nextstep))
	end

	self:UpdateOHPanel()
	self:UpdateNavCallout()

	-- An open quest/gossip window fires no further events once the step
	-- advances past the one that opened it; rescan it for the new step
	if self.current ~= oldcurrent then
		self:RedriveQuestAutomation()
	end
end

