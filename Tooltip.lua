local _, ns = ...
-- Adds a line to item tooltips saying whether the item beats what you wear:
--   Gearhawk: UPGRADE +12% over [worn item]  /  worse  /  about the same  /  can't use
local function Verdict(link)
    if not link or not ns.db or not ns.db.showTooltip or not ns.Spec or not ns.Spec() then return nil end
    local ok, r = pcall(ns.Compare, link)
    if not ok or not r or not r.gain or r.isWorn then return nil end
    local worn = r.worn and r.worn:match("%[(.-)%]") or nil
    local minGain = ns.db.minGain or 3
    local line
    if r.unusable then
        line = "|cffff6060Gearhawk: you can't use this|r"
    elseif r.empty then
        line = "|cff40ff40Gearhawk: UPGRADE, fills an empty slot|r"
        if r.tooHigh then line = line .. (" |cffffaa00(needs level %d)|r"):format(r.tooHigh) end
    elseif r.gain >= minGain then
        if r.gain > 300 then   -- same cut-off as the window: a huge percentage on a low-level item is just noise
            line = ("|cff40ff40Gearhawk: UPGRADE, big upgrade over %s|r"):format(worn or "what you wear")
        else
            line = ("|cff40ff40Gearhawk: UPGRADE, +%d%% over %s|r"):format(math.floor(r.gain + 0.5), worn or "what you wear")
        end
        if r.tooHigh then line = line .. (" |cffffaa00(needs level %d)|r"):format(r.tooHigh) end
    elseif r.gain <= -minGain then
        line = ("|cffff9090Gearhawk: worse, %d%% below %s|r"):format(math.floor(-r.gain + 0.5), worn or "what you wear")
    else
        line = "|cffccccccGearhawk: about the same as " .. (worn or "what you wear") .. "|r"
    end
    return line
end

local function Add(tip, link)
    if not link then
        local ok, _, l = pcall(tip.GetItem, tip)
        link = ok and l or nil
    end
    if not link or tip.gearhawkDone == link then return end
    -- the Auction House groups random-suffix items ("of the Monkey") into one entry whose tooltip has no real stats;
    -- scoring it would be a guess, so say so instead and leave the exact figure to Gearhawk's Auction tab
    local varies
    for i = 1, (tip.NumLines and tip:NumLines() or 0) do
        local fs = _G[(tip:GetName() or "") .. "TextLeft" .. i]
        local t = fs and fs.GetText and fs:GetText()
        if type(t) == "string" and t:find("may vary in stats", 1, true) then varies = true break end
    end
    local line = varies and (ns.db and ns.db.showTooltip and "|cffccccccGearhawk: stats vary by listing, see the Auction tab|r") or Verdict(link)
    if not line then return end
    tip.gearhawkDone = link
    tip:AddLine(" ")
    tip:AddLine(line)
    tip:Show()
end

local function Clear(tip) tip.gearhawkDone = nil end

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
        if not link or tip.gearhawkData == tip.tooltipData and tip.gearhawkLink == link then return end
        local line = Verdict(link)
        if not line then return end
        tip.gearhawkData, tip.gearhawkLink = tip.tooltipData, link
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

-- ===== Quest rewards: highlight the best upgrade =====
do
-- When a quest offers a choice of rewards, marks the one that is the best upgrade for your spec:
-- a green outline around its icon, and a "+x%" strip along the bottom of every real upgrade.
-- Nothing is marked when none of the choices beats what you wear. /hawk quest turns it off.

local MAX_CHOICES = 6
local marks = {}   -- button -> { glow, text }

local function Mark(btn)
    local m = marks[btn]
    if m then return m end
    m = {}
    local icon = btn.Icon or _G[(btn:GetName() or "") .. "IconTexture"] or btn
    -- a green outline hugging the icon (best pick only)
    m.edges = {}
    for i = 1, 4 do
        local e = btn:CreateTexture(nil, "OVERLAY", nil, 6)
        e:SetColorTexture(0.25, 1, 0.25, 1)
        m.edges[i] = e
        e:Hide()
    end
    local T, B, L, R = m.edges[1], m.edges[2], m.edges[3], m.edges[4]
    T:SetPoint("BOTTOMLEFT", icon, "TOPLEFT", -2, 0)   T:SetPoint("BOTTOMRIGHT", icon, "TOPRIGHT", 2, 0)   T:SetHeight(2)
    B:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", -2, 0)   B:SetPoint("TOPRIGHT", icon, "BOTTOMRIGHT", 2, 0)   B:SetHeight(2)
    L:SetPoint("TOPRIGHT", icon, "TOPLEFT", 0, 2)      L:SetPoint("BOTTOMRIGHT", icon, "BOTTOMLEFT", 0, -2) L:SetWidth(2)
    R:SetPoint("TOPLEFT", icon, "TOPRIGHT", 0, 2)      R:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 0, -2) R:SetWidth(2)
    -- a small strip along the bottom of the icon with the percentage, so nothing floats over the text above
    local bar = btn:CreateTexture(nil, "OVERLAY", nil, 6)
    bar:SetColorTexture(0, 0, 0, 0.7)
    bar:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    bar:SetHeight(13)
    bar:Hide()
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetFont((text:GetFont()), 10, "OUTLINE")
    text:Hide()
    m.bar, m.text = bar, text
    marks[btn] = m
    return m
end

local function ShowEdges(m, on) for _, e in ipairs(m.edges) do if on then e:Show() else e:Hide() end end end

local function ButtonFor(i)
    local frame = _G.QuestInfoRewardsFrame or (_G.QuestInfoFrame and QuestInfoFrame.rewardsFrame)
    if frame and frame.RewardButtons and frame.RewardButtons[i] then return frame.RewardButtons[i] end
    if _G.QuestInfo_GetRewardButton and frame then
        local ok, b = pcall(QuestInfo_GetRewardButton, frame, i)
        if ok and b then return b end
    end
    return _G["QuestInfoRewardsFrameQuestInfoItem" .. i]
end

local function Clear()
    for _, m in pairs(marks) do ShowEdges(m, false) m.bar:Hide() m.text:Hide() end
end

local function Refresh()
    Clear()
    if not ns.db or ns.db.questPick == false or not ns.Spec or not ns.Spec() then return end
    local n = GetNumQuestChoices and GetNumQuestChoices() or 0
    if n < 2 or n > MAX_CHOICES then return end
    local minGain = ns.db.minGain or 3
    local rows, best = {}, nil
    for i = 1, n do
        local link = GetQuestItemLink and GetQuestItemLink("choice", i)
        local ok, r = false, nil
        if link then ok, r = pcall(ns.Compare, link) end
        if ok and r and r.gain and not r.unusable and not r.tooHigh and (r.empty or r.gain >= minGain) then
            local row = { i = i, gain = r.gain, empty = r.empty, score = (r.score or 0) - (r.wornScore or 0) }
            rows[#rows + 1] = row
            if not best or row.gain > best.gain or (row.gain == best.gain and row.score > best.score) then best = row end
        end
    end
    for _, row in ipairs(rows) do
        local btn = ButtonFor(row.i)
        if btn then
            local m = Mark(btn)
            local pct = row.empty and "new" or ("+%d%%"):format(math.floor(row.gain + 0.5))
            if row == best then
                ShowEdges(m, true)
                m.text:SetText("|cff40ff40" .. pct .. "|r")
            else
                ShowEdges(m, false)
                m.text:SetText("|cffb0e8b0" .. pct .. "|r")
            end
            m.bar:Show()
            m.text:Show()
        end
    end
end

local pending
local function Soon()
    if pending then return end
    pending = true
    C_Timer.After(0.15, function()
        pending = nil
        local ok, err = pcall(Refresh)
        if not ok and ns.Print and ns.db and ns.db.debug then ns.Print("quest reward mark failed: " .. tostring(err)) end
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("QUEST_COMPLETE")
f:RegisterEvent("QUEST_ITEM_UPDATE")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:RegisterEvent("QUEST_FINISHED")
f:SetScript("OnEvent", function(_, ev)
    if ev == "QUEST_FINISHED" then Clear() return end
    if _G.QuestFrame and QuestFrame:IsShown() or ev == "QUEST_COMPLETE" then Soon() end
end)
if _G.QuestInfo_ShowRewards then hooksecurefunc("QuestInfo_ShowRewards", Soon) end

function ns.ToggleQuestPick()
    ns.db.questPick = (ns.db.questPick == false)
    ns.Print("quest reward highlight " .. (ns.db.questPick == false and "off" or "on"))
    Soon()
end
end

-- ===== Bags: green arrow on the best upgrades =====
do
-- A small green arrow at the bottom centre of an item's icon in your bags when it is the best upgrade for its slot
-- (rings and trinkets: the best two). Works on the game's own bags and on Baggie. Turn off on the Options tab.

local set, sig = {}, ""
local dirty = true
local arrows = setmetatable({}, { __mode = "k" })   -- button -> texture

local function Rebuild()
    dirty = false
    local new, keys = {}, {}
    if ns.db and ns.db.bagArrow ~= false and ns.Spec and ns.Spec() and ns.FindUpgrades then
        local ok, list = pcall(ns.FindUpgrades)
        if ok and type(list) == "table" then
            for _, e in ipairs(list) do
                if e.bag and e.bagSlot and not e.tooHigh and not e.unusable then
                    local k = e.bag .. ":" .. e.bagSlot
                    new[k] = true
                    keys[#keys + 1] = k
                end
            end
        end
    end
    table.sort(keys)
    local s = table.concat(keys, ",")
    local changed = s ~= sig
    set, sig = new, s
    return changed
end

-- The arrow and a green frame around the icon live on their own small frame on top of the slot. They must not be
-- textures of the slot button itself: Baggie hides every texture it did not make on its buttons, which is why the
-- arrow never showed in Baggie before.
local function ArrowFor(btn)
    local g = arrows[btn]
    if g then return g end
    local host = CreateFrame("Frame", nil, btn)
    host:SetAllPoints(btn)
    host:SetFrameLevel((btn:GetFrameLevel() or 1) + 20)
    host:EnableMouse(false)
    host:Hide()
    g = { host = host }
    -- a soft green wash and a bright green frame, so the item stands out without hovering it
    local wash = host:CreateTexture(nil, "OVERLAY", nil, 1)
    wash:SetAllPoints(host)
    wash:SetColorTexture(0.2, 1, 0.2, 0.16)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 2 } }) do
        local t = host:CreateTexture(nil, "OVERLAY", nil, 3)
        t:SetColorTexture(0.25, 1, 0.25, 0.95)
        t:SetHeight(2)
        t:SetPoint(e[1], host, e[1], 0, 0)
        t:SetPoint(e[2], host, e[2], 0, 0)
    end
    for _, e in ipairs({ { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = host:CreateTexture(nil, "OVERLAY", nil, 3)
        t:SetColorTexture(0.25, 1, 0.25, 0.95)
        t:SetWidth(2)
        t:SetPoint(e[1], host, e[1], 0, 0)
        t:SetPoint(e[2], host, e[2], 0, 0)
    end
    -- the arrow, built from small coloured blocks (no image file needed): a dark outline under a bright green arrow
    local BASE = 3
    local function ab(x, y, w, h, r, gr, b, layer)
        local t = host:CreateTexture(nil, "OVERLAY", nil, layer)
        t:SetColorTexture(r, gr, b, 1)
        t:SetSize(w, h)
        t:SetPoint("BOTTOMLEFT", host, "BOTTOM", x, y)
    end
    ab(-4, BASE - 1, 8, 8, 0, 0.2, 0, 6)
    for i = 0, 5 do ab(-(12 - 2 * i + 2) / 2, BASE + 7 + i, 12 - 2 * i + 2, 1, 0, 0.2, 0, 6) end
    ab(-2, BASE + 13, 4, 1, 0, 0.2, 0, 6)
    ab(-3, BASE, 6, 7, 0.25, 1, 0.25, 7)
    for i = 0, 5 do ab(-(12 - 2 * i) / 2, BASE + 7 + i, 12 - 2 * i, 1, 0.25, 1, 0.25, 7) end
    arrows[btn] = g
    return g
end
local function SetArrow(g, on) if g.host then g.host:SetShown(on and true or false) end end

-- paint (or clear) the arrow on one bag button; bag and slot say which item it shows
function ns.PaintBagArrow(btn, bag, slot)
    if not btn then return end
    if dirty then Rebuild() end
    local want = bag and slot and set[bag .. ":" .. slot]
    if want then SetArrow(ArrowFor(btn), true) elseif arrows[btn] then SetArrow(arrows[btn], false) end
end
local reported
_G.Outfitter_BagArrow = function(btn, bag, slot)
    local ok, err = pcall(ns.PaintBagArrow, btn, bag, slot)
    if not ok and not reported then
        reported = true
        if ns.Issue then ns.Issue("lua", "bag arrow", tostring(err)) end
        if ns.Print then ns.Print("bag arrow failed: " .. tostring(err)) end
    end
end

-- the game's own bag frames
local function PaintDefault()
    for i = 1, 13 do
        local f = _G["ContainerFrame" .. i]
        if f and f:IsShown() then
            if f.EnumerateValidItems then
                for _, b in f:EnumerateValidItems() do
                    local bag = (b.GetBagID and b:GetBagID()) or (f.GetID and f:GetID())
                    ns.PaintBagArrow(b, bag, b:GetID())
                end
            else
                local bag = f:GetID()
                for j = 1, (f.size or 36) do
                    local b = _G["ContainerFrame" .. i .. "Item" .. j]
                    if b then ns.PaintBagArrow(b, bag, b:GetID()) end
                end
            end
        end
    end
end

local function RepaintAll()
    pcall(PaintDefault)
    local B = _G.Baggie
    if B and B.Frame and B.Frame.Refresh then pcall(B.Frame.Refresh) end
end

local pending
local function Later(delay)
    if pending then return end
    pending = true
    C_Timer.After(delay or 0.3, function()
        pending = nil
        dirty = true
        local changed = Rebuild()
        if changed then RepaintAll() end
    end)
end
ns.RefreshBagArrows = function() dirty = true Rebuild() RepaintAll() end
-- for /issues test gearhawk: which bag slots currently get an arrow, and how many buttons have one
function ns.ArrowInfo()
    if dirty then Rebuild() end
    local keys, n = {}, 0
    for k in pairs(set) do keys[#keys + 1] = k end
    table.sort(keys)
    for b in pairs(arrows) do n = n + 1 end
    return keys, n
end

local f = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "GET_ITEM_INFO_RECEIVED", "PLAYER_ENTERING_WORLD" }) do
    pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function() Later(0.3) end)

for _, name in ipairs({ "ContainerFrame_Update", "ContainerFrame_UpdateAll" }) do
    if _G[name] then hooksecurefunc(name, function() pcall(PaintDefault) end) end
end
if _G.ContainerFrameMixin and ContainerFrameMixin.UpdateItems then
    hooksecurefunc(ContainerFrameMixin, "UpdateItems", function() pcall(PaintDefault) end)
end
if _G.ContainerFrameCombinedBags and ContainerFrameCombinedBags.UpdateItems then
    hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", function() pcall(PaintDefault) end)
end
end
