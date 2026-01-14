-- Tooltip.lua
Nebel = Nebel or {}
local N = Nebel

local function GetItemIDFromLink(itemLink)
    if not itemLink then return nil end
    return tonumber(string.match(itemLink, "item:(%d+)"))
end

local function OnTooltipSetItem(tooltip)
    local _, itemLink = tooltip:GetItem()
    if not itemLink then return end

    local itemID = GetItemIDFromLink(itemLink)
    if not itemID then return end

    local lines = {}

    -- Only OTHER players (not you)
    for playerName, needs in pairs(N.otherPlayerNeeds) do
        local cnt = needs[itemID]
        if cnt then
            lines[#lines + 1] = playerName .. " needs x" .. cnt
        end
    end

    if #lines > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFF00FF00Nebel - Players Need:|r")
        for _, line in ipairs(lines) do
            tooltip:AddLine(line, 1, 1, 1)
        end
        tooltip:Show()
    end
end

GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
