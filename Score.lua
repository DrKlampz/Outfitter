local _, ns = ...

local function Loaded(name)
    local f = (_G.C_AddOns and _G.C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
    if not f then return false end
    local ok, v = pcall(f, name)
    return ok and v and true or false
end

-- Reads an item's tooltip and turns it into numbers. English client text.
local scan = CreateFrame("GameTooltip", "GearhawkScanTip", nil, "GameTooltipTemplate")
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
    -- the game already adds enchants and gems into the item's stat lines (the "Enchanted: ..." line
    -- only describes them), so counting them again would double the value
    if text:match("^Enchanted: ") or text:match("^Socket Bonus: ") then return end
    -- the game writes big numbers with a thousands comma ("1,548 Armor"); without this the armor line was missed
    text = text:gsub("(%d),(%d%d%d)", "%1%2")
    -- plain suffix/enchant forms
    do
        local n3, sch = text:match("^%+(%d+) (%a+) Spell Damage$")
        if n3 and sch ~= "Healing" then Add(t, "SP_" .. sch:upper(), tonumber(n3)) return end
        n3 = text:match("^%+(%d+) Spell Damage$") or text:match("^%+(%d+) Spell Power$")
        if n3 then Add(t, "SP", tonumber(n3)) Add(t, "HEAL", tonumber(n3)) return end
        n3, sch = text:match("^%+(%d+) (%a+) Damage$")
        if n3 and (sch == "Fire" or sch == "Frost" or sch == "Shadow" or sch == "Nature" or sch == "Arcane" or sch == "Holy") then
            Add(t, "SP_" .. sch:upper(), tonumber(n3)) return
        end
        n3 = text:match("^%+(%d+) Healing Spells$") or text:match("^%+(%d+) Healing$")
        if n3 then Add(t, "HEAL", tonumber(n3)) return end
        n3 = text:match("^%+(%d+) Damage and Healing Spells$")
        if n3 then Add(t, "SP", tonumber(n3)) Add(t, "HEAL", tonumber(n3)) return end
        n3 = text:match("^%+(%d+) [Mm]ana every 5 sec") or text:match("^Mana Regen %+(%d+)")
        if n3 then Add(t, "MP5", tonumber(n3)) return end
        n3 = text:match("^%+(%d+) Attack Power$")
        if n3 then Add(t, "AP", tonumber(n3)) return end
    end
    -- "+8 Strength"
    local n, stat = text:match("^%+(%d+) (%a+)$")
    if n and PRIMARY[stat] then Add(t, PRIMARY[stat], tonumber(n)) return end
    -- "+4 All Stats" style bonuses
    n = text:match("^%+(%d+) All Stats$")
    if n then for _, k in pairs(PRIMARY) do Add(t, k, tonumber(n)) end return end
    n = text:match("^(%d+) Armor")
    if n then Add(t, "ARMOR", tonumber(n)) return end
    n = text:match("^(%d+) Block$")
    if n then Add(t, "BLOCKVAL", tonumber(n)) return end
    n = text:match("%(([%d%.]+) damage per second%)")
    if n then Add(t, "DPS", tonumber(n)) return end
    local body = text:match("^Equip: (.+)$")
    if not body then return end
    local v
    -- conditional bonuses ("... when fighting Undead") are not part of normal play
    if body:find("when fighting") or body:find("against ") then return end
    local hv, dv = body:match("Increases healing done by up to (%d+) and damage done by up to (%d+) for all magical spells")
    if hv then Add(t, "HEAL", tonumber(hv)) Add(t, "SP", tonumber(dv)) return end
    v = body:match("Increases attack power by (%d+)") or body:match("^%+(%d+) Attack Power")
    if v then Add(t, "AP", tonumber(v)) return end
    v = body:match("Increases ranged attack power by (%d+)")
    if v then Add(t, "RAP", tonumber(v)) return end
    v = body:match("%+(%d+) ranged Attack Power")
    if v then Add(t, "RAP", tonumber(v)) return end
    v = body:match("Increases damage and healing done by magical spells and effects by up to (%d+)")
    if v then Add(t, "SP", tonumber(v)) Add(t, "HEAL", tonumber(v)) return end
    v = body:match("Increases healing done by spells and effects by up to (%d+)")
    if v then Add(t, "HEAL", tonumber(v)) return end
    local school
    school, v = body:match("Increases damage done by (%a+) spells and effects by up to (%d+)")
    if v then Add(t, "SP_" .. school:upper(), tonumber(v)) return end   -- one school only: worth what your spec casts from it
    v = body:match("Allows (%d+)%% of your [Mm]ana regeneration to continue while casting")
    if v then Add(t, "CASTREGEN", tonumber(v)) return end
    v = body:match("Increases your spell damage by up to (%d+)") or body:match("Increases spell power by (%d+)")
    if v then Add(t, "SP", tonumber(v)) Add(t, "HEAL", tonumber(v)) return end
    v = body:match("Restores (%d+) [Mm]ana per 5 sec")
    if v then Add(t, "MP5", tonumber(v)) return end
    v = body:match("I%a+ your chance to get a critical strike by (%d+)%%")
    if v then Add(t, "CRIT", tonumber(v)) return end
    v = body:match("I%a+ your chance to hit by (%d+)%%")
    if v then Add(t, "HIT", tonumber(v)) return end
    v = body:match("Improves your chance to hit with spells by (%d+)%%")
    if v then Add(t, "SPHIT", tonumber(v)) return end
    v = body:match("Improves your chance to get a critical strike with spells by (%d+)%%")
    if v then Add(t, "SPCRIT", tonumber(v)) return end
    v = body:match("Increased Defense %+(%d+)")
    if v then Add(t, "DEF", tonumber(v)) return end
    v = body:match("I%a+ your chance to dodge an attack by (%d+)%%")
    if v then Add(t, "DODGE", tonumber(v)) return end
    v = body:match("I%a+ your chance to parry an attack by (%d+)%%")
    if v then Add(t, "PARRY", tonumber(v)) return end
    v = body:match("I%a+ your chance to block attacks with a shield by (%d+)%%")
    if v then Add(t, "BLOCK", tonumber(v)) return end
    v = body:match("Increases the block value of your shield by (%d+)")
    if v then Add(t, "BLOCKVAL", tonumber(v)) return end
end

local function IsRed(r, g, b) return r and r > 0.9 and g < 0.2 and b < 0.2 end

-- Returns { stats = {...}, unusable = text or nil, reqLevel = n or nil } for an item link.
-- Does the player have this profession / skill at that rank? nil when the client can't tell.
local function HasSkill(name, need)
    local n = _G.GetNumSkillLines and GetNumSkillLines()
    if not n or not _G.GetSkillLineInfo then return nil end
    for i = 1, n do
        local sname, header, _, rank = GetSkillLineInfo(i)
        if not header and sname and sname:lower() == name:lower() then
            return (rank or 0) >= need
        end
    end
    return false
end

-- Weapon skills you must have learned (trainer) before a weapon is any use.
local SKILL_OF = { Sword = "Swords", Dagger = "Daggers", Staff = "Staves", Mace = "Maces", Axe = "Axes", Polearm = "Polearms",
    Bow = "Bows", Crossbow = "Crossbows", Gun = "Guns", Wand = "Wands", Thrown = "Thrown", ["Fist Weapon"] = "Fist Weapons" }
local TWO_H = { Sword = "Two-Handed Swords", Axe = "Two-Handed Axes", Mace = "Two-Handed Maces" }
local ALL_WEAPON_SKILLS = {}
for _, v in pairs(SKILL_OF) do ALL_WEAPON_SKILLS[v:lower()] = true end
for _, v in pairs(TWO_H) do ALL_WEAPON_SKILLS[v:lower()] = true end
-- returns the skill name when the character has other weapon skills but not this one (so it must be trained), else nil
local function UntrainedWeapon(rt, twoHand)
    local skill = (twoHand and TWO_H[rt]) or SKILL_OF[rt]
    if not skill or not _G.GetNumSkillLines or not _G.GetSkillLineInfo then return nil end
    local any, has = false, false
    for i = 1, GetNumSkillLines() or 0 do
        local sname, header = GetSkillLineInfo(i)
        if not header and sname then
            local l = sname:lower()
            if ALL_WEAPON_SKILLS[l] then any = true end
            if l == skill:lower() then has = true end
        end
    end
    if any and not has then return skill end
end

-- Armor types by class: the highest the class can wear from this level on.
local ARMOR_FROM = {
    MAGE = { Cloth = 1 }, WARLOCK = { Cloth = 1 }, PRIEST = { Cloth = 1 },
    ROGUE = { Cloth = 1, Leather = 1 }, DRUID = { Cloth = 1, Leather = 1 },
    HUNTER = { Cloth = 1, Leather = 1, Mail = 40 }, SHAMAN = { Cloth = 1, Leather = 1, Mail = 40, Shield = 1 },
    WARRIOR = { Cloth = 1, Leather = 1, Mail = 1, Plate = 40, Shield = 1 },
    PALADIN = { Cloth = 1, Leather = 1, Mail = 1, Plate = 40, Shield = 1 },
}

-- Weapon types each class can use at all (training aside).
local function set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
local WEAPON_TYPES = set("Axe", "Mace", "Sword", "Dagger", "Fist Weapon", "Polearm", "Staff", "Bow", "Crossbow", "Gun", "Wand", "Thrown")
local WEAPONS = {
    WARRIOR = set("Axe", "Mace", "Sword", "Dagger", "Fist Weapon", "Polearm", "Staff", "Bow", "Crossbow", "Gun", "Thrown"),
    PALADIN = set("Axe", "Mace", "Sword", "Polearm"),
    HUNTER = set("Axe", "Dagger", "Fist Weapon", "Polearm", "Staff", "Sword", "Bow", "Crossbow", "Gun", "Thrown"),
    ROGUE = set("Axe", "Dagger", "Fist Weapon", "Mace", "Sword", "Bow", "Crossbow", "Gun", "Thrown"),
    PRIEST = set("Dagger", "Mace", "Staff", "Wand"),
    SHAMAN = set("Axe", "Dagger", "Fist Weapon", "Mace", "Staff"),
    MAGE = set("Dagger", "Staff", "Sword", "Wand"),
    WARLOCK = set("Dagger", "Staff", "Sword", "Wand"),
    DRUID = set("Dagger", "Fist Weapon", "Mace", "Polearm", "Staff"),
}

-- Two-handed weapons by class (a class that has none of that kind can't use it, whatever the skill list says)
local TWO_H_CLASSES = {
    Sword = set("WARRIOR", "PALADIN", "HUNTER"),
    Axe = set("WARRIOR", "PALADIN", "HUNTER", "SHAMAN"),
    Mace = set("WARRIOR", "PALADIN", "SHAMAN", "DRUID"),
}
-- Relics: each class's own kind only
local RELIC_CLASS = { Libram = "PALADIN", Idol = "DRUID", Totem = "SHAMAN" }

-- A requirement line, whatever colour the tooltip painted it. Returns "level", n | "unusable", text | nil
local function ReadRequirement(text)
    local lvl = text:match("^Requires [Ll]evel (%d+)")
    if lvl then return "level", tonumber(lvl) end
    local skill, rank = text:match("^Requires (.-) %((%d+)%)$")
    if skill then
        local has = HasSkill(skill, tonumber(rank))
        if has == false then return "unusable", text end
        return nil
    end
    local classes = text:match("^Classes: (.+)$")
    if classes then
        local _, cls = UnitClass("player")
        local mine = (UnitClass("player") or ""):lower()
        if not classes:lower():find(mine, 1, true) then return "unusable", text end
        return nil
    end
    if text:match("^Requires ") and not text:find("^Requires [Ll]evel") then
        -- reputation, riding, honor rank and the like: only trust the tooltip's own red
        return "maybe", text
    end
end

function ns.ReadItem(link)
    if not link then return nil end
    local c = ns.cache and ns.cache[link]
    if c then return c end
    scan:ClearLines()
    scan:SetOwner(UIParent, "ANCHOR_NONE")
    scan:SetHyperlink(link)
    if scan:NumLines() < 2 then return nil end        -- item data not loaded yet; try again later
    local res = { stats = {} }
    local _, class = UnitClass("player")
    for i = 2, scan:NumLines() do
        local left = _G["GearhawkScanTipTextLeft" .. i]
        local text = left and left:GetText()
        if text and text ~= "" then
            local r, g, b = left:GetTextColor()
            local red = IsRed(r, g, b)
            local kind, v = ReadRequirement(text)
            if text == "Binds when picked up" then res.bind = "bop"
            elseif text == "Soulbound" then res.bind = "bop"
            elseif text == "Binds to account" or text == "Binds to Blizzard account" then res.bind = res.bind or "account"
            elseif text == "Binds when equipped" then res.bind = res.bind or "boe" end
            local setN, setBody = text:match("^%((%d+)%) Set: (.+)$")
            local setHead, setHave, setOf = text:match("^(.-) %((%d+)/(%d+)%)$")
            local activeBody = text:match("^Set: (.+)$")
            if activeBody then
                -- a bonus you already have shows as plain "Set: ..." with no number; they come in order, lowest first
                res.setActive = res.setActive or {}
                local at = {}
                activeBody = activeBody:gsub("%.$", "")
                ParseLine(at, activeBody:match("^[%+%d]") and activeBody or ("Equip: " .. activeBody))
                res.setActive[#res.setActive + 1] = at
            elseif setN then
                -- set bonuses are kept apart: they only matter when this piece is swapped out
                res.setBonus = res.setBonus or {}
                local bt = {}
                setBody = setBody:gsub("%.$", "")
                ParseLine(bt, setBody:match("^[%+%d]") and setBody or ("Equip: " .. setBody))
                res.setBonus[tonumber(setN)] = bt
            elseif setHead and not text:match("^%(") then
                res.setName, res.setCount, res.setTotal = setHead, tonumber(setHave), tonumber(setOf)
            elseif kind == "level" then
                res.reqLevel = v
            elseif kind == "unusable" then
                res.unusable = res.unusable or v
            elseif kind == "maybe" then
                if red then res.unusable = res.unusable or v end
            elseif red then
                res.unusable = res.unusable or text
            else
                local before = 0
                for _ in pairs(res.stats) do before = before + 1 end
                local sum0 = 0
                for _, x in pairs(res.stats) do sum0 = sum0 + x end
                ParseLine(res.stats, text)
                local sum1 = 0
                for _, x in pairs(res.stats) do sum1 = sum1 + x end
                if sum1 == sum0 and (text:match("^Equip:") or text:match("^%+%d")) then
                    res.unparsed = res.unparsed or {}
                    res.unparsed[#res.unparsed + 1] = text
                end
            end
            local right = _G["GearhawkScanTipTextRight" .. i]
            local rt = right and right:GetText()
            if rt and rt ~= "" then
                local rr, rg, rb = right:GetTextColor()
                if IsRed(rr, rg, rb) and not rt:find("Requires") then res.unusable = res.unusable or rt end
                if rt == "Wand" then res.isWand = true end
                if RELIC_CLASS[rt] and RELIC_CLASS[rt] ~= class then res.unusable = res.unusable or rt end
                if text == "Two-Hand" and TWO_H_CLASSES[rt] and not TWO_H_CLASSES[rt][class] then res.unusable = res.unusable or ("two-handed " .. rt:lower()) end
                local wp = WEAPONS[class]
                if wp and WEAPON_TYPES[rt] and not wp[rt] then res.unusable = res.unusable or rt end
                if wp and wp[rt] and not res.unusable then
                    local sk = UntrainedWeapon(rt, text == "Two-Hand")
                    if sk then res.unusable = "train " .. sk end
                end
                local allowed = ARMOR_FROM[class]
                if allowed and (rt == "Cloth" or rt == "Leather" or rt == "Mail" or rt == "Plate" or rt == "Shield") then
                    local from = allowed[rt]
                    local lv = UnitLevel("player") or 1
                    if not from or lv < from then res.unusable = res.unusable or rt end
                end
            end
        end
    end
    -- a wand is worth its damage per second to a caster (melee weapon speed means nothing to one)
    if res.isWand and res.stats.DPS then res.stats.WDPS = res.stats.DPS end
    if not res.reqLevel then
        local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        if fn then
            local ok, _, _, _, _, minLevel = pcall(fn, link)
            if ok and type(minLevel) == "number" and minLevel > 0 then res.reqLevel = minLevel end
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
    -- a pure healing item (healing power, no spell damage) has its Intellect, Spirit and mana regen
    -- budgeted for healing; a spec that doesn't heal gets only half credit for those stats
    if not w.HEAL and (stats.HEAL or 0) > 0 and (stats.SP or 0) == 0 then s = s * 0.5 end
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

-- A Hunter fights from range: weapon damage per second only matters on the ranged weapon,
-- the melee weapons are worth their stats.
local MELEE_LOC = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true }
local huntMelee = setmetatable({}, { __mode = "k" })
local RANGED_LOC = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
local lowRanged = setmetatable({}, { __mode = "k" })
local function WeightsBase(link, w)
    local loc = w.DPS and ns.EquipLoc(link) or ""
    local class = ns.Class()
    if class == "HUNTER" and MELEE_LOC[loc or ""] then
        local c = huntMelee[w]
        if not c then
            c = {}
            for k, v in pairs(w) do c[k] = v end
            c.DPS = w.DPS * 0.07
            huntMelee[w] = c
        end
        return c
    end
    -- Warriors, Rogues and the other melee classes only pull with a bow, gun or thrown weapon:
    -- its damage per second is not worth what a main hand weapon's is.
    if class ~= "HUNTER" and RANGED_LOC[loc or ""] then
        local c = lowRanged[w]
        if not c then
            c = {}
            for k, v in pairs(w) do c[k] = v end
            c.DPS = w.DPS * 0.07
            lowRanged[w] = c
        end
        return c
    end
    return w
end

-- How well you can use a weapon of this type: your trained skill against the most your level allows.
-- A dagger at skill 1 swings far worse than a sword at 58, so its damage is worth less until you train it up.
local SKILL_OF = { ["One-Handed Axes"] = "Axes", ["One-Handed Swords"] = "Swords", ["One-Handed Maces"] = "Maces" }
local skillNow, skillAt = nil, 0
local function WeaponSkills()
    local now = GetTime and GetTime() or 0
    if skillNow and now - skillAt < 5 then return skillNow end
    local saved = ns.db and ns.db.skills
    local found, any = {}, false
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, header, _, rank = GetSkillLineInfo(i)
            if name and not header and type(rank) == "number" then found[name] = rank any = true end
        end
    end
    if any and ns.db then
        ns.db.skills = ns.db.skills or {}
        for k, v in pairs(found) do ns.db.skills[k] = v end      -- remembered for when the skills window is collapsed
    end
    skillNow, skillAt = (any and found) or saved or {}, now
    return skillNow
end
local function WeaponFactor(link)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not f then return 1 end
    local ok, _, _, sub = pcall(f, link)
    if not ok or type(sub) ~= "string" then return 1 end
    local rank = WeaponSkills()[SKILL_OF[sub] or sub]
    if type(rank) ~= "number" then return 1 end
    if ns.sim then return 1 end                       -- ranking for another character: weapon skill is not theirs to judge
    local cap = math.max(5, 5 * (UnitLevel("player") or 1))
    return 0.5 + 0.5 * math.min(1, rank / cap)
end

-- Armor is worth far more at low level: the same points take a bigger bite out of the damage you take.
-- The tank weights were set for level 60 (damage taken falls by A / (A + 85 * level + 400)).
local tuned = setmetatable({}, { __mode = "k" })
local function WeightsFor(link, w)
    local base = WeightsBase(link, w)
    local lv = (ns.sim and ns.sim.level) or UnitLevel("player") or 60
    local armorK = 1
    if base.DODGE and base.ARMOR and lv < 60 then armorK = math.min(4, 5500 / (85 * lv + 400)) end
    local dpsK = 1
    local loc = base.DPS and ns.EquipLoc(link) or ""
    if base.DPS and (MELEE_LOC[loc] or RANGED_LOC[loc]) then dpsK = WeaponFactor(link) end
    if armorK == 1 and dpsK >= 0.995 then return base end
    local bucket = tuned[base]
    if not bucket then bucket = {} tuned[base] = bucket end
    local key = ("%d|%.2f"):format(lv, dpsK)
    local c = bucket[key]
    if not c then
        c = {}
        for k, v in pairs(base) do c[k] = v end
        if armorK ~= 1 then c.ARMOR = base.ARMOR * armorK end
        if dpsK ~= 1 then c.DPS = base.DPS * dpsK end
        bucket[key] = c
    end
    return c
end

ns.WeightsForItem = WeightsFor          -- the Best in slot tab ranks other classes with the same weights
local function ItemScore(link, w)
    local r = ns.ReadItem(link)
    return r and ns.Score(r.stats, WeightsFor(link, w)) or 0
end

-- levels at which a class learns to dual wield (Shaman need a talent, so they are left out)
local DUAL_WIELD_FROM = { ROGUE = 10, WARRIOR = 20, HUNTER = 20 }

-- ---------------------------------------------------------------------------------------------------------------
-- Weapon loadouts. Main hand, off hand and two-handers are not separate slots: what you carry is a pair (a sword and a
-- shield, two daggers, a staff on its own...). So weapons are judged as whole loadouts, picking the best legal pair
-- for your class, spec and level, instead of one weapon against one slot.
-- ---------------------------------------------------------------------------------------------------------------
local HAND = { INVTYPE_2HWEAPON = "two", INVTYPE_WEAPON = "either", INVTYPE_WEAPONMAINHAND = "mh",
    INVTYPE_WEAPONOFFHAND = "oh", INVTYPE_SHIELD = "oh", INVTYPE_HOLDABLE = "oh" }
local IS_WEAPON = { INVTYPE_2HWEAPON = true, INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true }
local DUAL_WIELD_SPELL = 674

local function CanDualWield(spec, level)
    if spec.role ~= "dps" then return false end
    local class = ns.Class() or ""
    local known
    local f = _G.IsPlayerSpell or _G.IsSpellKnown
    if f then
        local ok, v = pcall(f, DUAL_WIELD_SPELL)
        if ok and type(v) == "boolean" then known = v end
    end
    if known ~= nil then return known end
    return (DUAL_WIELD_FROM[class] or 99) <= level          -- no spell API: go by the level the class learns it
end

-- what class and spec allow: shield roles (Protection warrior/paladin, shield healers) never use a two-hander;
-- tanks never hold an off-hand "held" item; only some specs can dual wield
local function LoadoutContext(spec, level)
    local arm = ns.Armor and ns.Armor[ns.Class() or ""]
    local shieldRole = (spec.role == "tank" or spec.role == "healer") and arm and arm.Shield and true or false
    return { shieldRole = shieldRole, tank = spec.role == "tank" and shieldRole, dw = CanDualWield(spec, level) }
end

local function WeaponEntry(link, w, slot)
    local loc = ns.EquipLoc(link)
    local hand = loc and HAND[loc]
    if not hand then return nil end
    return { link = link, loc = loc, hand = hand, weapon = IS_WEAPON[loc] or false, score = ItemScore(link, w), slot = slot }
end

-- the weapons you wear, and what they are worth together (an illegal two-hander for a shield role counts as nothing:
-- a one-hander and a shield are what is missing)
local function WornWeapons(w, ctx)
    local list, total = {}, 0
    for _, s in ipairs({ 16, 17 }) do
        local l = GetInventoryItemLink("player", s)
        local e = l and WeaponEntry(l, w, s)
        if e then
            e.worn = true
            list[#list + 1] = e
            if not (e.hand == "two" and ctx.shieldRole) then total = total + e.score end
        end
    end
    return list, total
end

-- weapons in the bags that you could wield now
local bagCache = { t = -10 }
local function BagWeapons(w, ctx, level)
    local now = GetTime and GetTime() or 0
    if bagCache.w == w and now - bagCache.t < 3 then return bagCache.list end
    local list = {}
    for _, it in ipairs(ns.BagItems()) do
        local e = WeaponEntry(it.link, w, nil)
        if e then
            local info = ns.ReadItem(it.link)
            if info and not info.unusable and not (info.reqLevel and info.reqLevel > level) then
                e.bag, e.bagSlot = it.bag, it.slot
                list[#list + 1] = e
            end
        end
    end
    bagCache.w, bagCache.t, bagCache.list = w, now, list
    return list
end

function ns.ResetWeaponCache() bagCache.t = -10 bagCache.list = nil end
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    ev:SetScript("OnEvent", ns.ResetWeaponCache)
    -- set counts on an item's tooltip depend on what you wear, so what was read about items is stale after a swap
    local ev2 = CreateFrame("Frame")
    ev2:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    ev2:SetScript("OnEvent", function() ns.cache = {} end)
end

-- The best legal pair from a pool of weapon entries. `must` limits it to pairs that contain that entry.
-- Returns { mh = entry, oh = entry } and its total score, or nil.
local function BestLoadout(pool, ctx, must)
    local best, bestScore
    local function consider(mh, oh)
        if must and mh ~= must and oh ~= must then return end
        local s = (mh and mh.score or 0) + (oh and oh.score or 0)
        if not best or s > bestScore then best, bestScore = { mh = mh, oh = oh }, s end
    end
    for _, a in ipairs(pool) do
        if a.hand == "two" then
            if not ctx.shieldRole then consider(a, nil) end
        elseif a.hand == "mh" or a.hand == "either" then
            consider(a, nil)
            for _, b in ipairs(pool) do
                if b ~= a then
                    if b.hand == "oh" and not b.weapon then
                        if not (ctx.tank and b.loc == "INVTYPE_HOLDABLE") then consider(a, b) end
                    elseif (b.hand == "either" or b.hand == "oh") and ctx.dw then
                        consider(a, b)                                -- a weapon in the off hand: needs dual wield
                    end
                end
            end
        elseif a.hand == "oh" and not a.weapon then
            if not (ctx.tank and a.loc == "INVTYPE_HOLDABLE") then consider(nil, a) end   -- a shield or held item on its own
        end
    end
    return best, bestScore or 0
end

local function InLoadout(l, e) return l and (l.mh == e or l.oh == e) end

-- Compare one item to what is worn. Returns a result table or nil if it is not gear.
-- A typical worn item's score, so a tiny difference between two near-empty items (3 armor against 7 armor on a
-- cloak) is not shown as +133%. Percentages are measured against at least a third of this.
local refCache = { t = -10 }
local function TypicalScore(w)
    local now = GetTime and GetTime() or 0
    if refCache.w == w and now - refCache.t < 5 then return refCache.v end
    local sum, n = 0, 0
    for sl = 1, 17 do
        if sl ~= 4 then
            local l = GetInventoryItemLink("player", sl)
            local sc = l and ItemScore(l, w) or 0
            if sc > 0 then sum, n = sum + sc, n + 1 end
        end
    end
    refCache.w, refCache.t, refCache.v = w, now, n > 0 and sum / n or 0
    return refCache.v
end

-- { gain = percent (positive = better), slot = id, worn = link, score, wornScore, unusable, reqLevel, tooHigh }
function ns.Compare(link, opts)
    local spec = ns.Spec()
    if not spec or not link then return nil end
    local equipLoc = ns.EquipLoc(link)
    local slots = equipLoc and SLOTS[equipLoc]
    if not slots or #slots == 0 then return nil end
    local info = ns.ReadItem(link)
    if not info then return nil end
    local w = spec.w
    local score = ns.Score(info.stats, WeightsFor(link, w))
    local level = UnitLevel("player") or 1
    local res = { score = score, unusable = info.unusable, reqLevel = info.reqLevel, equipLoc = equipLoc }
    if info.reqLevel and info.reqLevel > level then res.tooHigh = info.reqLevel end

    -- what it would replace
    local worn, wornScore, wornSlot
    local loadoutGain
    if HAND[equipLoc] then
        -- weapons: compare whole loadouts. With opts.bags, what you could already wield from your bags counts as
        -- yours (used for items you do not own yet).
        local ctx = LoadoutContext(spec, level)
        local pool, cur = WornWeapons(w, ctx)
        local baseLoad
        if opts and opts.bags then
            for _, e in ipairs(BagWeapons(w, ctx, level)) do pool[#pool + 1] = e end
            local bl, bs = BestLoadout(pool, ctx)
            baseLoad, cur = bl, bs
            if not bl then baseLoad = {} end
        else
            baseLoad = {}
            for _, e in ipairs(pool) do
                if not (e.hand == "two" and ctx.shieldRole) then
                    if e.slot == 16 then baseLoad.mh = e else baseLoad.oh = e end
                end
            end
        end
        local cand = WeaponEntry(link, w, nil)
        cand.cand = true
        local withCand = {}
        for _, e in ipairs(pool) do withCand[#withCand + 1] = e end
        withCand[#withCand + 1] = cand
        local nl = BestLoadout(withCand, ctx, cand)
        if not nl then
            -- no legal way to wield it (an off-hand weapon without dual wield, a two-hander for a shield role)
            res.unusable = res.unusable or (equipLoc == "INVTYPE_2HWEAPON" and ((ctx.tank and "tanks" or "healers") .. " use a one-hander and a shield"))
                or (ctx.tank and equipLoc == "INVTYPE_HOLDABLE" and "tanks use a shield") or "can't be wielded with your class or spec"
            nl = baseLoad
            wornScore, worn, wornSlot = 0, nil, (HAND[equipLoc] == "oh") and 17 or 16
            loadoutGain = 0
        else
            local newScore = (nl.mh and nl.mh.score or 0) + (nl.oh and nl.oh.score or 0)
            local replacedScore, first, bySlot = 0, nil, nil
            for _, e in ipairs({ baseLoad.mh or false, baseLoad.oh or false }) do
                if e and not InLoadout(nl, e) then
                    replacedScore = replacedScore + e.score
                    first = first or e
                    if e.slot == ((nl.mh == cand) and 16 or 17) then bySlot = e end
                end
            end
            local shown = bySlot or first
            worn, wornScore = shown and shown.link, replacedScore
            wornSlot = (nl.mh == cand) and 16 or 17
            loadoutGain = newScore - cur
            local partner = (nl.mh == cand) and nl.oh or nl.mh
            if partner and partner ~= cand then
                res.combo, res.comboSlot = partner.link, (nl.mh == partner) and 16 or 17
                res.comboOwned = partner.worn and "worn" or "bag"
            end
        end
    else
        local bestKey
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
    -- swapping out a piece of a set that is active loses the bonus that needed that piece
    if worn and equipLoc ~= "INVTYPE_2HWEAPON" and not HAND[equipLoc] then
        local wi = ns.ReadItem(worn)
        if wi and (wi.setBonus or wi.setActive) and wi.setCount and wi.setName ~= info.setName then
            local lost = wi.setBonus and wi.setBonus[wi.setCount]
            if not lost and wi.setActive and #wi.setActive > 0 then
                -- bonuses you have are listed without a number. The highest one needs as many pieces as you wear now
                -- (the next one still to earn is numbered, or the set is complete), so taking a piece off loses that one
                local firstOff
                for n in pairs(wi.setBonus or {}) do if not firstOff or n < firstOff then firstOff = n end end
                local topNeeds = (firstOff or ((wi.setTotal or wi.setCount) + 1)) - 1
                if topNeeds == wi.setCount then lost = wi.setActive[#wi.setActive] end
            end
            if lost then wornScore = wornScore + ns.Score(lost, w) end
        end
    end
    -- a piece that completes a set tier adds that tier's bonus: the pieces you wear now, plus this one, minus the one it replaces
    -- if that was from the same set. Tiers still to earn are listed with a number on this item's tooltip.
    if info.setBonus and info.setCount and not HAND[equipLoc] then
        local newCount = info.setCount + 1
        if worn then
            local wi2 = ns.ReadItem(worn)
            if wi2 and wi2.setName and wi2.setName == info.setName then newCount = newCount - 1 end
        end
        local gained = 0
        for n, bonus in pairs(info.setBonus) do
            if n > info.setCount and n <= newCount then gained = gained + ns.Score(bonus, w) end
        end
        if gained > 0 then
            score = score + gained
            res.score = score
            res.setGain = gained
        end
    end
    res.worn, res.wornScore, res.slot = worn, wornScore, wornSlot or slots[1]
    if loadoutGain then
        -- a loadout's change is measured against the weapon(s) it takes out of use
        if wornScore <= 0 then res.gain = loadoutGain > 0 and 100 or 0
        else res.gain = loadoutGain / math.max(wornScore, TypicalScore(w) / 3) * 100 end
    elseif wornScore <= 0 then res.gain = score > 0 and 100 or 0
    else res.gain = (score - wornScore) / math.max(wornScore, TypicalScore(w) / 3) * 100 end
    -- an empty slot only counts when the item would actually give you something
    res.empty = (worn == nil) and (loadoutGain and loadoutGain > 0 or (not loadoutGain and score > 0)) and true or false
    if worn == nil and (loadoutGain and loadoutGain <= 0 or (not loadoutGain and score <= 0)) then res.gain = 0 end
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

-- Weapons in the bags judged together with what you wear: a sword that is worse than your two-hander and a shield
-- that is worse than nothing can still be a better pair. Replaces the one-at-a-time weapon entries.
local function JointWeapons(out)
    local spec = ns.Spec()
    if not spec then return out end
    local w, level = spec.w, UnitLevel("player") or 1
    local ctx = LoadoutContext(spec, level)
    local pool, cur = WornWeapons(w, ctx)
    local bags = BagWeapons(w, ctx, level)
    if #bags == 0 then return out end
    local baseLoad = {}
    for _, e in ipairs(pool) do
        if not (e.hand == "two" and ctx.shieldRole) then if e.slot == 16 then baseLoad.mh = e else baseLoad.oh = e end end
    end
    local all = {}
    for _, e in ipairs(pool) do all[#all + 1] = e end
    for _, e in ipairs(bags) do all[#all + 1] = e end
    local best, total = BestLoadout(all, ctx)
    if not best or total <= cur then return out end
    local mine = {}
    for _, e in ipairs({ best.mh or false, best.oh or false }) do if e and e.bag then mine[#mine + 1] = e end end
    if #mine == 0 then return out end
    local replacedScore, first = 0, nil
    for _, e in ipairs({ baseLoad.mh or false, baseLoad.oh or false }) do
        if e and not InLoadout(best, e) then replacedScore = replacedScore + e.score first = first or e end
    end
    local gain
    if replacedScore <= 0 then gain = 100 else gain = (total - cur) / math.max(replacedScore, TypicalScore(w) / 3) * 100 end
    if gain < (ns.db.minGain or 3) then return out end
    local keep = {}
    for _, r in ipairs(out) do
        local isWeaponSlot = (r.slot == 16 or r.slot == 17) and HAND[r.equipLoc or ""] and not r.tooHigh
        if not isWeaponSlot then keep[#keep + 1] = r end
    end
    for _, e in ipairs(mine) do
        local r = ns.Compare(e.link)
        if r then
            local other = (best.mh == e) and best.oh or best.mh
            r.link, r.bag, r.bagSlot = e.link, e.bag, e.bagSlot
            r.slot = (best.mh == e) and 16 or 17
            r.gain, r.wornScore = gain, replacedScore
            r.worn = first and first.link or nil
            r.empty = first == nil
            r.combo = other and other.link or nil
            r.comboSlot = other and ((best.mh == other) and 16 or 17) or nil
            r.comboOwned = other and (other.worn and "worn" or "bag") or nil
            r.unusable = nil
            keep[#keep + 1] = r
        end
    end
    return keep
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
    out = JointWeapons(out)
    table.sort(out, function(a, b)
        local ah, bh = a.tooHigh and 1 or 0, b.tooHigh and 1 or 0
        if ah ~= bh then return ah < bh end
        if a.gain ~= b.gain then return a.gain > b.gain end
        return tostring(a.link) < tostring(b.link)     -- ties keep a fixed order, so the list does not reshuffle
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

-- Extra candidates read from saved data of another installed add-on (when it is there): gear your characters can
-- craft, and gear sitting in your other characters' bags and bank. Works for every class.
local function ShortChar(k) return (tostring(k):match("^[^-]+")) or tostring(k) end

local function DynamicSources(have, known)
    local out = {}
    local db = Loaded("Profiteer") and _G.ProfiteerDB or nil
    if type(db) ~= "table" then return out end
    local me = UnitName and UnitName("player")
    local names = type(db.names) == "table" and db.names or {}
    local function nameOf(id, fallback)
        return names[id] or fallback or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or ("item " .. id)
    end
    -- Soulbound / bind-on-pickup gear cannot be handed from one character to another
    local function tradable(id)
        local r = ns.ReadItem and ns.ReadItem("item:" .. id)
        return r ~= nil and r.bind ~= "bop"
    end
    local function add(id, name, how, where, needsTrade)
        if type(id) ~= "number" or have[id] or known[id] then return end
        if not ns.EquipLoc("item:" .. id) then return end        -- not wearable
        if needsTrade and not tradable(id) then return end
        known[id] = true
        out[#out + 1] = { id, nameOf(id, name), 1, how, where, "" }
    end
    -- bags and bank of your other characters
    for ck, inv in pairs(type(db.inventory) == "table" and db.inventory or {}) do
        if ShortChar(ck) ~= me and type(inv) == "table" then
            for _, where in ipairs({ "bags", "bank" }) do
                for id in pairs(type(inv[where]) == "table" and inv[where] or {}) do
                    add(id, nil, "alt", ("in %s's %s"):format(ShortChar(ck), where), true)
                end
            end
        end
    end
    -- gear your characters know how to make
    for ck, profs in pairs(type(db.recipes) == "table" and db.recipes or {}) do
        for prof, recs in pairs(type(profs) == "table" and profs or {}) do
            for _, r in ipairs(type(recs) == "table" and recs or {}) do
                local mine = ShortChar(ck) == me
                add(r.id, r.name, "crafted", mine and ("%s - you know the recipe"):format(prof)
                    or ("%s - %s knows the recipe"):format(prof, ShortChar(ck)), not mine)
            end
        end
    end
    return out
end

-- Known gear that would beat what you wear, best first: the built-in lists for the cloth casters,
-- plus gear your other characters hold or can craft (any class).
-- Returns list, pending (items whose data the game has not sent yet), checked.
-- A bind-on-pickup craft is only yours if your character has the profession itself.
local function CraftOnlyByOthers(link, where)
    local info = ns.ReadItem(link)
    if not (info and info.bind == "bop") then return false end
    if where:find("you know", 1, true) then return false end
    local prof = where:match("^(%a+)")
    return prof ~= nil and HasSkill(prof, 1) == false
end

function ns.FindSources()
    local out, pending, checked = {}, 0, 0
    if InCombatLockdown and InCombatLockdown() then return {}, 1, 0 end     -- heavy work waits for the fight to end
    local t0 = debugprofilestop and debugprofilestop() or 0
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
    -- quests, vendors and dungeon bosses for every class, from the quest database
    if ns.QuestSources then
        if not ns.QIndex.ready then
            ns.QuestIndexStart()
            pending = pending + 1                 -- still reading the database; the tab refreshes when done
        end
        local qs, qdone = ns.QuestSources(level, have, known)
        for _, e in ipairs(qs) do list[#list + 1] = e end
        if qdone == false then pending = pending + 1 end
    end
    for _, e in ipairs(list) do
        if debugprofilestop and debugprofilestop() - t0 > 10 then pending = pending + 1 break end   -- carry on next refresh; Compare results are cached
        local id, name, req, how, where, note = e[1], e[2], e[3], e[4], e[5], e[6]
        ns.srcTries = ns.srcTries or {}
        if not have[id] and req <= level and (ns.srcTries[id] or 0) <= 5 and ns.SourceOn(ns.SourceKind({ id = id, how = how, where = where })) then
            checked = checked + 1
            local link = "item:" .. id
            local r = ns.Compare(link, { bags = true })
            if r == nil then
                -- the game may never send data for an item it does not know: look a few times, then leave it out
                -- (otherwise the list keeps rebuilding forever and the window flickers)
                if ns.EquipLoc(link) then
                    ns.srcTries[id] = (ns.srcTries[id] or 0) + 1
                    if ns.srcTries[id] <= 5 then pending = pending + 1 end
                end
            elseif (r.empty or (r.gain and r.gain >= (ns.db.minGain or 3))) and not r.unusable and not r.tooHigh
                and not (how == "crafted" and CraftOnlyByOthers(link, where)) then
                r.link, r.name, r.req, r.how, r.where, r.note, r.id = link, name, req, how, where, note, id
                if r.empty then r.gain = 1000 + (r.score or 0) end
                out[#out + 1] = r
            end
        end
    end
    local function Order(a, b)
        local ah, bh = a.note ~= "" and 1 or 0, b.note ~= "" and 1 or 0     -- faction-unsure quests last
        if ah ~= bh then return ah < bh end
        if a.gain ~= b.gain then return a.gain > b.gain end
        -- equal gains (several items show +100%) must keep one fixed order, or the rows swap places every refresh
        if (a.slot or 0) ~= (b.slot or 0) then return (a.slot or 0) < (b.slot or 0) end
        return tostring(a.id or a.link) < tostring(b.id or b.link)
    end
    table.sort(out, Order)
    local best = BestPerSlot(out)
    -- while item data is still arriving, every pass sees a different part of the list. Showing each pass made rows
    -- jump in and out and the window grow and shrink, so while loading we only ever add to what is already shown.
    if pending > 0 and ns.srcShown then
        local merged, seen = {}, {}
        for _, e in ipairs(ns.srcShown) do merged[#merged + 1] = e seen[e.id] = true end
        for _, e in ipairs(best) do if not seen[e.id] then merged[#merged + 1] = e end end
        table.sort(merged, Order)
        best = BestPerSlot(merged)
    end
    ns.srcShown = best
    if pending == 0 then ns.srcFinal = true end
    return best, pending, checked
end

function ns.SlotsFor(loc)
    local t = SLOTS[loc]
    return t and #t > 0 and t or nil
end
