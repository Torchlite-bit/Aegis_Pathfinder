local ICONSIZE, CHECKSIZE, GAP = 16, 16, 8
local NAVBTNSIZE = 14
local FIXEDWIDTH = ICONSIZE + CHECKSIZE + GAP * 4 - 4 + NAVBTNSIZE * 2 + 6 -- +prev/next buttons

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
local ww = WidgetWarlock

local f = CreateFrame("Button", nil, UIParent)
AegisPathfinder.statusframe = f
f:SetPoint("BOTTOMRIGHT", QuestWatchFrame, "TOPRIGHT", -60, -15)
f:SetHeight(24)
f:SetFrameStrata("LOW")
f:EnableMouse(true)
f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
f:SetBackdrop(ww.TooltipBorderBG)
f:SetBackdropColor(0.09, 0.09, 0.19, 0.5)
f:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.5)

local check = ww.SummonCheckBox(CHECKSIZE, f, "LEFT", GAP, 0)

-- Previous objective button
local prevBtn = CreateFrame("Button", nil, f)
prevBtn:SetWidth(14)
prevBtn:SetHeight(14)
prevBtn:SetPoint("LEFT", check, "RIGHT", 2, 0)
prevBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
prevBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
prevBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
prevBtn:SetScript("OnClick", function() AegisPathfinder:GoToPreviousObjective() end)
prevBtn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText("Previous objective")
end)
prevBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local icon = ww.SummonTexture(f, "ARTWORK", ICONSIZE, ICONSIZE, nil, "LEFT", prevBtn, "RIGHT", GAP - 4, 0)
local text = ww.SummonFontString(f, "OVERLAY", "GameFontNormalSmall", nil, "RIGHT", -GAP - 4 - 18, 0)
text:SetPoint("LEFT", icon, "RIGHT", GAP - 4, 0)

-- Next objective button
local nextBtn = CreateFrame("Button", nil, f)
nextBtn:SetWidth(14)
nextBtn:SetHeight(14)
nextBtn:SetPoint("RIGHT", f, "RIGHT", -GAP, 0)
nextBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
nextBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
nextBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
nextBtn:SetScript("OnClick", function() AegisPathfinder:SkipToNextObjective() end)
nextBtn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText("Skip to next objective")
end)
nextBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Return from branch button (only visible when branching)
local returnBtn = CreateFrame("Button", nil, f)
returnBtn:SetWidth(50)
returnBtn:SetHeight(14)
returnBtn:SetPoint("LEFT", f, "RIGHT", 4, 0)
returnBtn:SetBackdrop({
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 8,
	edgeSize = 8,
	insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
returnBtn:SetBackdropColor(0, 0.4, 0, 0.8)
returnBtn:SetBackdropBorderColor(0, 0.8, 0, 0.8)
local returnText = returnBtn:CreateFontString(nil, "OVERLAY")
returnText:SetFontObject(GameFontNormalSmall)
returnText:SetPoint("CENTER", 0, 0)
returnText:SetText("|cff00ff00<< Main|r")
returnText:SetTextColor(0, 1, 0)
returnBtn:SetScript("OnClick", function() AegisPathfinder:ReturnFromBranch() end)
returnBtn:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	local savedGuide = AegisPathfinder.db.char.branchsavedguide or "Unknown"
	GameTooltip:SetText("Return to main route:\n" .. savedGuide, nil, nil, nil, nil, true)
end)
returnBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
returnBtn:Hide()
AegisPathfinder.branchReturnBtn = returnBtn

local item = CreateFrame("Button", "AegisPathfinderItemButton", UIParent, "ItemButtonTemplate")
item:SetFrameStrata("LOW")
item:SetHeight(36)
item:SetWidth(36)
item:SetPoint("BOTTOMRIGHT", QuestWatchFrame, "TOPRIGHT", -62, 10)
item:RegisterForClicks("LeftButtonUp", "RightButtonUp")
item:SetScript("OnEnter", function()
	if not item.uitem then return end
	GameTooltip:SetOwner(item, "ANCHOR_LEFT")
	local bag, slot = AegisPathfinder:FindBagSlot(item.uitem)
	if bag then
		GameTooltip:SetBagItem(bag, slot)
	else
		GameTooltip:SetItemByID(tonumber(item.uitem))
	end
	GameTooltip:Show()
end)
item:SetScript("OnLeave", GameTooltip_Hide)
item:Hide()

local f2 = CreateFrame("Frame", nil, UIParent)
local f2anchor = "RIGHT"
f2:SetHeight(32)
f2:SetWidth(100)
local text2 = ww.SummonFontString(f2, "OVERLAY", "GameFontNormalSmall", nil, "RIGHT", -GAP - 4, 0)
local icon2 = ww.SummonTexture(f2, "ARTWORK", ICONSIZE, ICONSIZE, nil, "RIGHT", text2, "LEFT", -GAP + 4, 0)
local check2 = ww.SummonCheckBox(CHECKSIZE, f2, "RIGHT", icon2, "LEFT", -GAP + 4, 0)
check2:SetChecked(true)
f2:Hide()


local elapsed, oldsize, newsize
f2:SetScript("OnUpdate", function()
	local self, el = this, arg1
	elapsed = elapsed + el
	if elapsed > 1 then
		self:Hide()
		icon:SetAlpha(1)
		text:SetAlpha(1)
		f:SetWidth(newsize)
	else
		self:SetPoint(f2anchor, f, f2anchor, 0, elapsed * 40)
		self:SetAlpha(1 - elapsed)
		text:SetAlpha(elapsed)
		icon:SetAlpha(elapsed)
		f:SetWidth(oldsize + (newsize - oldsize) * elapsed)
	end
end)

function AegisPathfinder:HideStatusFrameChildren()
	if AegisPathfinder.objectiveframe:IsVisible() then HideUIPanel(AegisPathfinder.objectiveframe) end
	if AegisPathfinder.optionsframe:IsVisible() then HideUIPanel(AegisPathfinder.optionsframe) end
	if AegisPathfinder.guidelistframe:IsVisible() then HideUIPanel(AegisPathfinder.guidelistframe) end
end

function AegisPathfinder:PositionStatusFrame()
	if self.db.profile.statusframepoint then
		f:ClearAllPoints()
		f:SetPoint(self.db.profile.statusframepoint, self.db.profile.statusframex, self.db.profile.statusframey)
	end

	if self.db.profile.itemframepoint then
		item:ClearAllPoints()
		item:SetPoint(self.db.profile.itemframepoint, self.db.profile.itemframex, self.db.profile.itemframey)
	end
end

function AegisPathfinder:SetStatusText(i)
	self.current = i
	local action, quest = self:GetObjectiveInfo(i)
	local note = self:GetObjectiveTag("N")
	local totalSteps = self.actions and table.getn(self.actions) or 0
	local stepNum = string.format("[%d/%d] ", i, totalSteps)
	local branchIndicator = self.db.char.isbranching and "|cff00ff00*|r " or ""
	local newtext = branchIndicator .. stepNum .. (quest or "???") .. (note and " [?]" or "")

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

	-- Show/hide branch return button
	if self.branchReturnBtn then
		if self.db.char.isbranching then
			self.branchReturnBtn:Show()
		else
			self.branchReturnBtn:Hide()
		end
	end

	-- Auto-track quest for COMPLETE objectives
	self:TrackCurrentQuest()

	if text:GetText() ~= newtext or icon:GetTexture() ~= self.icons[action] then
		oldsize = f:GetWidth()
		icon:SetAlpha(0)
		text:SetAlpha(0)
		elapsed = 0
		f2:SetWidth(f:GetWidth())
		f2anchor = self.select(3, self.GetQuadrant(f))
		f2:ClearAllPoints()
		f2:SetPoint(f2anchor, f, f2anchor, 0, 0)
		f2:SetAlpha(1)
		icon2:SetTexture(icon:GetTexture())
		icon2:SetTexCoord(4 / 48, 44 / 48, 4 / 48, 44 / 48)
		text2:SetText(text:GetText())
		f2:Show()
	end

	icon:SetTexture(self.icons[action])
	if action ~= "ACCEPT" and action ~= "TURNIN" then icon:SetTexCoord(4 / 48, 44 / 48, 4 / 48, 44 / 48) end
	if self:GetObjectiveTag("T") then f:SetBackdropColor(0.09, 0.5, 0.19, 0.5) else f:SetBackdropColor(0.09, 0.09, 0.19,
			0.5) end
	text:SetText(newtext)
	check:SetChecked(false)
	check:SetButtonState("NORMAL")
	if self.db.char.currentguide == "No Guide" then check:Disable() else check:Enable() end
	if i == 1 then f:SetWidth(FIXEDWIDTH + text:GetWidth()) end
	newsize = FIXEDWIDTH + text:GetWidth()

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

local lastmapped, lastmappedaction, lastmappedquest, tex, uitem
function AegisPathfinder:UpdateStatusFrame()
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

			if action == "TRAIN" and self:IsTrainingCompleted(name) then return self:SetTurnedIn(i, true) end

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
				incomplete = needlevel
			elseif action == "TRAIN" then
				incomplete = not self:IsTrainingCompleted(name)
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

	if not nextstep then return end

	self:SetStatusText(nextstep)
	self.current = nextstep
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
		self:ParseAndMapCoords(qid, action, note, quest, zonename)
	end


	local newtext = (quest or "???") .. (note and " [?]" or "")

	if text:GetText() ~= newtext or icon:GetTexture() ~= self.icons[action] then
		oldsize = f:GetWidth()
		icon:SetAlpha(0)
		text:SetAlpha(0)
		elapsed = 0
		f2:SetWidth(f:GetWidth())
		f2anchor = self.select(3, self.GetQuadrant(f))
		f2:ClearAllPoints()
		f2:SetPoint(f2anchor, f, f2anchor, 0, 0)
		f2:SetAlpha(1)
		icon2:SetTexture(icon:GetTexture())
		text2:SetText(text:GetText())
		f2:Show()
	end

	icon:SetTexture(self.icons[action])
	text:SetText(newtext)
	check:SetChecked(false)
	if not f2:IsVisible() then f:SetWidth(FIXEDWIDTH + text:GetWidth()) end
	newsize = FIXEDWIDTH + text:GetWidth()

	tex = useitem and C_Item.GetItemIconByID(tonumber(useitem))
	uitem = useitem
	item.uitem = tex and uitem or nil
	if UnitAffectingCombat("player") then
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
	else
		self:PLAYER_REGEN_ENABLED()
	end

	self:UpdateOHPanel()

	-- An open quest/gossip window fires no further events once the step
	-- advances past the one that opened it; rescan it for the new step
	if self.current ~= oldcurrent then
		self:RedriveQuestAutomation()
	end
end

function AegisPathfinder:PLAYER_REGEN_ENABLED()
	if tex then
		SetItemButtonTexture(item, tex)
		item:Show()
		tex = nil
	else
		item:Hide()
	end
	if self:IsEventRegistered("PLAYER_REGEN_ENABLED") then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end
end

f:SetScript("OnClick", function()
	local self, btn = this, arg1
	if AegisPathfinder.db.char.currentguide == "No Guide" then
		AegisPathfinder.guidelistframe:Show()
	else
		if btn == "LeftButton" then
			-- Left-click: Show/hide objectives panel
			if AegisPathfinder.objectiveframe:IsVisible() then
				HideUIPanel(AegisPathfinder.objectiveframe)
			else
				local quad, vhalf, hhalf = AegisPathfinder.GetQuadrant(self)
				local anchpoint = (vhalf == "TOP" and "BOTTOM" or "TOP") .. hhalf
				AegisPathfinder.objectiveframe:ClearAllPoints()
				AegisPathfinder.objectiveframe:SetPoint(quad, self, anchpoint)
				ShowUIPanel(AegisPathfinder.objectiveframe)
			end
		else
			-- Right-click: Show/hide quest log
			if QuestLogFrame:IsVisible() or (EQL3_QuestLogFrame and EQL3_QuestLogFrame:IsVisible()) then
				HideUIPanel(QuestLogFrame)
				HideUIPanel(EQL3_QuestLogFrame)
			else
				local i = AegisPathfinder:GetQuestLogIndexByName()
				if i then SelectQuestLogEntry(i) end
				ShowUIPanel(QuestLogFrame)
			end
		end
	end
end)


check:SetScript("OnClick", function(self, btn) AegisPathfinder:SetTurnedIn() end)


item:SetScript("OnClick", function()
	if AegisPathfinder:GetObjectiveInfo() == "USE" then AegisPathfinder:SetTurnedIn() end
	if item.uitem then
		local bag, slot = AegisPathfinder:FindBagSlot(item.uitem)
		if bag and slot then UseContainerItem(bag, slot) else AegisPathfinder:Print("Item not found") end
	end
end)


local function ShowTooltip()
	local self = this
	local tip = AegisPathfinder:GetObjectiveTag("N")
	local quad, vhalf, hhalf = AegisPathfinder.GetQuadrant(self)
	local anchpoint = "ANCHOR_TOP" .. hhalf
	AegisPathfinder:Debug("Setting tooltip anchor", anchpoint)
	GameTooltip:SetOwner(self, anchpoint)

	-- Show branch status if branching
	if AegisPathfinder.db.char.isbranching then
		GameTooltip:AddLine("|cff00ff00Currently branching|r", 1, 1, 1)
		GameTooltip:AddLine("Main route: " .. (AegisPathfinder.db.char.branchsavedguide or "Unknown"), 0.7, 0.7, 0.7)
		GameTooltip:AddLine(" ", 1, 1, 1)
	end

	if tip and tip ~= "" then
		GameTooltip:AddLine(tostring(tip), 1, 1, 1, true)
	end

	GameTooltip:Show()
end

local function HideTooltip()
	if GameTooltip:IsOwned(this) then
		GameTooltip:Hide()
	end
end

f:SetScript("OnLeave", HideTooltip)
f:SetScript("OnEnter", ShowTooltip)

f:RegisterForDrag("LeftButton")
f:SetMovable(true)
f:SetClampedToScreen(true)
f:SetScript("OnDragStart", function()
	local frame = this
	AegisPathfinder:HideStatusFrameChildren()
	GameTooltip:Hide()
	frame:StartMoving()
end)
f:SetScript("OnDragStop", function()
	local frame = this
	frame:StopMovingOrSizing()
	local _
	AegisPathfinder.db.profile.statusframepoint, _, _, AegisPathfinder.db.profile.statusframex, AegisPathfinder.db.profile.statusframey =
	frame:GetPoint()
	frame:ClearAllPoints()
	frame:SetPoint(AegisPathfinder.db.profile.statusframepoint, AegisPathfinder.db.profile.statusframex,
		AegisPathfinder.db.profile.statusframey)
	ShowTooltip(frame)
end)


item:RegisterForDrag("LeftButton")
item:SetMovable(true)
item:SetClampedToScreen(true)
item:SetScript("OnDragStart", function()
	local frame = this
	frame:StartMoving()
end)
item:SetScript("OnDragStop", function()
	local frame = this
	frame:StopMovingOrSizing()
	local _
	AegisPathfinder.db.profile.itemframepoint, _, _, AegisPathfinder.db.profile.itemframex, AegisPathfinder.db.profile.itemframey =
	frame:GetPoint()
end)

f:SetScript("OnHide", function()
	AegisPathfinder:HideStatusFrameChildren()
end)
