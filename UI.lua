-- UI.lua
Nebel = Nebel or {}
local N = Nebel

-----------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------

local function ExtractItemIDFromAny(input)
    if not input or input == "" then return nil end

    -- numeric ID
    local asNum = tonumber(input)
    if asNum then return asNum end

    -- item link / partial item link
    local fromLink = string.match(input, "item:(%d+)")
    if fromLink then return tonumber(fromLink) end

    return nil
end

-- Robust cursor parsing for Classic: return itemLink if possible, otherwise "item:<id>"
local function GetItemLinkFromCursor()
    local infoType, a, b = GetCursorInfo()
    if infoType ~= "item" then return nil end

    if type(a) == "string" and string.find(a, "|Hitem:") then
        return a
    end
    if type(b) == "string" and string.find(b, "|Hitem:") then
        return b
    end

    if type(a) == "number" then
        local _, link = GetItemInfo(a)
        return link or ("item:" .. tostring(a))
    end

    return nil
end

-----------------------------------------------------------------------
-- Custom Count Dialog (properly centered)
-----------------------------------------------------------------------

local pendingDropInput = nil

local function EnsureCountDialog()
    if N.countDialog then return N.countDialog end

    local d = CreateFrame("Frame", "NebelCountDialog", UIParent, "BasicFrameTemplate")
    N.countDialog = d

    d:SetSize(360, 170)
    d:SetPoint("CENTER")
    d:SetFrameStrata("DIALOG")
    d:SetClampedToScreen(true)
    d:Hide()

    d.title = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d.title:SetPoint("TOP", 0, -5)
    d.title:SetText("How many do you need?")

    -- Content container (centers the whole block)
    local content = CreateFrame("Frame", nil, d)
    d.content = content
    content:SetSize(300, 80)
    content:SetPoint("CENTER", d, "CENTER", 0, -5)

    -- Item icon
    d.itemIcon = content:CreateTexture(nil, "ARTWORK")
    d.itemIcon:SetSize(32, 32)
    d.itemIcon:SetPoint("LEFT", content, "LEFT", 0, 0)
    d.itemIcon:Hide()

    -- Item line (text)
    d.itemLine = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    d.itemLine:SetPoint("LEFT", d.itemIcon, "RIGHT", 6, 0)
    d.itemLine:SetJustifyH("LEFT")
    d.itemLine:SetText("")

    -- Count input (placed to the right of the item name)
    d.editBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    d.editBox:SetSize(60, 26)
    d.editBox:SetAutoFocus(true)
    d.editBox:SetNumeric(true)
    d.editBox:SetPoint("LEFT", d.itemLine, "RIGHT", 10, 0)

    -- Buttons
    d.okBtn = CreateFrame("Button", nil, d, "GameMenuButtonTemplate")
    d.okBtn:SetSize(120, 25)
    d.okBtn:SetPoint("BOTTOMLEFT", 30, 15)
    d.okBtn:SetText("OK")

    d.cancelBtn = CreateFrame("Button", nil, d, "GameMenuButtonTemplate")
    d.cancelBtn:SetSize(120, 25)
    d.cancelBtn:SetPoint("BOTTOMRIGHT", -30, 15)
    d.cancelBtn:SetText("Cancel")

    -- Behavior
    local function Confirm()
        local v = tonumber(d.editBox:GetText())
        local count = (v and v > 0) and v or 1

        if pendingDropInput then
            N.AddNeededItem(pendingDropInput, count)
        end

        pendingDropInput = nil
        d:Hide()
    end

    d.okBtn:SetScript("OnClick", Confirm)
    d.cancelBtn:SetScript("OnClick", function()
        pendingDropInput = nil
        d:Hide()
    end)

    d.editBox:SetScript("OnEnterPressed", Confirm)
    d.editBox:SetScript("OnEscapePressed", function()
        pendingDropInput = nil
        d:Hide()
    end)

    return d
end

local function ShowCountDialog(itemInput)
    local d = EnsureCountDialog()
    pendingDropInput = itemInput

    local itemID = ExtractItemIDFromAny(itemInput)
    local name, link, _, _, _, _, _, _, _, texture = GetItemInfo(itemID or itemInput)

    if link then
        d.itemLine:SetText(link)
    else
        d.itemLine:SetText("|cFFFFCC00" .. tostring(itemInput) .. "|r")
    end

    if texture then
        d.itemIcon:SetTexture(texture)
        d.itemIcon:Show()
    else
        d.itemIcon:Hide()
    end

    -- Prefill existing count
    if itemID and N.playerNeeds and N.playerNeeds[itemID] then
        d.editBox:SetText(tostring(N.playerNeeds[itemID]))
    else
        d.editBox:SetText("1")
    end

    d:Show()
    d.editBox:HighlightText()
    d.editBox:SetFocus()
end

local function HandleDroppedItem()
    local link = GetItemLinkFromCursor()
    if not link then return end
    ClearCursor()
    ShowCountDialog(link)
end

-----------------------------------------------------------------------
-- Item needs management
-----------------------------------------------------------------------

function N.AddNeededItem(itemInput, count)
    local itemID = ExtractItemIDFromAny(itemInput)

    if not itemID then
        -- Try resolve by name (requires cache)
        local _, itemLink = GetItemInfo(itemInput)
        if itemLink then
            itemID = ExtractItemIDFromAny(itemLink)
        end
    end

    if not itemID then
        print("|cFFFF0000Nebel: Item not found. Use item ID, item link, or drag & drop.|r")
        return
    end

    N.playerNeeds[itemID] = count
    NebelDB.playerNeeds = N.playerNeeds

    if N.UpdateItemList then N.UpdateItemList() end
    if N.BroadcastNeeds then N.BroadcastNeeds() end
end

function N.RemoveNeededItem(itemID)
    N.playerNeeds[itemID] = nil
    NebelDB.playerNeeds = N.playerNeeds

    if N.UpdateItemList then N.UpdateItemList() end
    if N.BroadcastNeeds then N.BroadcastNeeds() end
end

function N.UpdateItemList()
    if not N.contentFrame then return end
    local contentFrame = N.contentFrame

    -- Clear existing rows
    if contentFrame.items then
        for i = 1, #contentFrame.items do
            contentFrame.items[i]:Hide()
            contentFrame.items[i]:SetParent(nil)
        end
    end
    contentFrame.items = {}

    local yOffset = 0
    for itemID, needCount in pairs(N.playerNeeds) do
        local name, itemLink, _, _, _, _, _, _, _, texture = GetItemInfo(itemID)

        local row = CreateFrame("Frame", nil, contentFrame)
        row:SetSize(360, 30)
        row:SetPoint("TOPLEFT", 5, -yOffset)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", 5, 0)
        if texture then
            icon:SetTexture(texture)
            icon:Show()
        else
            icon:Hide()
        end

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", icon, "RIGHT", 6, 0)

        if itemLink then
            text:SetText(itemLink .. " x" .. needCount)
        else
            text:SetText("|cFFFFCC00ItemID: " .. itemID .. " (loading...)|r x" .. needCount)
            GetItemInfo(itemID) -- trigger cache
        end

        local deleteBtn = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
        deleteBtn:SetSize(60, 20)
        deleteBtn:SetPoint("RIGHT", -5, 0)
        deleteBtn:SetText("Remove")
        deleteBtn:SetScript("OnClick", function()
            N.RemoveNeededItem(itemID)
        end)

        table.insert(contentFrame.items, row)
        yOffset = yOffset + 35
    end
end

-----------------------------------------------------------------------
-- Main Window
-----------------------------------------------------------------------

function N.CreateMainWindow()
    if N.frame then
        N.frame:Show()
        return
    end

    local frame = CreateFrame("Frame", "NebelFrame", UIParent, "BasicFrameTemplateWithInset")
    N.frame = frame

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
    addLabel:SetText("Add Item (Name, ID, Link, or Drag & Drop):")

    local itemInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    itemInput:SetSize(220, 30)
    itemInput:SetPoint("TOPLEFT", 20, -55)
    itemInput:SetAutoFocus(false)
    itemInput:EnableMouse(true)

    -- Drag & drop onto input
    itemInput:SetScript("OnReceiveDrag", HandleDroppedItem)
    itemInput:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and GetCursorInfo() then
            HandleDroppedItem()
        end
    end)

    local countLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    countLabel:SetPoint("LEFT", itemInput, "RIGHT", 10, 0)
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
        local txt = itemInput:GetText()
        local cnt = tonumber(countInput:GetText()) or 1

        if txt and txt ~= "" then
            N.AddNeededItem(txt, cnt)
            itemInput:SetText("")
            countInput:SetText("1")
        end
    end)

    -- My needs section
    local myNeedsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    myNeedsLabel:SetPoint("TOPLEFT", 20, -95)
    myNeedsLabel:SetText("My Needed Items:")

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    N.scrollFrame = scrollFrame
    scrollFrame:SetPoint("TOPLEFT", 20, -115)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 20)

    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    N.contentFrame = contentFrame
    contentFrame:SetSize(380, 350)
    scrollFrame:SetScrollChild(contentFrame)

    -- Drag & drop onto list area
    contentFrame:EnableMouse(true)
    contentFrame:SetScript("OnReceiveDrag", HandleDroppedItem)
    contentFrame:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and GetCursorInfo() then
            HandleDroppedItem()
        end
    end)

    N.UpdateItemList()
end
