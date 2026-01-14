-- Nebel Item Tracker Addon
local ADDON_NAME = "Nebel"
local ADDON_PREFIX = "NebelSync"

-- Initialize saved variables
NebelDB = NebelDB or {}

-- Local variables
local frame
local playerNeeds = {} -- Local player's needs
local otherPlayerNeeds = {} -- Other players' needs {playerName = {itemID = count}}
local scrollFrame
local contentFrame

-- Drag/drop + popup state
local pendingDropItemID = nil

-- Communication
C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)

-----------------------------------------------------------------------
-- Drag & Drop + Ask Count Popup
-----------------------------------------------------------------------

StaticPopupDialogs["NEBEL_ASK_COUNT"] = {
    text = "How many do you need?",
    button1 = "OK",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 80,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,

    OnShow = function(self)
        local editBox = self.editBox
        editBox:SetNumeric(true)
        editBox:SetText("1")
        editBox:HighlightText()
        editBox:SetFocus()

        if pendingDropItemID then
            local _, link = GetItemInfo(pendingDropItemID)
            if link then
                self.text:SetText("How many do you need?\n" .. link)
            else
                self.text:SetText("How many do you need?\nItemID: " .. tostring(pendingDropItemID))
            end
        else
            self.text:SetText("How many do you need?")
        end
    end,

    OnAccept = function(self)
        local v = tonumber(self.editBox:GetText())
        local count = (v and v > 0) and v or 1

        if pendingDropItemID then
            AddNeededItem(tostring(pendingDropItemID), count)
        end

        pendingDropItemID = nil
    end,

    OnCancel = function()
        pendingDropItemID = nil
    end,
}

local function GetItemIDFromCursor()
    local infoType, itemID, itemLink = GetCursorInfo()
    if infoType ~= "item" then return nil end

    if itemID then return tonumber(itemID) end
    if itemLink then
        return tonumber(string.match(itemLink, "item:(%d+)"))
    end
    return nil
end

local function HandleDroppedItem()
    local itemID = GetItemIDFromCursor()
    if not itemID then return end

    ClearCursor()

    pendingDropItemID = itemID
    StaticPopup_Show("NEBEL_ASK_COUNT")
end

-----------------------------------------------------------------------
-- Addon frame & events
-----------------------------------------------------------------------

local NebelAddon = CreateFrame("Frame")
NebelAddon:RegisterEvent("ADDON_LOADED")
NebelAddon:RegisterEvent("PLAYER_ENTERING_WORLD")
NebelAddon:RegisterEvent("CHAT_MSG_ADDON")

-- Event handler (FIXED: proper varargs handling)
NebelAddon:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            if NebelDB.playerNeeds then
                playerNeeds = NebelDB.playerNeeds
            end
            print("|cFF00FF00Nebel Item Tracker loaded! Type /nebel to open.|r")
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        BroadcastNeeds()

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == ADDON_PREFIX then
            ReceiveNeeds(sender, message)
        end
    end
end)

-----------------------------------------------------------------------
-- Sync / Serialization
-----------------------------------------------------------------------

function BroadcastNeeds()
    local data = SerializeNeeds(playerNeeds)

    if IsInGroup() then
        if IsInRaid() then
            C_ChatInfo.SendAddonMessage(ADDON_PREFIX, data, "RAID")
        else
            C_ChatInfo.SendAddonMessage(ADDON_PREFIX, data, "PARTY")
        end
    end

    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, data, "GUILD")
    end
end

function SerializeNeeds(needs)
    local parts = {}
    for itemID, count in pairs(needs) do
        table.insert(parts, itemID .. ":" .. count)
    end
    return table.concat(parts, ";")
end

function DeserializeNeeds(data)
    local needs = {}
    if data and data ~= "" then
        for pair in string.gmatch(data, "[^;]+") do
            local itemID, count = string.match(pair, "(%d+):(%d+)")
            if itemID and count then
                needs[tonumber(itemID)] = tonumber(count)
            end
        end
    end
    return needs
end

function ReceiveNeeds(sender, data)
    local playerName = string.match(sender or "", "([^-]+)")
    if playerName and playerName ~= UnitName("player") then
        otherPlayerNeeds[playerName] = DeserializeNeeds(data)
    end
end

-----------------------------------------------------------------------
-- UI
-----------------------------------------------------------------------

function CreateMainWindow()
    if frame then
        frame:Show()
        return
    end

    frame = CreateFrame("Frame", "NebelFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(450, 500)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText("Nebel Item Tracker")

    -- Add item section
    local addLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addLabel:SetPoint("TOPLEFT", 20, -35)
    addLabel:SetText("Add Item (Name or ID):")

    local itemInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    itemInput:SetSize(200, 30)
    itemInput:SetPoint("TOPLEFT", 20, -55)
    itemInput:SetAutoFocus(false)

    -- Drag & drop onto input box
    itemInput:EnableMouse(true)
    itemInput:SetScript("OnReceiveDrag", HandleDroppedItem)
    itemInput:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and GetCursorInfo() then
            HandleDroppedItem()
        end
    end)

    local countLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    countLabel:SetPoint("LEFT", itemInput, "RIGHT", 15, 0)
    countLabel:SetText("Count:")

    local countInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    countInput:SetSize(50, 30)
    countInput:SetPoint("LEFT", countLabel, "RIGHT", 5, 0)
    countInput:SetAutoFocus(false)
    countInput:SetText("1")
    countInput:SetNumeric(true)

    local addButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    addButton:SetSize(80, 25)
    addButton:SetPoint("LEFT", countInput, "RIGHT", 10, 0)
    addButton:SetText("Add")
    addButton:SetScript("OnClick", function()
        local itemNameOrID = itemInput:GetText()
        local count = tonumber(countInput:GetText()) or 1

        if itemNameOrID and itemNameOrID ~= "" then
            AddNeededItem(itemNameOrID, count)
            itemInput:SetText("")
            countInput:SetText("1")
        end
    end)

    -- My needs section
    local myNeedsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    myNeedsLabel:SetPoint("TOPLEFT", 20, -95)
    myNeedsLabel:SetText("My Needed Items:")

    -- Scroll frame for item list
    scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -115)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 20)

    contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetSize(380, 350)
    scrollFrame:SetScrollChild(contentFrame)

    -- Drag & drop onto list area
    contentFrame:EnableMouse(true)
    contentFrame:SetScript("OnReceiveDrag", HandleDroppedItem)
    contentFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and GetCursorInfo() then
            HandleDroppedItem()
        end
    end)

    UpdateItemList()
end

-----------------------------------------------------------------------
-- Item needs management
-----------------------------------------------------------------------

function AddNeededItem(itemInput, count)
    local itemID = tonumber(itemInput)

    if not itemID then
        -- Accept item links pasted into the input
        local fromLink = string.match(itemInput or "", "item:(%d+)")
        if fromLink then
            itemID = tonumber(fromLink)
        end
    end

    if not itemID then
        -- Try to get item ID from name (requires cache)
        local _, itemLink = GetItemInfo(itemInput)
        if itemLink then
            itemID = tonumber(string.match(itemLink, "item:(%d+)"))
        end
    end

    if itemID then
        playerNeeds[itemID] = count
        NebelDB.playerNeeds = playerNeeds
        UpdateItemList()
        BroadcastNeeds()
    else
        print("|cFFFF0000Nebel: Item not found. Try item ID or ensure it's in your cache.|r")
    end
end

function RemoveNeededItem(itemID)
    playerNeeds[itemID] = nil
    NebelDB.playerNeeds = playerNeeds
    UpdateItemList()
    BroadcastNeeds()
end

function UpdateItemList()
    if not contentFrame then return end

    -- Clear existing items safely
    if contentFrame.items then
        for i = 1, #contentFrame.items do
            contentFrame.items[i]:Hide()
            contentFrame.items[i]:SetParent(nil)
        end
    end
    contentFrame.items = {}

    local yOffset = 0
    for itemID, count in pairs(playerNeeds) do
        local itemName, itemLink = GetItemInfo(itemID)

        if itemName and itemLink then
            local itemFrame = CreateFrame("Frame", nil, contentFrame)
            itemFrame:SetSize(360, 30)
            itemFrame:SetPoint("TOPLEFT", 5, -yOffset)

            local itemText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            itemText:SetPoint("LEFT", 5, 0)
            itemText:SetText(itemLink .. " x" .. count)

            local deleteBtn = CreateFrame("Button", nil, itemFrame, "GameMenuButtonTemplate")
            deleteBtn:SetSize(60, 20)
            deleteBtn:SetPoint("RIGHT", -5, 0)
            deleteBtn:SetText("Remove")
            deleteBtn:SetScript("OnClick", function()
                RemoveNeededItem(itemID)
            end)

            table.insert(contentFrame.items, itemFrame)
            yOffset = yOffset + 35
        end
    end
end

-----------------------------------------------------------------------
-- Tooltip hook (shows YOU + other players)
-----------------------------------------------------------------------

local function GetItemIDFromLink(itemLink)
    if not itemLink then return nil end
    return tonumber(string.match(itemLink, "item:(%d+)"))
end

local function OnTooltipSetItem(tooltip)
    local _, itemLink = tooltip:GetItem()
    if not itemLink then return end

    local itemID = GetItemIDFromLink(itemLink)
    if not itemID then return end

    local needLines = {}

    -- Local player needs
    local myCount = playerNeeds[itemID]
    if myCount then
        table.insert(needLines, "|cFF00FF00" .. UnitName("player") .. "|r needs x" .. myCount)
    end

    -- Other players
    for playerName, needs in pairs(otherPlayerNeeds) do
        local count = needs[itemID]
        if count then
            table.insert(needLines, playerName .. " needs x" .. count)
        end
    end

    if #needLines > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFF00FF00Nebel - Players Need:|r")
        for _, line in ipairs(needLines) do
            tooltip:AddLine(line, 1, 1, 1)
        end
        tooltip:Show()
    end
end

GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)

-----------------------------------------------------------------------
-- Slash command (FIXED: correct toggle behavior)
-----------------------------------------------------------------------

SLASH_NEBEL1 = "/nebel"
SlashCmdList["NEBEL"] = function(msg)
    if not frame then
        CreateMainWindow()
        frame:Show()
        return
    end

    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end
