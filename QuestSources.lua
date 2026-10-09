local _, ns = ...

-- Where to get gear for EVERY class, read from the quest database Questie installs (QuestieDB):
-- quest rewards, vendors and dungeon-boss drops for each piece of armor and weapon.
-- The list is built once per session in small slices (no hitching) and held in memory.
-- Items are still scored in game from their real tooltip, so only real upgrades you can use are shown.
local Q = { ready = false, building = false, items = {}, count = 0 }
ns.QIndex = Q

local MAX_LEVEL = 60
local SLICE = 400

local function Lib() return _G.LibQuestieDB end

function ns.QuestDBAvailable()
    local L = Lib()
    return L ~= nil and type(L.Item) == "table" and type(L.Item.GetAllIds) == "function"
        and type(L.Quest) == "table" and type(L.Npc) == "table"
end

local function Get(ent, id, key)
    local ok, v = pcall(ent.Get, id, key)
    if ok then return v end
end

local ids, pos
local function Slice()
    local L = Lib()
    local I = L.Item
    local last = math.min(pos + SLICE - 1, #ids)
    for i = pos, last do
        local id = ids[i]
        local cls = Get(I, id, "class")
        if cls == 2 or cls == 4 then
            local lvl = Get(I, id, "requiredLevel") or 0
            if lvl <= MAX_LEVEL then
                local q, v, d = Get(I, id, "questRewards"), Get(I, id, "vendors"), Get(I, id, "npcDrops")
                if (q and #q > 0) or (v and #v > 0) or (d and #d > 0) then
                    local loc = ns.EquipLoc and ns.EquipLoc("item:" .. id)
                    if loc and ns.SlotsFor and ns.SlotsFor(loc) then
                        Q.items[id] = { lvl = lvl, q = q, v = v, d = d }
                        Q.count = Q.count + 1
                    end
                end
            end
        end
    end
    pos = last + 1
    if pos > #ids then
        Q.ready, Q.building = true, false
        if ns.RefreshUI then ns.RefreshUI() end
    else
        C_Timer.After(0.02, Slice)
    end
end

function ns.QuestIndexStart()
    if Q.ready or Q.building or not ns.QuestDBAvailable() then return end
    local ok, all = pcall(Lib().Item.GetAllIds)
    if not ok or type(all) ~= "table" then return end
    ids, pos = all, 1
    Q.building = true
    C_Timer.After(0.02, Slice)
end

------------------------------------------------------------------------
-- Turning ids into readable sources
------------------------------------------------------------------------
local function AreaName(areaId)
    if type(areaId) ~= "number" or areaId <= 0 then return nil end
    if C_Map and C_Map.GetAreaInfo then
        local ok, n = pcall(C_Map.GetAreaInfo, areaId)
        if ok and n then return n end
    end
end

local function ZoneDB()
    local loader = _G.QuestieLoader
    if loader and loader.ImportModule then
        local ok, z = pcall(loader.ImportModule, loader, "ZoneDB")
        if ok then return z end
    end
end

local function DungeonName(areaId)
    local z = ZoneDB()
    if not (z and type(areaId) == "number" and areaId > 0) then return nil end
    local ok, isD = pcall(z.IsDungeonZone, areaId)
    if not (ok and isD) then return nil end
    local ok2, n = pcall(z.GetLocalizedDungeonName, z, areaId)
    if ok2 and n then return n end
    return AreaName(areaId) or "dungeon"
end

local function PlayerBits()
    local raceId = select(3, UnitRace("player")) or 0
    local classId = select(3, UnitClass("player")) or 0
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return raceId > 0 and 2 ^ (raceId - 1) or 0, classId > 0 and 2 ^ (classId - 1) or 0, faction
end

local function HasBit(mask, bit)
    if not mask or mask == 0 or bit == 0 then return true end
    return math.floor(mask / bit) % 2 == 1
end

local function QuestSource(L, qid, level, raceBit, classBit)
    local Qd = L.Quest
    local name = Get(Qd, qid, "name")
    if not name then return nil end
    local req = Get(Qd, qid, "requiredLevel") or 0
    if req > level then return nil end
    if not HasBit(Get(Qd, qid, "requiredRaces"), raceBit) then return nil end
    if not HasBit(Get(Qd, qid, "requiredClasses"), classBit) then return nil end
    local zone = AreaName(Get(Qd, qid, "zoneOrSort"))
    if not zone then
        local fin = Get(Qd, qid, "finishedBy")
        local npc = fin and fin[1] and fin[1][1]
        zone = npc and Get(L.Npc, npc, "name") or nil
    end
    return zone and (name .. " - " .. zone) or name
end

local function NpcFriendly(f, faction)
    if not f or f == "AH" or f == "HA" then return true end
    if faction == "Horde" then return f:find("H", 1, true) ~= nil end
    if faction == "Alliance" then return f:find("A", 1, true) ~= nil end
    return true
end

-- Returns a list of { id, name, req, how, where, note } for items you could get at this level.
function ns.QuestSources(level, have, known)
    local out = {}
    if not Q.ready then return out end
    local L = Lib()
    if not L then return out end
    local raceBit, classBit, faction = PlayerBits()
    local lo = math.max(1, level - 15)
    for id, it in pairs(Q.items) do
        if not have[id] and not known[id] and it.lvl <= level and it.lvl >= lo then
            local how, where
            if it.q then
                for k = 1, math.min(#it.q, 6) do
                    local w = QuestSource(L, it.q[k], level, raceBit, classBit)
                    if w then how, where = "quest", w break end
                end
            end
            if not how and it.v then
                for k = 1, math.min(#it.v, 6) do
                    local npc = it.v[k]
                    if NpcFriendly(Get(L.Npc, npc, "friendlyToFaction"), faction) then
                        local n = Get(L.Npc, npc, "name")
                        local z = AreaName(Get(L.Npc, npc, "zoneID"))
                        if n then how, where = "vendor", z and (n .. ", " .. z) or n break end
                    end
                end
            end
            if not how and it.d then
                for k = 1, math.min(#it.d, 30) do
                    local npc = it.d[k]
                    local dn = DungeonName(Get(L.Npc, npc, "zoneID"))
                    local n = dn and Get(L.Npc, npc, "name")
                    if n then how, where = "drop", n .. ", " .. dn break end
                end
            end
            if how then
                known[id] = true
                local nm = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or Get(L.Item, id, "name") or ("item " .. id)
                out[#out + 1] = { id, nm, it.lvl, how, where, "" }
            end
        end
    end
    return out
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    C_Timer.After(20, ns.QuestIndexStart)       -- quietly, once the game has settled
end)
