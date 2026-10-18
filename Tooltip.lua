local _, ns = ...
-- Adds a line to item tooltips saying whether the item beats what you wear:
--   Outfitter: UPGRADE +12% over [worn item]  /  worse  /  about the same  /  can't use
local function Verdict(link)
    if not link or not ns.db or not ns.db.showTooltip or not ns.Spec or not ns.Spec() then return nil end
    local ok, r = pcall(ns.Compare, link)
    if not ok or not r or not r.gain or r.isWorn then return nil end
    local worn = r.worn and r.worn:match("%[(.-)%]") or nil
    local minGain = ns.db.minGain or 3
    local line
    if r.unusable then
        line = "|cffff6060Outfitter: you can't use this|r"
    elseif r.empty then
        line = "|cff40ff40Outfitter: UPGRADE, fills an empty slot|r"
        if r.tooHigh then line = line .. (" |cffffaa00(needs level %d)|r"):format(r.tooHigh) end
    elseif r.gain >= minGain then
        if r.gain > 300 then   -- same cut-off as the window: a huge percentage on a low-level item is just noise
            line = ("|cff40ff40Outfitter: UPGRADE, big upgrade over %s|r"):format(worn or "what you wear")
        else
            line = ("|cff40ff40Outfitter: UPGRADE, +%d%% over %s|r"):format(math.floor(r.gain + 0.5), worn or "what you wear")
        end
        if r.tooHigh then line = line .. (" |cffffaa00(needs level %d)|r"):format(r.tooHigh) end
    elseif r.gain <= -minGain then
        line = ("|cffff9090Outfitter: worse, %d%% below %s|r"):format(math.floor(-r.gain + 0.5), worn or "what you wear")
    else
        line = "|cffccccccOutfitter: about the same as " .. (worn or "what you wear") .. "|r"
    end
    return line
end

local function Add(tip, link)
    if not link then
        local ok, _, l = pcall(tip.GetItem, tip)
        link = ok and l or nil
    end
    if not link or tip.outfitterDone == link then return end
    -- the Auction House groups random-suffix items ("of the Monkey") into one entry whose tooltip has no real stats;
    -- scoring it would be a guess, so say so instead and leave the exact figure to Outfitter's Auction tab
    local varies
    for i = 1, (tip.NumLines and tip:NumLines() or 0) do
        local fs = _G[(tip:GetName() or "") .. "TextLeft" .. i]
        local t = fs and fs.GetText and fs:GetText()
        if type(t) == "string" and t:find("may vary in stats", 1, true) then varies = true break end
    end
    local line = varies and (ns.db and ns.db.showTooltip and "|cffccccccOutfitter: stats vary by listing, see the Auction tab|r") or Verdict(link)
    if not line then return end
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

-- Dialogue UI draws quest rewards and gossip items in its own tooltip (not the game's), so it needs its own hook
local dialogueHooked
local function HookDialogue()
    if dialogueHooked then return end
    local api = _G.DialogueUIAPI
    if not (api and api.AddItemTooltipProcessorExternal) then return end
    dialogueHooked = true
    api.AddItemTooltipProcessorExternal(function(tip, itemID, link)
        link = link or (itemID and ("item:" .. itemID))
        if not link or tip.outfitterData == tip.tooltipData and tip.outfitterLink == link then return end
        local line = Verdict(link)
        if not line then return end
        tip.outfitterData, tip.outfitterLink = tip.tooltipData, link
        tip:AddLine(" ")
        tip:AddLine(line)
        return true
    end)
end
HookDialogue()
local dl = CreateFrame("Frame")
dl:RegisterEvent("ADDON_LOADED")
dl:RegisterEvent("PLAYER_LOGIN")
dl:SetScript("OnEvent", function() HookDialogue() end)
