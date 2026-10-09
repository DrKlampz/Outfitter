local _, ns = ...
-- Adds "Outfitter: +12% over [worn item]" to item tooltips.
local function Add(tip)
    if not ns.db or not ns.db.showTooltip or not ns.Spec() then return end
    local _, link = tip:GetItem()
    if not link then return end
    local r = ns.Compare(link)
    if not r or not r.gain or r.isWorn then return end
    local worn = r.worn and r.worn:match("%[(.-)%]") or "an empty slot"
    local line
    if r.unusable then line = "|cffff6060Outfitter: you can't use this|r"
    elseif r.gain >= (ns.db.minGain or 3) then
        line = ("|cff40ff40Outfitter: upgrade, +%d%% over %s|r"):format(math.floor(r.gain + 0.5), worn)
        if r.tooHigh then line = line .. (" |cffffaa00(needs level %d)|r"):format(r.tooHigh) end
    elseif r.gain <= -(ns.db.minGain or 3) then line = ("|cffff9090Outfitter: %d%% worse than %s|r"):format(math.floor(-r.gain + 0.5), worn)
    else line = "|cffcccccOutfitter: about the same as " .. worn .. "|r" end
    tip:AddLine(line)
    tip:Show()
end
if GameTooltip and GameTooltip.HookScript then GameTooltip:HookScript("OnTooltipSetItem", Add) end
if ItemRefTooltip and ItemRefTooltip.HookScript then ItemRefTooltip:HookScript("OnTooltipSetItem", Add) end
