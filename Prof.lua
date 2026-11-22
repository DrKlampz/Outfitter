local _, ns = ...
-- Profession gear: anything you wear or carry that raises a profession skill or speeds it up
-- (fishing hats and poles, mining and skinning gear, lures and other "Use:" boosts), what it gives,
-- and what you'd swap out to use it.

local scan = CreateFrame("GameTooltip", "GearhawkProfScanTip", nil, "GameTooltipTemplate")
scan:SetOwner(UIParent, "ANCHOR_NONE")

ns.PROFESSIONS = {
    { key = "fishing",        name = "Fishing",        icon = "Interface\\Icons\\Trade_Fishing" },
    { key = "mining",         name = "Mining",         icon = "Interface\\Icons\\Trade_Mining" },
    { key = "herbalism",      name = "Herbalism",      icon = "Interface\\Icons\\Trade_Herbalism" },
    { key = "skinning",       name = "Skinning",       icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    { key = "engineering",    name = "Engineering",    icon = "Interface\\Icons\\Trade_Engineering" },
    { key = "blacksmithing",  name = "Blacksmithing",  icon = "Interface\\Icons\\Trade_BlackSmithing" },
    { key = "alchemy",        name = "Alchemy",        icon = "Interface\\Icons\\Trade_Alchemy" },
    { key = "enchanting",     name = "Enchanting",     icon = "Interface\\Icons\\Trade_Engraving" },
    { key = "tailoring",      name = "Tailoring",      icon = "Interface\\Icons\\Trade_Tailoring" },
    { key = "leatherworking", name = "Leatherworking", icon = "Interface\\Icons\\Trade_LeatherWorking" },
    { key = "jewelcrafting",  name = "Jewelcrafting",  icon = "Interface\\Icons\\INV_Misc_Gem_01" },
    { key = "cooking",        name = "Cooking",        icon = "Interface\\Icons\\INV_Misc_Food_15" },
    { key = "first aid",      name = "First Aid",      icon = "Interface\\Icons\\INV_Misc_Bandage_15" },
    { key = "lockpicking",    name = "Lockpicking",    icon = "Interface\\Icons\\INV_Misc_Key_03" },
}

local function Clean(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- the profession lines of one item: { { prof = <entry>, text = "...", value = number, use = bool }, ... }
-- returns nil while the game hasn't loaded the item yet
local cache = {}
function ns.ProfLines(link)
    if not link then return {} end
    if cache[link] then return cache[link] end
    scan:ClearLines()
    scan:SetOwner(UIParent, "ANCHOR_NONE")
    scan:SetHyperlink(link)
    if scan:NumLines() < 2 then return nil end
    local out = {}
    for i = 2, scan:NumLines() do
        local left = _G["GearhawkProfScanTipTextLeft" .. i]
        local raw = left and left:GetText()
        if raw and raw ~= "" then
            local text = Clean(raw)
            local low = text:lower()
            if not low:find("^requires") and not low:find("teaches") and not low:find("^classes:") then
                for _, p in ipairs(ns.PROFESSIONS) do
                    if low:find(p.key, 1, true) then
                        local num = tonumber(low:match("(%d+)")) or 0
                        local rel = num > 0 or low:find("faster", 1, true) or low:find("speed", 1, true) or low:find("skill", 1, true) or low:find("chance", 1, true)
                        if rel then
                            out[#out + 1] = { prof = p, text = text, value = num, use = low:find("^use:") and true or false }
                        end
                    end
                end
            end
        end
    end
    cache[link] = out
    return out
end

local function Sum(lines, key)
    local s = 0
    for _, l in ipairs(lines or {}) do if l.prof.key == key and not l.use then s = s + l.value end end
    return s
end

-- returns groups = { { prof, worn = { {link, slot, text, value} }, bag = { {link, bag, slot, text, value, use, swapSlot, swapLink, swapValue, gain} }, total } }, pending
function ns.ProfGear()
    local pending = 0
    local byProf, order = {}, {}
    local function Group(p)
        local g = byProf[p.key]
        if not g then g = { prof = p, worn = {}, bag = {}, total = 0 } byProf[p.key] = g order[#order + 1] = g end
        return g
    end
    local wornLines = {}
    for slot = 1, 19 do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if link then
            local lines = ns.ProfLines(link)
            if not lines then pending = pending + 1 else
                wornLines[slot] = lines
                for _, l in ipairs(lines) do
                    local g = Group(l.prof)
                    g.worn[#g.worn + 1] = { link = link, slot = slot, text = l.text, value = l.value }
                    if not l.use then g.total = g.total + l.value end
                end
            end
        end
    end
    for _, b in ipairs(ns.BagItems()) do
        local lines = ns.ProfLines(b.link)
        if not lines then pending = pending + 1
        elseif #lines > 0 then
            local loc = ns.EquipLoc and ns.EquipLoc(b.link)
            local slots = loc and ns.SlotsFor and ns.SlotsFor(loc)
            for _, l in ipairs(lines) do
                local g = Group(l.prof)
                local e = { link = b.link, bag = b.bag, slot = b.slot, text = l.text, value = l.value, use = l.use }
                if slots and not l.use then
                    -- the slot it would take: an empty one first, else the one whose worn item gives the least of this skill
                    local pick, pickVal, pickLink
                    for _, s in ipairs(slots) do
                        local wl = GetInventoryItemLink and GetInventoryItemLink("player", s)
                        local v = wl and Sum(wornLines[s], l.prof.key) or -1
                        if pickVal == nil or v < pickVal then pick, pickVal, pickLink = s, v, wl end
                    end
                    e.swapSlot, e.swapLink, e.swapValue = pick, pickLink, math.max(pickVal or 0, 0)
                    if ns.Compare then
                        local ok, c = pcall(ns.Compare, b.link)
                        if ok and type(c) == "table" and type(c.gain) == "number" then e.gain = c.gain end
                    end
                end
                g.bag[#g.bag + 1] = e
            end
        end
    end
    -- profession order as listed above, bag items best first
    local rank = {}
    for i, p in ipairs(ns.PROFESSIONS) do rank[p.key] = i end
    table.sort(order, function(a, b) return rank[a.prof.key] < rank[b.prof.key] end)
    for _, g in ipairs(order) do
        table.sort(g.bag, function(a, b)
            if a.value ~= b.value then return a.value > b.value end
            return tostring(a.link) < tostring(b.link)
        end)
    end
    return order, pending
end

-- put a bag item on (out of combat only), in the slot ProfGear chose
function ns.ProfWear(e)
    if not e or e.use or not e.swapSlot then return end
    if InCombatLockdown and InCombatLockdown() then ns.Print("can't change gear in combat") return end
    if EquipItemByName then pcall(EquipItemByName, e.link, e.swapSlot) end
    if C_Timer then C_Timer.After(0.5, function() if ns.RefreshUI then ns.RefreshUI() end end) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:SetScript("OnEvent", function() if ns.RefreshUI then ns.RefreshUI() end end)
