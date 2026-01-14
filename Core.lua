-- Core.lua
local ADDON_NAME = ...
Nebel = Nebel or {}
local N = Nebel

N.ADDON_NAME = ADDON_NAME
N.ADDON_PREFIX = "NebelSync"

-- Saved variables
NebelDB = NebelDB or {}

-- State
N.playerNeeds = NebelDB.playerNeeds or {}   -- [itemID] = count
N.otherPlayerNeeds = {}                    -- [playerName] = {[itemID]=count}

-- UI refs
N.frame = nil
N.scrollFrame = nil
N.contentFrame = nil

-- Register prefix
C_ChatInfo.RegisterAddonMessagePrefix(N.ADDON_PREFIX)

-- Central toggle (used by /nebel AND minimap button)
function N.ToggleWindow()
    if not N.frame then
        if N.CreateMainWindow then
            N.CreateMainWindow()
        end
        if N.frame then
            N.frame:Show()
        end
        return
    end

    if N.frame:IsShown() then
        N.frame:Hide()
    else
        N.frame:Show()
    end
end

-- Event frame
N.eventFrame = CreateFrame("Frame")
local EF = N.eventFrame

EF:RegisterEvent("ADDON_LOADED")
EF:RegisterEvent("PLAYER_ENTERING_WORLD")
EF:RegisterEvent("CHAT_MSG_ADDON")
EF:RegisterEvent("GET_ITEM_INFO_RECEIVED")

EF:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= N.ADDON_NAME then return end

        -- Load saved needs
        if NebelDB.playerNeeds then
            N.playerNeeds = NebelDB.playerNeeds
        else
            NebelDB.playerNeeds = N.playerNeeds
        end

        -- Create minimap button (MBB-friendly)
        if N.CreateMinimapButton then
            N.CreateMinimapButton()
        end

        print("|cFF00FF00Nebel Item Tracker loaded! Type /nebel to open.|r")

    elseif event == "PLAYER_ENTERING_WORLD" then
        if N.BroadcastNeeds then
            N.BroadcastNeeds()
        end

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == N.ADDON_PREFIX and N.ReceiveNeeds then
            N.ReceiveNeeds(sender, message)
        end

    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemID = ...
        itemID = tonumber(itemID)
        if not itemID then return end

        if N.playerNeeds[itemID] and N.frame and N.frame:IsShown() and N.UpdateItemList then
            N.UpdateItemList()
        end
    end
end)

-- Slash command
SLASH_NEBEL1 = "/nebel"
SlashCmdList["NEBEL"] = function(msg)
    N.ToggleWindow()
end
