--[[ Automation.lua -- what the options' Automation page does for you at a
	flight master and at a vendor; the quest automation is QuestTracker.lua's.

	  * Travel: open the flight master's map on a step that says to fly
	    somewhere, and that flight is taken. "Fly to Orgrimmar" is the town;
	    "Fly to Westfall" the zone, taken only when the zone has one flight
	    path you know, never a guess between two.
	  * Buying: open a vendor on a step that says to buy something -- its |L|
	    item and how many -- and as many as you still need are bought, if the
	    vendor sells it and you can pay.
	  * A "Sell greys" button on the vendor window, and selling greys by
	    themselves as it opens.
	  * Repairing with your own money as it opens. 1.12 has no guild bank, so
	    there is no repairing with the guild's.

	Each is a switch on the Automation page. Holding Shift as the window
	opens does none of it, as Shift does for quests.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme
local L = AegisPathfinder.Locale

local Auto = {}
AegisPathfinder.Automation = Auto

--- Copper as "1g 23s 4c", leading zero amounts left out.
function Auto.Money(copper)
	copper = math.floor(copper or 0)
	local g, s, c = math.floor(copper / 10000), math.floor(math.mod(copper, 10000) / 100), math.mod(copper, 100)
	local out = {}
	if g > 0 then table.insert(out, g .. "g") end
	if g > 0 or s > 0 then table.insert(out, s .. "s") end
	table.insert(out, c .. "c")
	return table.concat(out, " ")
end

--[[ Travel --------------------------------------------------------------------- ]]

--- Where a fly step goes: "Fly to The Crossroads (Part 2)" is "crossroads".
function Auto.Destination(name)
	name = string.gsub(name or "", L.PART_GSUB, "")
	name = string.gsub(string.lower(name), "^fly to ", "")
	name = string.gsub(name, "^the ", "")
	return (string.gsub(name, "%s+$", ""))
end

-- Two names for one place: the same, or one the start of the other, as the
-- flight map shortens them ("Redridge" for Redridge Mountains).
local function Same(a, b)
	if a == b then return true end
	if string.len(a) < 4 or string.len(b) < 4 then return false end
	return string.find(a, b, 1, true) == 1 or string.find(b, a, 1, true) == 1
end

--- How a flight path ("Lakeshire, Redridge") answers a destination: 2 for
--- its town, 1 for its zone, 0 for neither.
function Auto.Match(node, dest)
	local lower = string.lower(node or "")
	local _, _, town, zone = string.find(lower, "^(.-),%s*(.+)$")
	town = string.gsub(town or lower, "^the ", "")
	zone = string.gsub(zone or "", "^the ", "")
	if dest == "" then return 0 end
	if Same(town, dest) then return 2 end
	if zone ~= "" and Same(zone, dest) then return 1 end
	return 0
end

--- On the flight master's map: take the step's flight, if it is a fly step
--- and its place is one flight path you can reach. Returns the node taken.
function Auto:TakeFlight()
	local db = AegisPathfinder.db.char
	if not db.autofly or IsShiftKeyDown() then return end
	local action, name = AegisPathfinder:GetObjectiveInfo()
	if action ~= "FLY" or not name then return end
	local dest = Auto.Destination(name)
	local towns, zones = {}, {}
	for i = 1, NumTaxiNodes() do
		if TaxiNodeGetType(i) == "REACHABLE" then
			local m = Auto.Match(TaxiNodeName(i), dest)
			if m == 2 then table.insert(towns, i) elseif m == 1 then table.insert(zones, i) end
		end
	end
	local pick = towns[1] or (table.getn(zones) == 1 and zones[1])
	if not pick then
		if table.getn(zones) > 1 then
			AegisPathfinder:Print("More than one flight path goes to " .. name .. ": pick the one you want.")
		end
		return
	end
	local node = TaxiNodeName(pick)
	AegisPathfinder:Print("Flying to " .. node .. ".")
	TakeTaxiNode(pick)
	return node
end

--[[ Buying ----------------------------------------------------------------------- ]]

--- At a vendor: buy what a buy step names, as many as you still need. Returns
--- how many were bought.
function Auto:BuyStepItems()
	if AegisPathfinder.db.char.autobuy == false or IsShiftKeyDown() then return end
	local action = AegisPathfinder:GetObjectiveInfo()
	if action ~= "BUY" then return end
	local item, qty = AegisPathfinder:GetLootRequirement()
	if not item then return end
	local need = (tonumber(qty) or 1) - (C_Item.GetItemCount(item) or 0)
	if need <= 0 then return end
	for i = 1, GetMerchantNumItems() do
		local _, _, id = string.find(GetMerchantItemLink(i) or "", "item:(%d+)")
		if tonumber(id) == item then
			local itemName, _, price, per, available = GetMerchantItemInfo(i)
			per = math.max(per or 1, 1)
			-- How many purchases: enough, no more than the vendor has (-1 is
			-- no limit) and no more than you can pay for.
			local buys = math.ceil(need / per)
			if available and available >= 0 then buys = math.min(buys, available) end
			if price and price > 0 then buys = math.min(buys, math.floor(GetMoney() / price)) end
			if buys <= 0 then
				AegisPathfinder:Print("Not enough money to buy " .. (itemName or "it") .. " for the guide.")
				return 0
			end
			-- A single item is bought in one go, split as the client's stack
			-- split buys it; one sold in bundles a bundle at a time.
			if per == 1 then
				BuyMerchantItem(i, buys)
			else
				for _ = 1, buys do BuyMerchantItem(i) end
			end
			AegisPathfinder:Print(string.format("Bought %d %s for the guide.", buys * per, itemName or "items"))
			return buys * per
		end
	end
end

--[[ Selling greys ---------------------------------------------------------------- ]]

--- The grey items in your bags, as { bag, slot } pairs: by the link's colour,
--- which is the stock API.
function Auto.Greys()
	local out = {}
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) or 0 do
			local link = GetContainerItemLink(bag, slot)
			if link and string.find(link, "|cff9d9d9d", 1, true) then table.insert(out, { bag, slot }) end
		end
	end
	return out
end

--- At a vendor: sell every grey, and say how many and, a moment later, for
--- how much. `quiet`: nothing said when there are none. Returns how many.
function Auto:SellGreys(quiet)
	if not (MerchantFrame and MerchantFrame:IsVisible()) then return 0 end
	local greys = Auto.Greys()
	local n = table.getn(greys)
	if n == 0 then
		if not quiet then AegisPathfinder:Print("No grey items to sell.") end
		return 0
	end
	local before = GetMoney()
	for _, g in ipairs(greys) do UseContainerItem(g[1], g[2]) end
	local function report()
		local gained = GetMoney() - before
		AegisPathfinder:Print(string.format("Sold %d grey item%s%s.", n, n == 1 and "" or "s",
			gained > 0 and (" for " .. Auto.Money(gained)) or ""))
	end
	-- The money arrives with the server's answer, not here.
	if C_Timer and C_Timer.After then C_Timer.After(1, report) else report() end
	return n
end

--- The "Sell greys" button, on the vendor window when it is switched on.
function Auto:PlaceButton()
	local b = self.button
	if not b and MerchantFrame then
		b = Theme:PanelButton(MerchantFrame, "Sell greys", 92, 20)
		b:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -44, -44)
		b:SetFrameLevel(MerchantFrame:GetFrameLevel() + 5)
		b:SetScript("OnClick", function() Auto:SellGreys() end)
		self.button = b
	end
	if not b then return end
	if AegisPathfinder.db.char.sellbutton ~= false then b:Show() else b:Hide() end
end

--[[ Repairing ---------------------------------------------------------------------- ]]

--- At a vendor who repairs: everything, with your own money, when the
--- Automation page says to. Returns what it cost.
function Auto:Repair()
	if AegisPathfinder.db.char.autorepair ~= "own" or IsShiftKeyDown() then return end
	if not (CanMerchantRepair and CanMerchantRepair()) then return end
	local cost = GetRepairAllCost()
	if not cost or cost <= 0 then return end
	if GetMoney() < cost then
		AegisPathfinder:Print("Not enough money to repair: it costs " .. Auto.Money(cost) .. ".")
		return
	end
	RepairAllItems()
	AegisPathfinder:Print("Repaired for " .. Auto.Money(cost) .. ".")
	return cost
end

--- A vendor's window opening: repair, sell, then buy, with the money each
--- leaves for the next.
function Auto:OnMerchant()
	self:PlaceButton()
	if IsShiftKeyDown() then return end
	self:Repair()
	if AegisPathfinder.db.char.autosell then self:SellGreys(true) end
	self:BuyStepItems()
end

local events = CreateFrame("Frame")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("TAXIMAP_OPENED")
events:SetScript("OnEvent", function()
	-- Nothing before the saved settings are there.
	if not AegisPathfinder.db then return end
	if event == "TAXIMAP_OPENED" then
		Auto:TakeFlight()
	elseif event == "MERCHANT_SHOW" then
		Auto:OnMerchant()
	end
end)
Auto.events = events
