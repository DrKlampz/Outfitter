local ADDON_NAME, ns = ...
-- Window customization (see Look.lua). Opens with /outfitterlook.
if not ns.WinLook then return end
ns.WinLook.Setup({
    title = "Outfitter",
    slash = "outfitterlook",
    media = "Interface\\AddOns\\Outfitter\\Media\\",
    db = function() return OutfitterDB end,
    windows = {
        { id = "main", name = "Main window", global = "OutfitterFrame", strip = "template", title = function(f) return f.TitleText end },
    },
})
