-- Stat weights per class and spec. One point of the main stat is about 1.0. Edit freely:
-- /outfit weights shows the numbers a spec uses.
local _, ns = ...

-- keys: STR AGI STA INT SPI ARMOR AP RAP SP (damage/spell power) HEAL CRIT HIT SPCRIT SPHIT
--       MP5 DEF DODGE PARRY BLOCK BLOCKVAL DPS (weapon damage per second) HASTE
local W = {}
ns.Weights = W

local function set(class, spec, role, weights) W[class] = W[class] or {} W[class][#W[class] + 1] = { name = spec, role = role, w = weights } end

-- melee building blocks
local function melee(o)
    local t = { STA = 0.3, ARMOR = 0.02, CRIT = 14, HIT = 12, DPS = 12 }
    for k, v in pairs(o) do t[k] = v end
    return t
end

set("WARRIOR", "Arms", "dps", melee({ STR = 2.0, AGI = 1.0, AP = 1.0, DPS = 14, HIT = 16, CRIT = 16 }))
set("WARRIOR", "Fury", "dps", melee({ STR = 2.0, AGI = 1.2, AP = 1.0, DPS = 12, HIT = 18, CRIT = 18 }))
set("WARRIOR", "Protection", "tank", { STA = 1.5, STR = 0.6, AGI = 0.8, ARMOR = 0.12, DEF = 2.5, DODGE = 14, PARRY = 14, BLOCK = 8, BLOCKVAL = 0.5, AP = 0.3, HIT = 6, CRIT = 5, DPS = 4 })

set("PALADIN", "Retribution", "dps", melee({ STR = 2.0, AGI = 0.8, INT = 0.1, AP = 1.0, DPS = 15, HIT = 16, CRIT = 14, SP = 0.1 }))
set("PALADIN", "Protection", "tank", { STA = 1.5, STR = 0.5, AGI = 0.5, ARMOR = 0.12, DEF = 2.5, DODGE = 12, PARRY = 12, BLOCK = 10, BLOCKVAL = 0.6, SP = 0.5, INT = 0.3, DPS = 2 })
set("PALADIN", "Holy", "healer", { INT = 1.8, SPI = 0.3, STA = 0.4, HEAL = 1.0, SP = 0.4, MP5 = 2.5, SPCRIT = 8, ARMOR = 0.02 })

set("HUNTER", "Beast Mastery", "dps", { AGI = 2.0, STA = 0.4, INT = 0.3, STR = 0.2, RAP = 1.0, AP = 0.5, CRIT = 14, HIT = 12, DPS = 14, ARMOR = 0.02 })
set("HUNTER", "Marksmanship", "dps", { AGI = 2.0, STA = 0.4, INT = 0.3, STR = 0.2, RAP = 1.0, AP = 0.5, CRIT = 15, HIT = 14, DPS = 16, ARMOR = 0.02 })
set("HUNTER", "Survival", "dps", { AGI = 2.2, STA = 0.6, INT = 0.3, STR = 0.2, RAP = 1.0, AP = 0.5, CRIT = 14, HIT = 12, DPS = 12, ARMOR = 0.02 })

set("ROGUE", "Assassination", "dps", melee({ AGI = 2.0, STR = 1.0, AP = 1.0, DPS = 14, HIT = 16, CRIT = 14 }))
set("ROGUE", "Combat", "dps", melee({ AGI = 2.0, STR = 1.0, AP = 1.0, DPS = 16, HIT = 18, CRIT = 14 }))
set("ROGUE", "Subtlety", "dps", melee({ AGI = 2.0, STR = 1.0, AP = 1.0, DPS = 12, HIT = 16, CRIT = 14 }))

set("PRIEST", "Discipline", "healer", { INT = 1.8, SPI = 1.0, STA = 0.4, HEAL = 1.0, SP = 0.4, MP5 = 2.5, SPCRIT = 6, ARMOR = 0.01 })
set("PRIEST", "Holy", "healer", { INT = 1.8, SPI = 1.0, STA = 0.4, HEAL = 1.0, SP = 0.4, MP5 = 2.5, SPCRIT = 6, ARMOR = 0.01 })
set("PRIEST", "Shadow", "dps", { INT = 1.0, SPI = 0.6, STA = 0.5, SP = 1.0, SPHIT = 12, SPCRIT = 10, MP5 = 1.0, ARMOR = 0.01 })

set("SHAMAN", "Elemental", "dps", { INT = 1.2, STA = 0.4, SPI = 0.2, SP = 1.0, SPHIT = 12, SPCRIT = 10, MP5 = 1.5, ARMOR = 0.02 })
set("SHAMAN", "Enhancement", "dps", melee({ STR = 1.6, AGI = 1.0, AP = 1.0, INT = 0.2, DPS = 16, HIT = 16, CRIT = 14 }))
set("SHAMAN", "Restoration", "healer", { INT = 1.8, SPI = 0.4, STA = 0.4, HEAL = 1.0, SP = 0.4, MP5 = 2.5, SPCRIT = 6, ARMOR = 0.02 })

set("MAGE", "Arcane", "dps", { INT = 1.2, SPI = 0.3, STA = 0.5, SP = 1.0, SPHIT = 12, SPCRIT = 10, MP5 = 1.0, ARMOR = 0.01 })
set("MAGE", "Fire", "dps", { INT = 1.0, SPI = 0.2, STA = 0.5, SP = 1.0, SPHIT = 12, SPCRIT = 12, MP5 = 0.6, ARMOR = 0.01 })
set("MAGE", "Frost", "dps", { INT = 1.0, SPI = 0.3, STA = 0.5, SP = 1.0, SPHIT = 12, SPCRIT = 8, MP5 = 0.8, ARMOR = 0.01 })

set("WARLOCK", "Affliction", "dps", { STA = 0.9, INT = 0.8, SPI = 0.2, SP = 1.0, SPHIT = 12, SPCRIT = 8, MP5 = 0.5, ARMOR = 0.01 })
set("WARLOCK", "Demonology", "dps", { STA = 0.9, INT = 0.8, SPI = 0.2, SP = 1.0, SPHIT = 12, SPCRIT = 8, MP5 = 0.5, ARMOR = 0.01 })
set("WARLOCK", "Destruction", "dps", { STA = 0.8, INT = 0.8, SPI = 0.2, SP = 1.0, SPHIT = 12, SPCRIT = 12, MP5 = 0.5, ARMOR = 0.01 })

set("DRUID", "Balance", "dps", { INT = 1.2, SPI = 0.6, STA = 0.5, SP = 1.0, SPHIT = 12, SPCRIT = 10, MP5 = 1.2, ARMOR = 0.01 })
set("DRUID", "Feral (cat)", "dps", { AGI = 2.0, STR = 2.0, STA = 0.5, AP = 0.8, CRIT = 14, HIT = 12, DPS = 4, ARMOR = 0.02 })
set("DRUID", "Feral (bear)", "tank", { STA = 1.5, AGI = 1.2, STR = 0.5, ARMOR = 0.1, DEF = 1.0, DODGE = 14, AP = 0.3, HIT = 4, CRIT = 4 })
set("DRUID", "Restoration", "healer", { INT = 1.6, SPI = 1.2, STA = 0.4, HEAL = 1.0, SP = 0.4, MP5 = 2.5, SPCRIT = 6, ARMOR = 0.01 })

-- Armor and weapon types each class can use (best armor type first; used to flag unusable gear)
ns.Armor = {
    WARRIOR = { Plate = true, Mail = true, Leather = true, Cloth = true, Shield = true },
    PALADIN = { Plate = true, Mail = true, Leather = true, Cloth = true, Shield = true, Libram = true },
    HUNTER  = { Mail = true, Leather = true, Cloth = true },
    ROGUE   = { Leather = true, Cloth = true },
    PRIEST  = { Cloth = true },
    SHAMAN  = { Mail = true, Leather = true, Cloth = true, Shield = true, Totem = true },
    MAGE    = { Cloth = true },
    WARLOCK = { Cloth = true },
    DRUID   = { Leather = true, Cloth = true, Idol = true },
}
