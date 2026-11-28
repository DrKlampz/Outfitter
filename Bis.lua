-- Best in slot: pick a class, a spec and a level and see the best gear for every slot, every weapon type and the ranged
-- slot, ranked with the same scoring Gearhawk uses on your own gear (each item's real tooltip, the spec's weights).
-- The candidate items per class and slot come from BisData.lua (data from ForeverDB.net, https://foreverdb.net).
local _, ns = ...
local Bis = {}
ns.BisUI = Bis

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local CLASS_NAME = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }
-- the level at which a class can dual wield (Shaman by talent)
local DW_FROM = { ROGUE = 10, WARRIOR = 20, HUNTER = 20, SHAMAN = 40 }

local SLOTS = {
    { "head", "Head", 3 }, { "neck", "Neck", 3 }, { "shoulder", "Shoulders", 3 }, { "back", "Back", 3 }, { "chest", "Chest", 3 },
    { "wrist", "Wrists", 3 }, { "hands", "Hands", 3 }, { "waist", "Waist", 3 }, { "legs", "Legs", 3 }, { "feet", "Feet", 3 },
    { "finger", "Rings", 4 }, { "trinket", "Trinkets", 4 },
}
-- weapon groups: pool, heading, how many of each weapon type to list
local WEAPONS = {
    { "2h", "Two-hand weapons" }, { "mh", "One-hand weapons" }, { "oh", "Off hand: shields, held items and weapons" }, { "ranged", "Ranged: bows, guns, crossbows, wands, thrown" },
}

local function b36(s) return tonumber(s, 36) end

---------------------------------------------------------------------------
-- The data
---------------------------------------------------------------------------
local decoded = {}
local function Pool(class, key)
    local c = decoded[class]
    if not c then c = {} decoded[class] = c end
    if c[key] then return c[key] end
    local text = ns.Bis and ns.Bis.pools and ns.Bis.pools[class] and ns.Bis.pools[class][key]
    local list = {}
    for id, lv in (text or ""):gmatch("(%w+):(%w+)") do list[#list + 1] = { b36(id), b36(lv) } end
    c[key] = list
    return list
end

local itemLines
local function ItemRecord(id)
    if not itemLines then
        itemLines = {}
        for line in (ns.Bis and ns.Bis.itemText or ""):gmatch("[^\n]+") do
            local k = line:match("^(%w+)|")
            if k then itemLines[b36(k)] = line end
        end
    end
    local line = itemLines[id]
    if not line then return nil end
    local _, side, twin, src = strsplit("|", line)
    local rec = { side = side or "", twin = tonumber(twin or "") , srcs = {} }
    for s in ((src or "") .. "~"):gmatch("(.-)~") do
        if s ~= "" then
            local kind, text, sd = strsplit("^", s)
            rec.srcs[#rec.srcs + 1] = { kind = kind, text = text, side = sd or "" }
        end
    end
    return rec
end

local function MapName(m)
    local info = m and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(tonumber(m))
    return type(info) == "table" and info.name or nil
end

-- where an item comes from, in words, for the chosen faction
local function SourceText(rec, side)
    if not rec or #rec.srcs == 0 then return "Where it comes from is not known yet" end
    local out = {}
    for _, s in ipairs(rec.srcs) do
        if s.side == "" or s.side == side or s.side == nil then
            local t = s.text or ""
            local name, map = t:match("^(.-)@(%d+)$")
            if name then
                local z = MapName(map)
                t = name .. (z and (", " .. z) or "")
            end
            out[#out + 1] = t
            if #out >= 2 then break end
        end
    end
    if #out == 0 then return "Where it comes from is not known yet" end
    return table.concat(out, "   |   ")
end

---------------------------------------------------------------------------
-- Loading item data. The game gives an item's tooltip only once it has the item; ask for each one and read them as they come.
---------------------------------------------------------------------------
local asked = {}
local pendingAsk = {}
local function Now() return (GetTime and GetTime()) or 0 end
local function Ask(id)
    if asked[id] then return end
    asked[id] = Now()
    pendingAsk[#pendingAsk + 1] = id
end
-- an item the game still has not given after a few seconds is not in this client: stop waiting for it
local function Gone(id) return asked[id] and Now() - asked[id] > 8 end
local function Link(id) return "item:" .. id end
-- has the game got this item's data yet? (an item it has not loaded reads as an empty tooltip)
local function Cached(id)
    if C_Item and C_Item.IsItemDataCachedByID then
        local ok, v = pcall(C_Item.IsItemDataCachedByID, id)
        if ok and type(v) == "boolean" then return v end
    end
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if fn then
        local ok, name = pcall(fn, id)
        return ok and name ~= nil
    end
    return true
end
local function Stats(id)
    if not Cached(id) then return nil end
    local ok, r = pcall(ns.ReadItem, Link(id))
    if ok then return r end
end

---------------------------------------------------------------------------
-- Ranking
---------------------------------------------------------------------------
local state = { class = nil, spec = 1, level = 1, side = "a" }
local result = nil          -- { rows = {...}, loaded, total, done }
local dirty = true
local scoreCache = {}

local subCache = {}
local function SubType(id)
    local hit = subCache[id]
    if hit then return hit[1], hit[2] end
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not f then return "" end
    local ok, _, _, sub, loc = pcall(f, id)
    if ok and type(sub) == "string" then subCache[id] = { sub, loc } return sub, loc end
    return ""
end

-- the ids to rank for a slot pool at the chosen level and faction
local function Candidates(class, key, level, side)
    local out, seen = {}, {}
    for _, e in ipairs(Pool(class, key)) do
        local id, lv = e[1], e[2]
        if lv <= level and not seen[id] then
            seen[id] = true
            local rec = ItemRecord(id)
            local shown = id
            local ok = true
            if rec and rec.side ~= "" and rec.side ~= side then
                if rec.twin then shown = rec.twin else ok = false end
            end
            if ok then out[#out + 1] = { id = shown, base = id, lv = lv } end
        end
    end
    return out
end

local function Mine(class)
    if not (UnitClass and select(2, UnitClass("player")) == class) then return nil end
    local worn, bag = {}, {}
    for s = 1, 19 do
        local l = GetInventoryItemLink("player", s)
        local id = l and tonumber(l:match("item:(%d+)"))
        if id then worn[id] = true end
    end
    for _, it in ipairs(ns.BagItems()) do
        local id = tonumber(it.link:match("item:(%d+)"))
        if id then bag[id] = true end
    end
    return worn, bag
end

-- scored candidates of one pool, best first; counts how many are still unread
local function Rank(class, spec, key, level, side)
    local w = spec.w
    local list, unread = {}, 0
    for _, c in ipairs(Candidates(class, key, level, side)) do
        local r = Stats(c.id)
        if not r then
            Ask(c.id)
            if not Gone(c.id) then unread = unread + 1 end
        else
            local sc = ns.Score(r.stats, (ns.WeightsForItem and ns.WeightsForItem(Link(c.id), w)) or w)
            if sc and sc > 0 then
                c.score = sc
                c.sub, c.loc = SubType(c.id)
                list[#list + 1] = c
            end
        end
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.id < b.id
    end)
    return list, unread
end

local function Compute()
    local class, level, side = state.class, state.level, state.side
    local specs = ns.Weights and ns.Weights[class]
    local spec = specs and specs[state.spec] or (specs and specs[1])
    if not spec then result = { rows = {}, unread = 0, total = 0 } return end
    ns.sim = { class = class, level = level }
    local ok, err = pcall(function()
        local worn, bag = Mine(class)
        local rows, unread, total = {}, 0, 0
        local function add(r) rows[#rows + 1] = r end
        local best = {}
        for _, s in ipairs(SLOTS) do
            local list, un = Rank(class, spec, s[1], level, side)
            unread = unread + un
            total = total + #list + un
            add({ kind = "head", text = s[2] })
            for i = 1, math.min(s[3], #list) do
                local c = list[i]
                add({ kind = "item", c = c, best = list[1].score, rank = i })
            end
            if #list == 0 then add({ kind = "none", text = un > 0 and "Reading items..." or "Nothing for this level yet" }) end
        end
        -- weapons: the best of each weapon type, then the best sets
        local top = {}
        for _, wdef in ipairs(WEAPONS) do
            local list, un = Rank(class, spec, wdef[1], level, side)
            unread = unread + un
            total = total + #list + un
            top[wdef[1]] = list
            add({ kind = "head", text = wdef[2] })
            local seenType, n = {}, 0
            for _, c in ipairs(list) do
                local t = c.sub ~= "" and c.sub or "Other"
                if not seenType[t] then
                    seenType[t] = true
                    n = n + 1
                    add({ kind = "item", c = c, best = list[1].score, rank = n, typeName = t })
                end
            end
            if #list == 0 then
                add({ kind = "none", text = un > 0 and "Reading items..." or ((class == "ROGUE" and wdef[1] == "2h") and "Not usable by this class" or "Nothing for this class or level") })
            end
        end
        -- the weapon sets
        local sets = {}
        local function first(l, skip)
            for _, c in ipairs(l or {}) do if c ~= skip then return c end end
        end
        local two = first(top["2h"])
        local mh = first(top["mh"])
        local oh
        for _, c in ipairs(top["oh"] or {}) do
            local t = c.sub or ""
            if not (t:find("Axes") or t:find("Swords") or t:find("Maces") or t:find("Daggers") or t:find("Fist")) then oh = c break end
        end
        local ohWeapon
        local dwAt = DW_FROM[class]
        if dwAt and level >= dwAt and mh then
            for _, c in ipairs(top["mh"] or {}) do if c ~= mh then ohWeapon = c break end end
        end
        local out = {}
        if two then out[#out + 1] = { name = "Two-hand", a = two, total = two.score } end
        if mh and oh then out[#out + 1] = { name = "One-hand + shield or held item", a = mh, b = oh, total = mh.score + oh.score } end
        if mh and ohWeapon then out[#out + 1] = { name = "Dual wield", a = mh, b = ohWeapon, total = mh.score + ohWeapon.score } end
        local noTwo = (spec.role == "tank" or spec.role == "healer") and ns.Armor and ns.Armor[class] and ns.Armor[class].Shield
        local bestSet
        for _, s in ipairs(out) do
            s.blocked = noTwo and s.name == "Two-hand"
            if not s.blocked and (not bestSet or s.total > bestSet.total) then bestSet = s end
        end
        if #out > 0 then
            table.insert(rows, 1, { kind = "head", text = "Weapon sets (best of each, added up)" })
            local at = 2
            for _, s in ipairs(out) do
                table.insert(rows, at, { kind = "set", s = s, best = s == bestSet })
                at = at + 1
            end
        end
        -- own gear markers
        if worn then
            for _, r in ipairs(rows) do
                if r.kind == "item" then r.mine = worn[r.c.id] and "worn" or (bag[r.c.id] and "in bags") end
                if r.kind == "set" then
                    local a = worn[r.s.a.id] and "worn" or (bag[r.s.a.id] and "in bags")
                    r.s.mine = a
                end
            end
        end
        result = { rows = rows, unread = unread, total = total, spec = spec }
    end)
    ns.sim = nil
    if not ok then
        result = { rows = {}, unread = 0, total = 0, err = tostring(err) }
        if ns.Issue then ns.Issue("lua", "Best in slot", err) end
    end
    dirty = false
end

function Bis.Result() return result end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local frame
local ROWS, ROW_H = 14, 32
local rows = {}

local function Button(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

local function ItemText(id)
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if fn then
        local ok, name, link = pcall(fn, id)
        if ok and type(link) == "string" then return link end
        if ok and type(name) == "string" then return name end
    end
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return "Item " .. id
end

local function Fmt(n) return ("%.1f"):format(n) end

local function Fill()
    if not (frame and frame:IsShown()) then return end
    if dirty or not result then Compute() end
    local specs = ns.Weights[state.class] or {}
    local spec = specs[state.spec] or specs[1]
    frame.classBtn:SetText(CLASS_NAME[state.class] or "?")
    frame.specBtn:SetText(spec and spec.name or "?")
    frame.sideBtn:SetText(state.side == "h" and "Horde" or "Alliance")
    frame.levelBox:SetText(tostring(state.level))
    local un = result and result.unread or 0
    if un > 0 then
        frame.status:SetText(("Reading item data... %d items to go. The list fills in as they arrive."):format(un))
    elseif result and result.err then
        frame.status:SetText("|cffff5555Something went wrong; it is in the issue log.|r")
    else
        frame.status:SetText(("Best gear for a level %d %s %s. Scored from each item's real tooltip with the spec's weights."):format(state.level, spec and spec.name or "", CLASS_NAME[state.class] or ""))
    end
    local list = (result and result.rows) or {}
    local offset = FauxScrollFrame_GetOffset(frame.scroll)
    FauxScrollFrame_Update(frame.scroll, #list, ROWS, ROW_H)
    for i = 1, ROWS do
        local row, e = rows[i], list[i + offset]
        if not e then
            row:Hide()
        else
            row:Show()
            row.link = nil
            row.icon:Hide()
            row.sub:SetText("")
            row.note:SetText("")
            if e.kind == "head" then
                row.name:ClearAllPoints()
                row.name:SetPoint("LEFT", 4, 0)
                row.name:SetText("|cffffd100" .. e.text .. "|r")
            elseif e.kind == "none" then
                row.name:ClearAllPoints()
                row.name:SetPoint("LEFT", 14, 0)
                row.name:SetText("|cff888888" .. e.text .. "|r")
            elseif e.kind == "set" then
                local s = e.s
                row.name:ClearAllPoints()
                row.name:SetPoint("TOPLEFT", 14, -3)
                row.name:SetText((s.blocked and "|cff888888" or (e.best and "|cff40ff40" or "|cffffffff")) .. s.name .. "|r")
                row.sub:SetText(ItemText(s.a.id) .. (s.b and ("  +  " .. ItemText(s.b.id)) or ""))
                row.note:SetText((s.blocked and "|cff888888not for this spec  |r" or "") .. Fmt(s.total))
                row.link = Link(s.a.id)
            else
                local c = e.c
                row.icon:Show()
                row.icon:SetTexture(ns.ItemIcon(Link(c.id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.name:ClearAllPoints()
                row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)
                row.name:SetText(ItemText(c.id))
                local rec = ItemRecord(c.base)
                local srcRec = ItemRecord(c.id) or rec
                row.sub:SetText((e.typeName and ("|cff9ab8ff" .. e.typeName .. "|r  ") or "") .. SourceText(srcRec, state.side))
                local pct = e.best > 0 and math.floor(c.score / e.best * 100 + 0.5) or 100
                row.note:SetText(("%s%s  |cffaaaaaaLv %d  %s%s|r"):format(e.mine and ("|cff40ff40" .. e.mine .. "|r  ") or "", "", c.lv, Fmt(c.score), pct < 100 and ("  " .. pct .. "%") or ""))
                row.link = Link(c.id)
            end
        end
    end
end

function Bis.Refresh() dirty = true Fill() end

local function Reset()
    result = nil
    dirty = true
    Fill()
end

local function SetLevel(n)
    n = math.max(1, math.min((ns.Bis and ns.Bis.cap) or 60, math.floor(tonumber(n) or state.level)))
    state.level = n
    Reset()
end

local function PopMenu(anchor, entries, onPick)
    local m = frame.menu
    if m:IsShown() and m.anchor == anchor then m:Hide() return end
    m.anchor = anchor
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
    for i, e in ipairs(entries) do
        local b = m.items[i]
        if not b then
            b = CreateFrame("Button", nil, m)
            b:SetSize(150, 20)
            b:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
            b.t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            b.t:SetPoint("LEFT", 8, 0)
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            b:SetScript("OnClick", function(self) m:Hide() if self.pick then self.pick(self.value) end end)
            m.items[i] = b
        end
        b.value, b.pick = e.value, onPick
        b.t:SetText(e.text)
        b:Show()
    end
    for i = #entries + 1, #m.items do m.items[i]:Hide() end
    m:SetSize(150, #entries * 20)
    m:Show()
end

local function Build()
    if frame then return end
    frame = ns.WinLook.NewWindow("GearhawkBisFrame", 640, 600, "Gearhawk: best in slot")
    ns.WinLook.Attach("bis", frame)
    frame:SetPoint("CENTER", 80, 0)
    frame:SetFrameStrata("HIGH")

    frame.classBtn = Button(frame, "", 100, function(self)
        local e = {}
        for _, c in ipairs(CLASSES) do e[#e + 1] = { text = CLASS_NAME[c], value = c } end
        PopMenu(self, e, function(c)
            state.class, state.spec = c, 1
            Reset()
        end)
    end)
    frame.classBtn:SetPoint("TOPLEFT", 14, -34)
    frame.specBtn = Button(frame, "", 130, function(self)
        local e = {}
        for i, sp in ipairs(ns.Weights[state.class] or {}) do e[#e + 1] = { text = sp.name .. " |cff999999" .. sp.role .. "|r", value = i } end
        PopMenu(self, e, function(i) state.spec = i Reset() end)
    end)
    frame.specBtn:SetPoint("LEFT", frame.classBtn, "RIGHT", 4, 0)
    frame.sideBtn = Button(frame, "", 80, function()
        state.side = state.side == "h" and "a" or "h"
        Reset()
    end)
    frame.sideBtn:SetPoint("LEFT", frame.specBtn, "RIGHT", 4, 0)

    local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("LEFT", frame.sideBtn, "RIGHT", 14, 0)
    lbl:SetText("Level")
    local minus = Button(frame, "-", 22, function() SetLevel(state.level - 1) end)
    minus:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
    frame.levelBox = CreateFrame("EditBox", "GearhawkBisLevel", frame, "InputBoxTemplate")
    frame.levelBox:SetSize(32, 20) frame.levelBox:SetPoint("LEFT", minus, "RIGHT", 8, 0)
    frame.levelBox:SetAutoFocus(false) frame.levelBox:SetNumeric(true) frame.levelBox:SetMaxLetters(2)
    frame.levelBox:SetScript("OnEnterPressed", function(self) SetLevel(self:GetText()) self:ClearFocus() end)
    frame.levelBox:SetScript("OnEscapePressed", function(self) self:SetText(tostring(state.level)) self:ClearFocus() end)
    local plus = Button(frame, "+", 22, function() SetLevel(state.level + 1) end)
    plus:SetPoint("LEFT", frame.levelBox, "RIGHT", 4, 0)

    -- quick level steps and "my level"
    local x = 14
    for _, n in ipairs({ 10, 20, 30, 40, 50, 60 }) do
        local b = Button(frame, tostring(n), 36, function() SetLevel(n) end)
        b:SetPoint("TOPLEFT", x, -62)
        x = x + 38
    end
    local mine = Button(frame, "My character", 100, function()
        local _, c = UnitClass("player")
        state.class, state.level = c, UnitLevel("player") or 1
        state.side = (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "h" or "a"
        state.spec = ns.SpecIndex and ns.SpecIndex() or 1
        Reset()
    end)
    mine:SetPoint("TOPLEFT", x + 6, -62)

    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.status:SetPoint("TOPLEFT", 16, -90) frame.status:SetWidth(600) frame.status:SetJustifyH("LEFT")

    local menu = CreateFrame("Frame", nil, frame)
    menu:SetFrameStrata("DIALOG") menu:SetFrameLevel(50)
    menu.bg = menu:CreateTexture(nil, "BACKGROUND") menu.bg:SetAllPoints() menu.bg:SetColorTexture(0.05, 0.05, 0.08, 0.97)
    menu.items = {}
    menu:Hide()
    frame.menu = menu

    frame.scroll = CreateFrame("ScrollFrame", "GearhawkBisScroll", frame, "FauxScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 10, -108)
    frame.scroll:SetSize(590, ROWS * ROW_H)
    frame.scroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, Fill) end)
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, frame)
        r:SetSize(590, ROW_H)
        r:SetPoint("TOPLEFT", 12, -108 - (i - 1) * ROW_H)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(24, 24) r.icon:SetPoint("LEFT", 8, 0) r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.name:SetWidth(330) r.name:SetJustifyH("LEFT") r.name:SetWordWrap(false) r.name:SetMaxLines(1)
        r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -1) r.sub:SetWidth(430) r.sub:SetJustifyH("LEFT") r.sub:SetWordWrap(false) r.sub:SetMaxLines(1)
        r.note = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.note:SetPoint("TOPRIGHT", -4, -4) r.note:SetWidth(240) r.note:SetJustifyH("RIGHT")
        r:SetScript("OnEnter", function(self)
            if self.link and GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.link)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        r:SetScript("OnClick", function(self)
            if self.link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
                local id = tonumber(self.link:match("item:(%d+)"))
                local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
                local ok, _, link = pcall(fn, id)
                if ok and link then ChatEdit_InsertLink(link) end
            end
        end)
        rows[i] = r
    end

    -- ask for item data a few at a time, and read what has arrived
    local acc = 0
    frame:SetScript("OnUpdate", function(self, dt)
        acc = acc + dt
        if acc < 0.25 then return end
        acc = 0
        local n = 0
        while pendingAsk[1] and n < 80 do
            local id = table.remove(pendingAsk, 1)
            if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
            n = n + 1
        end
        if result and result.unread and result.unread > 0 then dirty = true Fill() end
    end)
    frame:SetScript("OnShow", function() menu:Hide() dirty = true Fill() end)
    frame:Hide()
end

local function Init()
    if state.class then return end
    local _, c = UnitClass("player")
    state.class = c
    state.level = UnitLevel("player") or 1
    state.side = (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "h" or "a"
    state.spec = ns.SpecIndex and ns.SpecIndex() or 1
end

function ns.ToggleBis()
    Init()
    Build()
    frame:SetShown(not frame:IsShown())
end
function ns.OpenBis(class, level)
    Init()
    Build()
    if class then state.class, state.spec = class, 1 end
    if level then state.level = level end
    frame:Show()
    Reset()
end

-- when item data lands, redo the ranking
local ev = CreateFrame("Frame")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:SetScript("OnEvent", function() if frame and frame:IsShown() and result and result.unread and result.unread > 0 then dirty = true end end)

ns.BisInternals = { Candidates = Candidates, Rank = Rank, Compute = Compute, state = state, SLOTS = SLOTS, Pool = Pool, ItemRecord = ItemRecord, SourceText = SourceText }
