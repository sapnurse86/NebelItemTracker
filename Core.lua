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

        print("|cFF00FF00Nebel Item Tracker loaded! Type /nebel to open.|r")

    elseif event == "PLAYER_ENTERING_WORLD" then
        N.BroadcastNeeds()

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == N.ADDON_PREFIX then
            N.ReceiveNeeds(sender, message)
        end

    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemID, success = ...
        itemID = tonumber(itemID)
        if not itemID then return end

        -- If we track this item, refresh list so placeholders become proper links
        if N.playerNeeds[itemID] and N.frame and N.frame:IsShown() then
            N.UpdateItemList()
        end
    end
end)

-- Slash command
SLASH_NEBEL1 = "/nebel"
SlashCmdList["NEBEL"] = function(msg)
    if not N.frame then
        N.CreateMainWindow()
        N.frame:Show()
        return
    end

    if N.frame:IsShown() then
        N.frame:Hide()
    else
        N.frame:Show()
    end
end
