local _, ns = ...
-- Adds a line to item tooltips saying whether the item beats what you wear:
--   Outfitter: UPGRADE +12% over [worn item]  /  worse  /  about the same  /  can't use
local function Add(tip, link)
    if not ns.db or not ns.db.showTooltip or not ns.Spec or not ns.Spec() then return end
    if not link then
        local ok, _, l = pcall(tip.GetItem, tip)
        link = ok and l or nil
    end
    if not link or tip.outfitterDone == link then return end
    local ok, r = pcall(ns.Compare, link)
    if not ok or not r or not r.gain or r.isWorn then return end
    local worn = r.worn and r.worn:match("%[(.-)%]") or nil
    local minGain = ns.db.minGain or 3
    local line
    if r.unusable then
        line = "|cffff6060Outfitter: you can't use this|r"
    elseif r.empty then
        line = "|cff40ff40Outfitter: UPGRADE, fills an empty slot|r"
        if r.tooHigh then line = line .. (" |cffffaa00(needs level %d)|r"):format(r.tooHigh) end
    elseif r.gain >= minGain then
        line = ("|cff40ff40Outfitter: UPGRADE, +%d%% over %s|r"):format(math.floor(r.gain + 0.5), worn or "what you wear")
        if r.tooHigh then line = line .. (" |cffffaa00(needs level %d)|r"):format(r.tooHigh) end
    elseif r.gain <= -minGain then
        line = ("|cffff9090Outfitter: worse, %d%% below %s|r"):format(math.floor(-r.gain + 0.5), worn or "what you wear")
    else
        line = "|cffccccccOutfitter: about the same as " .. (worn or "what you wear") .. "|r"
    end
    tip.outfitterDone = link
    tip:AddLine(" ")
    tip:AddLine(line)
    tip:Show()
end

local function Clear(tip) tip.outfitterDone = nil end

-- current clients build tooltips from data and run post-call hooks; older ones fire OnTooltipSetItem
if _G.TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data)
        if tip == GameTooltip or tip == ItemRefTooltip or tip == ShoppingTooltip1 or tip == ShoppingTooltip2 then
            Add(tip, data and data.hyperlink)
        end
    end)
end
for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
    local t = _G[name]
    if t and t.HookScript then
        pcall(t.HookScript, t, "OnTooltipSetItem", function(tip) Add(tip) end)
        pcall(t.HookScript, t, "OnTooltipCleared", Clear)
    end
end
