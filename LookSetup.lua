local ADDON_NAME, ns = ...
-- Window customization (see Look.lua). Opens from the minimap button (Alt-click).
if not ns.WinLook then return end
local function Options()
    local L = ns.WinLook
    local db = function() return ns.db or OutfitterDB end
    local mmdb = function() return (ns.db or OutfitterDB).minimap end
    return { sections = {
        { id = "main", title = "Outfitter", open = true, rows = {
            L.Kon("Add an Outfitter line to item tooltips (upgrade or not)", db, "showTooltip"),
            L.Kon("Alert me when a better item is in my bags", db, "alert"),
            L.Slider("Smallest improvement worth mentioning (%)", db, "minGain", 0, 30, 1),
            L.K("Show the minimap button", mmdb, "hide", function() if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end end, true),
        } },
    } }
end

ns.WinLook.Setup({
    options = Options,
    title = "Outfitter",
    media = "Interface\\AddOns\\Outfitter\\Media\\",
    db = function() return OutfitterDB end,
    windows = {
        { id = "main", name = "Main window", global = "OutfitterFrame", strip = "template", defaultOn = true, title = function(f) return f.TitleText end },
    },
})
