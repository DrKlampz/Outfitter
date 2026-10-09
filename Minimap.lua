local _, ns = ...

-- Minimap button: left click opens the window, right click opens "Where to get",
-- drag to move it around the minimap. /outfit minimap hides or shows it.
local btn
local ICON = "Interface\\Icons\\INV_Helmet_01"

local function Place()
    if not btn then return end
    local angle = math.rad((ns.db.minimap and ns.db.minimap.angle) or 215)
    local w, h = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
    local x, y = math.cos(angle), math.sin(angle)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local dx, dy
    if shape == "SQUARE" then
        -- square minimap: slide along the edge instead of a circle
        local m = math.max(math.abs(x), math.abs(y))
        dx, dy = x / m * (w + 6), y / m * (h + 6)
    else
        dx, dy = x * (w + 5), y * (h + 5)
    end
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", dx, dy)
end

local function Drag(self)
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    ns.db.minimap.angle = math.deg(math.atan2(py - my, px - mx)) % 360
    Place()
end

local function Tip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Outfitter", 0.2, 0.8, 1)
    local spec = ns.Spec and ns.Spec()
    if spec then GameTooltip:AddLine(("%s (%s)"):format(spec.name, spec.role), 1, 1, 1) end
    local ok, list = pcall(ns.FindUpgrades)
    if ok and list then
        GameTooltip:AddLine(#list > 0 and ("%d upgrade%s in your bags"):format(#list, #list == 1 and "" or "s") or "No upgrades in your bags", 0.4, 1, 0.4)
    end
    GameTooltip:AddLine("Left click: open", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Right click: where to get gear", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

function ns.UpdateMinimapButton()
    if not btn then return end
    if ns.db.minimap.hide then btn:Hide() else btn:Show() Place() end
end

function ns.BuildMinimapButton()
    if btn or not Minimap then return end
    btn = CreateFrame("Button", "OutfitterMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("CENTER", 0, 1)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("CENTER", 0, 1)
    local ring = btn:CreateTexture(nil, "OVERLAY")
    ring:SetSize(53, 53)
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetPoint("TOPLEFT")
    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if ns.OpenTab then ns.OpenTab("src") end
        elseif ns.ToggleUI then
            ns.ToggleUI()
        end
    end)
    btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", Drag) GameTooltip:Hide() end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    btn:SetScript("OnEnter", Tip)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ns.UpdateMinimapButton()
end
