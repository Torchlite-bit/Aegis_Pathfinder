local AegisPathfinder = AegisPathfinder
local ww = WidgetWarlock
local Theme = AegisPathfinder.Theme

local title

local NUMROWS, COLWIDTH = 16, 210
local ROWHEIGHT = 305 / NUMROWS
local TOTALROWS = NUMROWS * 3

local offset = 0
local rows = {}
local displayList = {}
local levelFilterOn = false

local function SortGuidesByLevel(a, b)
    local aMin, aMax = AegisPathfinder:ParseGuideLevelRange(a)
    local bMin, bMax = AegisPathfinder:ParseGuideLevelRange(b)

    if not aMin and not bMin then
        return a < b
    elseif not aMin then
        return false
    elseif not bMin then
        return true
    end

    if aMin ~= bMin then
        return aMin < bMin
    elseif aMax ~= bMax then
        return aMax < bMax
    else
        return a < b
    end
end

local function HideTooltip()
    if GameTooltip:IsOwned(this) then
        GameTooltip:Hide()
    end
end

local function ShowTooltip()
    local f = this
    GameTooltip:SetOwner(f, "ANCHOR_RIGHT")

    local lines = {}
    if f.guide then
        table.insert(lines, "|cffffd100" .. f.guide .. "|r")
        table.insert(lines, "")
    end
    table.insert(lines, "Left-click: Load this guide")
    table.insert(lines, "Right-click: Branch to this guide")

    if f.guide and AegisPathfinder.db.char.completion[f.guide] == 1 then
        table.insert(lines, "Shift-click: Reset progress")
    end

    if f.guide and AegisPathfinder.db.char.isbranching and AegisPathfinder.db.char.branchsavedguide == f.guide then
        table.insert(lines, "|cff00ff00(Your saved main route)|r")
    end

    GameTooltip:SetText(table.concat(lines, "\n"), nil, nil, nil, nil, true)
end

local function OnClick()
    local f = this
    local btn = arg1
    if IsShiftKeyDown() then
        AegisPathfinder.db.char.completion[f.guide] = nil
        AegisPathfinder.db.char.turnins[f.guide] = {}
        AegisPathfinder:UpdateGuideListPanel()
        GameTooltip:Hide()
    elseif btn == "RightButton" then
        local text = f.guide
        if text then
            AegisPathfinder:BranchToGuide(text)
            AegisPathfinder:UpdateGuideListPanel()
        end
    else
        local text = f.guide
        if not text then
            f:SetChecked(false)
        else
            local isRXP = string.find(text, "^RXP/")
            local isRXPHC = string.find(text, "^RXP_Hardcore/")
            local currentPack = AegisPathfinder.db.char.routepack

            -- If manually picking an RXP guide, ensure an RXP-based route pack is active
            -- so that auto-navigation continues with compatible guides
            if isRXPHC and currentPack ~= "RXP Hardcore" then
                AegisPathfinder:SelectRoutePack("RXP Hardcore")
            elseif isRXP and currentPack ~= "RestedXP" and currentPack ~= "Kamisayo Speedrun" then
                AegisPathfinder:SelectRoutePack("RestedXP")
            end

            AegisPathfinder:LoadGuide(text)
            AegisPathfinder:UpdateStatusFrame()
            AegisPathfinder:UpdateGuideListPanel()
        end
    end
end

-- Parented to UIParent, not the status card: the card is hidden by default and
-- a child of a hidden frame cannot be shown. It is still anchored to the card,
-- which keeps a position whether or not it is drawn.
local frame = CreateFrame("Frame", "AegisPathfinderGuideList", UIParent)
AegisPathfinder.guidelistframe = frame
frame:SetFrameStrata("DIALOG")
frame:SetWidth(660)
frame:SetHeight(320 + 28)
frame:SetPoint("TOPRIGHT", AegisPathfinder.statusframe, "BOTTOMRIGHT")
Theme:Panel(frame, "panel")
frame:Hide()

local closebutton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closebutton:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
frame.closebutton = closebutton

local title = ww.SummonFontString(frame, nil, "SubZoneTextFont", nil, "BOTTOM", frame, "TOP")
local fontname, fontheight, fontflags = title:GetFont()
title:SetFont(fontname, 18, fontflags)
title:SetText("Guide List")
frame.title = title

-- Level filter checkbox
local filterCheck = ww.SummonCheckBox(18, frame, "TOPLEFT", 15, -6)
local filterLabel = ww.SummonFontString(filterCheck, "OVERLAY", "GameFontNormalSmall", "Level filter (+/-5)", "LEFT",
    filterCheck, "RIGHT", 2, 0)
filterCheck:SetScript("OnClick", function()
    levelFilterOn = not levelFilterOn
    filterCheck:SetChecked(levelFilterOn)
    offset = 0
    AegisPathfinder:UpdateGuideListPanel()
end)

--[[ Category tabs.

    The concept uses a single-select tab bar here rather than the five
    independent checkboxes this panel had. Single-select on its own would lose
    the ability to see several categories at once, so ALL leads the bar and is
    the default -- the concept's layout, none of the old capability removed.
]]
local CATEGORY_TABS = {
    { key = "all",        label = "All" },
    { key = "turtle",     label = "Custom" },
    { key = "optimized",  label = "Optimized" },
    { key = "rxp",        label = "RestedXP" },
    { key = "rxp_hc",     label = "Hardcore" },
    { key = "zone",       label = "Zones" },
    { key = "profession", label = "Professions" },
}

local categoryTabs = {}
local TAB_W, TAB_H, TAB_GAP = 84, 22, 2

for idx, def in ipairs(CATEGORY_TABS) do
    local tab = Theme:Tab(frame, def.label, TAB_W, TAB_H)
    tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 12 + (idx - 1) * (TAB_W + TAB_GAP), -28)
    tab.categoryKey = def.key

    local key = def.key
    tab:SetScript("OnClick", function()
        AegisPathfinder.db.char.guidecategory = key
        offset = 0
        AegisPathfinder:UpdateGuideListPanel()
    end)

    table.insert(categoryTabs, tab)
end

AegisPathfinder.guidecategorytabs = categoryTabs

-- Return to Main button
local returnBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
returnBtn:SetWidth(120)
returnBtn:SetHeight(20)
returnBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -6)
returnBtn:SetText("Return to Main")
returnBtn:SetScript("OnClick", function()
    AegisPathfinder:ReturnFromBranch()
    AegisPathfinder:UpdateGuideListPanel()
end)
frame.returnBtn = returnBtn

-- Fill in the frame with guide CheckButtons (3-column layout)
for i = 1, TOTALROWS do
    local anchor, point = rows[i - 1], "BOTTOMLEFT"
    if i == 1 then
        anchor, point = frame, "TOPLEFT"
    elseif i == (NUMROWS + 1) then
        anchor, point = rows[1], "TOPRIGHT"
    elseif i == (NUMROWS * 2 + 1) then
        anchor, point = rows[NUMROWS + 1], "TOPRIGHT"
    end

    local row = CreateFrame("CheckButton", nil, frame)
    if i == 1 then
        row:SetPoint("TOPLEFT", anchor, point, 15, -30)
    else
        row:SetPoint("TOPLEFT", anchor, point)
    end
    row:SetHeight(ROWHEIGHT)
    row:SetWidth(COLWIDTH)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture(Theme.texture.solid)
    highlight:SetAllPoints()
    highlight:SetVertexColor(1, 1, 1, 0.06)
    row:SetHighlightTexture(highlight)
    row:SetCheckedTexture(highlight)

    -- TPL badge, right-aligned so the guide names still line up. Only shown
    -- for placeholder guides, which would otherwise look authored.
    local badge = Theme:Badge(row, "TPL", "tpl")
    badge:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    badge:Hide()

    local text = row:CreateFontString(nil, "OVERLAY")
    Theme:SetFont(text, "body", 11)
    text:SetPoint("LEFT", row, "LEFT", 6, 0)
    Theme:TextColor(text, "textDim")
    text:SetWidth(COLWIDTH - 12)
    text:SetHeight(ROWHEIGHT)
    text:SetJustifyH("LEFT")

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", OnClick)
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", HideTooltip)

    row.text = text
    row.badge = badge
    rows[i] = row
end

-- Slider for scrolling
local slider = CreateFrame("Slider", "AegisPathfinderGuideListSlider", frame, "UIPanelScrollBarTemplate")
slider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -45)
slider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 25)
slider:SetMinMaxValues(0, 100)
slider:SetValueStep(1)
slider:SetWidth(16)
frame.slider = slider

slider:SetScript("OnValueChanged", function()
    local val = arg1
    if not slider.updating and AegisPathfinder.UpdateGuideListPanel then
        offset = math.floor(val)
        AegisPathfinder:UpdateGuideListPanel()
    end
end)
slider:SetValue(0)

frame:SetScript("OnShow", function()
    offset = 0
    local quad, vhalf, hhalf = AegisPathfinder.GetQuadrant(AegisPathfinder.statusframe)
    local anchpoint = (vhalf == "TOP" and "BOTTOM" or "TOP") .. hhalf
    this:ClearAllPoints()
    this:SetPoint(quad, AegisPathfinder.statusframe, anchpoint)
    AegisPathfinder:UpdateGuideListPanel()
    this:SetAlpha(0)
    this:SetScript("OnUpdate", ww.FadeIn)
end)

frame:EnableMouseWheel()
frame:SetScript("OnMouseWheel", function()
    local val = arg1
    local oldOffset = offset
    offset = offset - val * NUMROWS
    local maxOffset = math.max(0, table.getn(displayList) - TOTALROWS)
    if offset > maxOffset then offset = maxOffset end
    if offset < 0 then offset = 0 end

    if offset ~= oldOffset then
        slider.updating = true
        slider:SetValue(offset)
        slider.updating = false
        AegisPathfinder:UpdateGuideListPanel()
    end
end)

ww.SetFadeTime(frame, 0.7)

table.insert(UISpecialFrames, "AegisPathfinderGuideList")

-- Public API: open guide list with optional level filter preset
function AegisPathfinder:ShowGuideList(withLevelFilter)
    if withLevelFilter then
        levelFilterOn = true
    end
    self.guidelistframe:Show()
end

function AegisPathfinder:UpdateGuideListPanel()
    if not frame or not frame:IsVisible() then return end

    -- Update title to show branch status
    if self.db.char.isbranching then
        frame.title:SetText("Guide List |cff00ff00(Branching)|r")
    else
        frame.title:SetText("Guide List")
    end

    -- Show/hide Return to Main button
    if self.db.char.isbranching then
        frame.returnBtn:Show()
        frame.returnBtn:Enable()
    else
        frame.returnBtn:Hide()
    end

    if self.db.char.guidecategory == nil then self.db.char.guidecategory = "all" end
    local activeCategory = self.db.char.guidecategory

    filterCheck:SetChecked(levelFilterOn)
    for _, tab in ipairs(self.guidecategorytabs or {}) do
        tab:SetActive(tab.categoryKey == activeCategory)
    end

    -- Build categorized display list (fresh table each time)
    displayList = {}
    local turtleGuides = {}
    local optimizedGuides = {}
    local rxpGuides = {}
    local rxphcGuides = {}
    local zoneGuides = {}
    local professionGuides = {}
    local seen = {}

    local playerLevel = UnitLevel("player") or 0
    local margin = 5

    for _, name in ipairs(self.guidelist) do
        if not self:IsRoutePackGuide(name) and not seen[name] then
            seen[name] = true

            local include = true
            if levelFilterOn then
                local minLevel, maxLevel = self:ParseGuideLevelRange(name)
                if minLevel and maxLevel then
                    if playerLevel < (minLevel - margin) or playerLevel > (maxLevel + margin) then
                        include = false
                    end
                end
            end

            if include then
                local cat = self:GetGuideCategory(name)
                if activeCategory ~= "all" and cat ~= activeCategory then
                    include = false
                end
            end

            if include then
                local cat = self:GetGuideCategory(name)
                if cat == "turtle" then
                    table.insert(turtleGuides, name)
                elseif cat == "optimized" then
                    table.insert(optimizedGuides, name)
                elseif cat == "rxp" then
                    table.insert(rxpGuides, name)
                elseif cat == "rxp_hc" then
                    table.insert(rxphcGuides, name)
                elseif cat == "profession" then
                    table.insert(professionGuides, name)
                else
                    table.insert(zoneGuides, name)
                end
            end
        end
    end

    table.sort(turtleGuides, SortGuidesByLevel)
    table.sort(optimizedGuides, SortGuidesByLevel)
    table.sort(rxpGuides, SortGuidesByLevel)
    table.sort(rxphcGuides, SortGuidesByLevel)
    table.sort(zoneGuides, SortGuidesByLevel)
    table.sort(professionGuides, SortGuidesByLevel)

    if table.getn(turtleGuides) > 0 then
        table.insert(displayList, { header = true, text = "--- Turtle-lineage Custom Zones ---" })
        for _, name in ipairs(turtleGuides) do
            table.insert(displayList, { guide = name })
        end
    end

    if table.getn(optimizedGuides) > 0 then
        table.insert(displayList, { header = true, text = "--- Optimized Guides ---" })
        for _, name in ipairs(optimizedGuides) do
            table.insert(displayList, { guide = name })
        end
    end

    if table.getn(rxpGuides) > 0 then
        table.insert(displayList, { header = true, text = "--- RXP Guides ---" })
        for _, name in ipairs(rxpGuides) do
            table.insert(displayList, { guide = name })
        end
    end

    if table.getn(rxphcGuides) > 0 then
        table.insert(displayList, { header = true, text = "--- RXP Hardcore Guides ---" })
        for _, name in ipairs(rxphcGuides) do
            table.insert(displayList, { guide = name })
        end
    end

    if table.getn(zoneGuides) > 0 then
        table.insert(displayList, { header = true, text = "--- Zone Guides ---" })
        for _, name in ipairs(zoneGuides) do
            table.insert(displayList, { guide = name })
        end
    end

    if table.getn(professionGuides) > 0 then
        table.insert(displayList, { header = true, text = "--- Professions ---" })
        for _, name in ipairs(professionGuides) do
            table.insert(displayList, { guide = name })
        end
    end

    -- Clamp offset and update slider
    local maxOffset = math.max(0, table.getn(displayList) - TOTALROWS)
    if offset > maxOffset then offset = maxOffset end
    if offset < 0 then offset = 0 end

    if maxOffset > 0 then
        slider:Show()
        slider.updating = true
        slider:SetMinMaxValues(0, maxOffset)
        slider:SetValue(offset)
        slider.updating = false
    else
        slider:Hide()
    end

    -- Update rows (never hide — just clear text for unused slots, matching original pattern)
    for i, row in ipairs(rows) do
        local entry = displayList[i + offset]
        if entry and entry.header then
            row.text:SetText("|cffffd100" .. entry.text .. "|r")
            row.guide = nil
            row.badge:Hide()
            row:SetChecked(false)
            row:Enable()
        elseif entry and entry.guide then
            row:Enable()
            local name = entry.guide
            row.guide = name

            if self:IsTemplateGuide(name) then row.badge:Show() else row.badge:Hide() end

            -- Color by level range: green = in range, yellow = +-5, red = out of range
            local minLevel, maxLevel = self:ParseGuideLevelRange(name)
            local colorCode
            if minLevel and maxLevel then
                if playerLevel >= minLevel and playerLevel <= maxLevel then
                    colorCode = "|cff00ff00" -- green: in range
                elseif playerLevel >= (minLevel - 5) and playerLevel <= (maxLevel + 5) then
                    colorCode = "|cffffff00" -- yellow: within 5 levels
                else
                    colorCode = "|cffff4444" -- red: out of range
                end
            else
                colorCode = "|cffcccccc" -- gray: no level info
            end

            -- Completion percentage
            local complete
            if self.db.char.currentguide == name and self.current and self.actions then
                complete = (self.current - 1) / table.getn(self.actions)
            else
                complete = self.db.char.completion[name]
            end

            local text
            if complete and complete ~= 0 then
                local pct = math.floor(complete * 100)
                text = string.format("%s%s (%d%%)|r", colorCode, name, pct)
            else
                text = colorCode .. name .. "|r"
            end

            if self.db.char.isbranching and self.db.char.branchsavedguide == name then
                text = "|cff00ff00[Main]|r " .. text
            end

            row.text:SetText(text)
            row:SetChecked(self.db.char.currentguide == name)
        else
            row.guide = nil
            row.text:SetText("")
            row.badge:Hide()
            row:SetChecked(false)
            row:Enable()
        end
    end
end
