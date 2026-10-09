local _, ns = ...

-- Reads an item's tooltip and turns it into numbers. English client text.
local scan = CreateFrame("GameTooltip", "OutfitterScanTip", nil, "GameTooltipTemplate")
scan:SetOwner(UIParent, "ANCHOR_NONE")

-- API wrappers: the client may have the old global functions, the C_ ones, or both.
local function Instant(link)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if f then
        local ok, a1, a2, a3, a4, a5 = pcall(f, link)
        if ok then return a1, a2, a3, a4, a5 end
    end
end
function ns.EquipLoc(link)
    if not link then return nil end
    local _, _, _, loc = Instant(link)
    if loc and loc ~= "" then return loc end
    local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if f then return select(9, f(link)) end
end
function ns.ItemIcon(link)
    if not link then return nil end
    local _, _, _, _, icon = Instant(link)
    if icon then return icon end
    if GetItemIcon then return GetItemIcon(link) end
end
-- every bag slot as { bag, slot, link }
function ns.BagItems()
    local out = {}
    local C = _G.C_Container
    for bag = 0, 4 do
        local n = (C and C.GetContainerNumSlots and C.GetContainerNumSlots(bag)) or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
        for slot = 1, n do
            local link
            if C and C.GetContainerItemLink then link = C.GetContainerItemLink(bag, slot) end
            if not link and C and C.GetContainerItemInfo then
                local i = C.GetContainerItemInfo(bag, slot)
                link = type(i) == "table" and i.hyperlink or nil
            end
            if not link and GetContainerItemLink then link = GetContainerItemLink(bag, slot) end
            if not link and GetContainerItemInfo then
                local _, _, _, _, _, _, l = GetContainerItemInfo(bag, slot)
                link = l
            end
            if link then out[#out + 1] = { bag = bag, slot = slot, link = link } end
        end
    end
    return out
end

local PRIMARY = { Strength = "STR", Agility = "AGI", Stamina = "STA", Intellect = "INT", Spirit = "SPI" }

local function Add(t, k, v) t[k] = (t[k] or 0) + v end

local function ParseLine(t, text)
    -- "+8 Strength"
    local n, stat = text:match("^%+(%d+) (%a+)$")
    if n and PRIMARY[stat] then Add(t, PRIMARY[stat], tonumber(n)) return end
    -- "+4 All Stats" style bonuses
    n = text:match("^%+(%d+) All Stats$")
    if n then for _, k in pairs(PRIMARY) do Add(t, k, tonumber(n)) end return end
    n = text:match("^(%d+) Armor$")
    if n then Add(t, "ARMOR", tonumber(n)) return end
    n = text:match("^(%d+) Block$")
    if n then Add(t, "BLOCKVAL", tonumber(n)) return end
    n = text:match("%(([%d%.]+) damage per second%)")
    if n then Add(t, "DPS", tonumber(n)) return end
    local body = text:match("^Equip: (.+)$")
    if not body then return end
    local v
    v = body:match("Increases attack power by (%d+)")
    if v then Add(t, "AP", tonumber(v)) return end
    v = body:match("%+(%d+) ranged Attack Power")
    if v then Add(t, "RAP", tonumber(v)) return end
    v = body:match("Increases damage and healing done by magical spells and effects by up to (%d+)")
    if v then Add(t, "SP", tonumber(v)) Add(t, "HEAL", tonumber(v)) return end
    v = body:match("Increases healing done by spells and effects by up to (%d+)")
    if v then Add(t, "HEAL", tonumber(v)) return end
    v = body:match("Increases damage done by [%a ]+ spells and effects by up to (%d+)")
    if v then Add(t, "SP", tonumber(v) * 0.6) return end            -- one school only: worth less
    v = body:match("Restores (%d+) mana per 5 sec")
    if v then Add(t, "MP5", tonumber(v)) return end
    v = body:match("Improves your chance to get a critical strike by (%d+)%%")
    if v then Add(t, "CRIT", tonumber(v)) return end
    v = body:match("Improves your chance to hit by (%d+)%%")
    if v then Add(t, "HIT", tonumber(v)) return end
    v = body:match("Improves your chance to hit with spells by (%d+)%%")
    if v then Add(t, "SPHIT", tonumber(v)) return end
    v = body:match("Improves your chance to get a critical strike with spells by (%d+)%%")
    if v then Add(t, "SPCRIT", tonumber(v)) return end
    v = body:match("Increased Defense %+(%d+)")
    if v then Add(t, "DEF", tonumber(v)) return end
    v = body:match("Improves your chance to dodge an attack by (%d+)%%")
    if v then Add(t, "DODGE", tonumber(v)) return end
    v = body:match("Improves your chance to parry an attack by (%d+)%%")
    if v then Add(t, "PARRY", tonumber(v)) return end
    v = body:match("Improves your chance to block attacks with a shield by (%d+)%%")
    if v then Add(t, "BLOCK", tonumber(v)) return end
    v = body:match("Increases the block value of your shield by (%d+)")
    if v then Add(t, "BLOCKVAL", tonumber(v)) return end
end

local function IsRed(r, g, b) return r and r > 0.9 and g < 0.2 and b < 0.2 end

-- Returns { stats = {...}, unusable = text or nil, reqLevel = n or nil } for an item link.
function ns.ReadItem(link)
    if not link then return nil end
    local c = ns.cache and ns.cache[link]
    if c then return c end
    scan:ClearLines()
    scan:SetOwner(UIParent, "ANCHOR_NONE")
    scan:SetHyperlink(link)
    if scan:NumLines() < 2 then return nil end        -- item data not loaded yet; try again later
    local res = { stats = {} }
    for i = 2, scan:NumLines() do
        local left = _G["OutfitterScanTipTextLeft" .. i]
        local text = left and left:GetText()
        if text and text ~= "" then
            local r, g, b = left:GetTextColor()
            if IsRed(r, g, b) then
                local lvl = text:match("Requires Level (%d+)")
                if lvl then res.reqLevel = tonumber(lvl) else res.unusable = res.unusable or text end
            else
                ParseLine(res.stats, text)
            end
            local right = _G["OutfitterScanTipTextRight" .. i]
            local rt = right and right:GetText()
            if rt and rt ~= "" then
                local rr, rg, rb = right:GetTextColor()
                if IsRed(rr, rg, rb) and not rt:find("Requires") then res.unusable = res.unusable or rt end
            end
        end
    end
    if ns.cache then ns.cache[link] = res end
    return res
end

function ns.Score(stats, w)
    local s = 0
    for k, v in pairs(stats) do
        local x = w[k]
        if x then s = s + v * x end
    end
    return s
end

-- Which inventory slot ids an item can go in.
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = {}, INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
    INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
ns.SLOT_NAMES = { [1] = "Head", [2] = "Neck", [3] = "Shoulders", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
    [9] = "Wrists", [10] = "Hands", [11] = "Ring", [12] = "Ring", [13] = "Trinket", [14] = "Trinket", [15] = "Back",
    [16] = "Main hand", [17] = "Off hand", [18] = "Ranged" }

local function ItemScore(link, w)
    local r = ns.ReadItem(link)
    return r and ns.Score(r.stats, w) or 0
end

-- Compare one item to what is worn. Returns a result table or nil if it is not gear.
-- { gain = percent (positive = better), slot = id, worn = link, score, wornScore, unusable, reqLevel, tooHigh }
function ns.Compare(link)
    local spec = ns.Spec()
    if not spec or not link then return nil end
    local equipLoc = ns.EquipLoc(link)
    local slots = equipLoc and SLOTS[equipLoc]
    if not slots or #slots == 0 then return nil end
    local info = ns.ReadItem(link)
    if not info then return nil end
    local w = spec.w
    local score = ns.Score(info.stats, w)
    local level = UnitLevel("player") or 1
    local res = { score = score, unusable = info.unusable, reqLevel = info.reqLevel, equipLoc = equipLoc }
    if info.reqLevel and info.reqLevel > level then res.tooHigh = info.reqLevel end

    -- what it would replace: an empty slot first, otherwise the worn item that scores lowest
    local worn, wornScore, wornSlot
    if equipLoc == "INVTYPE_2HWEAPON" then
        local a, b = GetInventoryItemLink("player", 16), GetInventoryItemLink("player", 17)
        wornScore = (a and ItemScore(a, w) or 0) + (b and ItemScore(b, w) or 0)
        worn, wornSlot = a or b, 16
    else
        local bestKey
        if equipLoc == "INVTYPE_WEAPON" then
            -- a one-hander only goes in the off hand if you already dual wield
            local oh = GetInventoryItemLink("player", 17)
            local ohLoc = oh and ns.EquipLoc(oh)
            if ohLoc ~= "INVTYPE_WEAPON" and ohLoc ~= "INVTYPE_WEAPONOFFHAND" then slots = { 16 } end
        end
        for _, s in ipairs(slots) do
            local l = GetInventoryItemLink("player", s)
            local key = l and ItemScore(l, w) or -1               -- -1: empty slot wins
            if bestKey == nil or key < bestKey then
                bestKey, worn, wornSlot = key, l, s
                wornScore = l and key or 0
            end
        end
    end
    wornScore = wornScore or 0
    res.worn, res.wornScore, res.slot = worn, wornScore, wornSlot or slots[1]
    if wornScore <= 0 then res.gain = score > 0 and 100 or 0
    else res.gain = (score - wornScore) / wornScore * 100 end
    res.empty = (worn == nil)
    for sl = 1, 19 do
        if GetInventoryItemLink("player", sl) == link then res.isWorn = true end
    end
    return res
end

-- Keeps only the best candidates per equipment slot (rings and trinkets: two, everything else: one).
-- The list must already be sorted best first.
local GROUP = { [12] = 11, [14] = 13 }
local function BestPerSlot(list)
    local out, count = {}, {}
    for _, e in ipairs(list) do
        local g = GROUP[e.slot] or e.slot
        count[g] = (count[g] or 0) + 1
        local cap = (g == 11 or g == 13) and 2 or 1
        if count[g] <= cap then out[#out + 1] = e end
    end
    return out
end

-- Everything in the bags that is better than what you wear, best first.
function ns.FindUpgrades()
    local out = {}
    for _, it in ipairs(ns.BagItems()) do
        local link = it.link
        local r = ns.Compare(link)
        if r and r.gain and r.gain >= (ns.db.minGain or 3) and not r.unusable then
            r.link, r.bag, r.bagSlot = link, it.bag, it.slot
            out[#out + 1] = r
        end
    end
    table.sort(out, function(a, b)
        local ah, bh = a.tooHigh and 1 or 0, b.tooHigh and 1 or 0
        if ah ~= bh then return ah < bh end
        return a.gain > b.gain
    end)
    return BestPerSlot(out)
end

ns.BestPerSlot = BestPerSlot

-- Every equipped item with a score, for the "Equipped" view.
function ns.EquippedScores()
    local spec = ns.Spec()
    local out = {}
    if not spec then return out end
    for s = 1, 18 do
        if s ~= 4 then
            local l = GetInventoryItemLink("player", s)
            out[#out + 1] = { slot = s, link = l, score = l and ItemScore(l, spec.w) or 0 }
        end
    end
    return out
end

-- Extra candidates read from Profiteer's saved data (if it is installed): gear your characters can
-- craft, and gear sitting in your other characters' bags and bank. Works for every class.
local function ShortChar(k) return (tostring(k):match("^[^-]+")) or tostring(k) end

local function DynamicSources(have, known)
    local out = {}
    local db = _G.ProfiteerDB
    if type(db) ~= "table" then return out end
    local me = UnitName and UnitName("player")
    local names = type(db.names) == "table" and db.names or {}
    local function nameOf(id, fallback)
        return names[id] or fallback or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or ("item " .. id)
    end
    local function add(id, name, how, where)
        if type(id) ~= "number" or have[id] or known[id] then return end
        if not ns.EquipLoc("item:" .. id) then return end        -- not wearable
        known[id] = true
        out[#out + 1] = { id, nameOf(id, name), 1, how, where, "" }
    end
    -- bags and bank of your other characters
    for ck, inv in pairs(type(db.inventory) == "table" and db.inventory or {}) do
        if ShortChar(ck) ~= me and type(inv) == "table" then
            for _, where in ipairs({ "bags", "bank" }) do
                for id in pairs(type(inv[where]) == "table" and inv[where] or {}) do
                    add(id, nil, "alt", ("in %s's %s"):format(ShortChar(ck), where))
                end
            end
        end
    end
    -- gear your characters know how to make
    for ck, profs in pairs(type(db.recipes) == "table" and db.recipes or {}) do
        for prof, recs in pairs(type(profs) == "table" and profs or {}) do
            for _, r in ipairs(type(recs) == "table" and recs or {}) do
                add(r.id, r.name, "crafted", ("%s - %s knows the recipe"):format(prof, ShortChar(ck)))
            end
        end
    end
    return out
end

-- Known gear that would beat what you wear, best first: the built-in lists for the cloth casters,
-- plus gear your other characters hold or can craft (any class).
-- Returns list, pending (items whose data the game has not sent yet), checked.
function ns.FindSources()
    local out, pending, checked = {}, 0, 0
    local group = ns.SourceClasses and ns.SourceClasses[ns.Class() or ""]
    local static = group and ns.Sources and ns.Sources[group] or {}
    local level = UnitLevel("player") or 1
    local have, known = {}, {}
    for _, it in ipairs(ns.BagItems()) do
        local id = tonumber((it.link or ""):match("item:(%d+)"))
        if id then have[id] = true end
    end
    for sl = 1, 19 do
        local l = GetInventoryItemLink("player", sl)
        local id = l and tonumber(l:match("item:(%d+)"))
        if id then have[id] = true end
    end
    local list = {}
    for _, e in ipairs(static) do known[e[1]] = true list[#list + 1] = e end
    for _, e in ipairs(DynamicSources(have, known)) do list[#list + 1] = e end
    for _, e in ipairs(list) do
        local id, name, req, how, where, note = e[1], e[2], e[3], e[4], e[5], e[6]
        if not have[id] and req <= level then
            checked = checked + 1
            local link = "item:" .. id
            local r = ns.Compare(link)
            if r == nil then
                if ns.EquipLoc(link) then pending = pending + 1 end
            elseif (r.empty or (r.gain and r.gain >= (ns.db.minGain or 3))) and not r.unusable and not r.tooHigh then
                r.link, r.name, r.req, r.how, r.where, r.note, r.id = link, name, req, how, where, note, id
                if r.empty then r.gain = 1000 + (r.score or 0) end
                out[#out + 1] = r
            end
        end
    end
    table.sort(out, function(a, b)
        local ah, bh = a.note ~= "" and 1 or 0, b.note ~= "" and 1 or 0     -- faction-unsure quests last
        if ah ~= bh then return ah < bh end
        return a.gain > b.gain
    end)
    return BestPerSlot(out), pending, checked
end

function ns.SlotsFor(loc)
    local t = SLOTS[loc]
    return t and #t > 0 and t or nil
end
