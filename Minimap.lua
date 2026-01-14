-- Minimap.lua
Nebel = Nebel or {}
local N = Nebel

-- Saved minimap settings (only used when NOT managed by MinimapButtonButton)
NebelDB.minimap = NebelDB.minimap or {
    angle = 220,
}

local MINIMAP_RADIUS = 80

local function IsMBBLoaded()
    return IsAddOnLoaded and IsAddOnLoaded("MinimapButtonButton")
end

local function UpdateMinimapButtonPosition(btn)
    local angle = math.rad(NebelDB.minimap.angle or 220)
    local x = math.cos(angle) * MINIMAP_RADIUS
    local y = math.sin(angle) * MINIMAP_RADIUS
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Recalculate visuals based on current button size (MBB may resize!)
local function ApplyVisualLayout(btn)
    local w = btn:GetWidth() or 32
    local h = btn:GetHeight() or 32
    local s = math.min(w, h)

    -- Since the ring is inside the icon texture, the icon should fill the button
    local iconSize = math.floor(s * 0.95)

    local nt = btn:GetNormalTexture()
    if nt then
        nt:ClearAllPoints()
        nt:SetPoint("CENTER", btn, "CENTER", 0, 0)
        nt:SetSize(iconSize, iconSize)
    end

    local pt = btn:GetPushedTexture()
    if pt then
        pt:ClearAllPoints()
        pt:SetPoint("CENTER", btn, "CENTER", 1, -1)
        pt:SetSize(iconSize, iconSize)
    end

    -- round minimap highlight
    if btn.highlight then
        btn.highlight:ClearAllPoints()
        btn.highlight:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        btn.highlight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    end
end

function N.CreateMinimapButton()
    if N.minimapButton then return end

    -- SecureActionButtonTemplate so click works even if MBB overwrites scripts
    local btn = CreateFrame("Button", "NebelMinimapButton", Minimap, "SecureActionButtonTemplate")
    N.minimapButton = btn

    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:EnableMouse(true)
    btn:RegisterForClicks("AnyUp")

    -- Secure macro click (same as /nebel)
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", "/nebel")

    -- Tooltip text used by some collectors
    btn.tooltipText = "Nebel Item Tracker\nLeft-click: Toggle window"

    -------------------------------------------------------------------
    -- Textures (MBB-friendly: NormalTexture is important)
    -- Icon already contains the ring/border.
    -------------------------------------------------------------------
    btn:SetNormalTexture("Interface\\AddOns\\Nebel\\Media\\MinimapIcon")
    btn:SetPushedTexture("Interface\\AddOns\\Nebel\\Media\\MinimapIcon")

    -- Round highlight (not square)
    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    btn.highlight:SetBlendMode("ADD")

    -- Layout adapts if MBB changes the button size
    btn:SetScript("OnSizeChanged", function(self)
        ApplyVisualLayout(self)
    end)
    ApplyVisualLayout(btn)

    -- Position on minimap (only relevant if not collected)
    UpdateMinimapButtonPosition(btn)

    -- Drag handling (disabled when MBB manages buttons)
    if not IsMBBLoaded() then
        btn:RegisterForDrag("LeftButton")

        btn:SetScript("OnDragStart", function(self)
            self:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                local cx, cy = GetCursorPosition()
                local scale = UIParent:GetScale()
                cx, cy = cx / scale, cy / scale

                local angle = math.deg(math.atan2(cy - my, cx - mx))
                NebelDB.minimap.angle = angle
                UpdateMinimapButtonPosition(self)
            end)
        end)

        btn:SetScript("OnDragStop", function(self)
            btn:SetScript("OnUpdate", nil)
        end)

        -- Tooltip only when not managed by MBB (MBB often handles its own)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("Nebel Item Tracker", 1, 1, 1)
            GameTooltip:AddLine("Left-click: Toggle window", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Drag: Move icon", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
end
