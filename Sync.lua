-- Sync.lua
Nebel = Nebel or {}
local N = Nebel

function N.SerializeNeeds(needs)
    local parts = {}
    for itemID, count in pairs(needs) do
        parts[#parts + 1] = tostring(itemID) .. ":" .. tostring(count)
    end
    return table.concat(parts, ";")
end

function N.DeserializeNeeds(data)
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

function N.BroadcastNeeds()
    local data = N.SerializeNeeds(N.playerNeeds)

    if IsInGroup() then
        if IsInRaid() then
            C_ChatInfo.SendAddonMessage(N.ADDON_PREFIX, data, "RAID")
        else
            C_ChatInfo.SendAddonMessage(N.ADDON_PREFIX, data, "PARTY")
        end
    end

    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(N.ADDON_PREFIX, data, "GUILD")
    end
end

function N.ReceiveNeeds(sender, data)
    local playerName = string.match(sender or "", "([^-]+)")
    if not playerName then return end
    if playerName == UnitName("player") then return end

    N.otherPlayerNeeds[playerName] = N.DeserializeNeeds(data)
end
