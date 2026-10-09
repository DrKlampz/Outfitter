local ADDON, ns = ...
ns.VERSION = "dev"
local DEFAULTS = { spec = {}, showTooltip = true, minGain = 3, alert = true, minimap = { hide = false, angle = 215 } }   -- spec[charKey] = index into Weights[class]

local function CharKey() return (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "") end
ns.CharKey = CharKey

function ns.Money(c)
    c = math.floor(c or 0)
    local g, s, cp = math.floor(c / 10000), math.floor(c % 10000 / 100), c % 100
    local t = {}
    if g > 0 then t[#t + 1] = g .. "g" end
    if s > 0 or g > 0 then t[#t + 1] = s .. "s" end
    t[#t + 1] = cp .. "c"
    return table.concat(t, " ")
end

local function LinkOr(id)
    local n = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or (GetItemInfo and (GetItemInfo(id)))
    return n or ("item " .. id)
end

function ns.Print(msg) print("|cff33ccffOutfitter:|r " .. tostring(msg)) end

function ns.Class() local _, c = UnitClass("player") return c end

-- Guess the spec from where the talent points went (Classic: three trees in order).
function ns.GuessSpec()
    local class = ns.Class()
    local list = ns.Weights[class]
    if not list then return 1 end
    local best, bestPts = 1, -1
    if GetNumTalentTabs and GetTalentTabInfo then
        local tabs = GetNumTalentTabs() or 0
        for i = 1, tabs do
            local _, _, pts = GetTalentTabInfo(i)
            pts = tonumber(pts) or 0
            if pts > bestPts then best, bestPts = i, pts end
        end
    end
    if class == "DRUID" and best == 2 then return 2 end        -- feral defaults to cat
    if class == "DRUID" and best == 3 then return 4 end        -- druid tree 3 is Restoration
    return math.min(best, #list)
end

function ns.SpecIndex()
    local class = ns.Class()
    local list = ns.Weights[class]
    if not list then return nil end
    local i = ns.db.spec[CharKey()]
    if not i or not list[i] then i = ns.GuessSpec() end
    return i
end

function ns.Spec()
    local class = ns.Class()
    local list = ns.Weights[class]
    if not list then return nil end
    return list[ns.SpecIndex()]
end

function ns.SetSpec(i)
    local list = ns.Weights[ns.Class()]
    if not list or not list[i] then return end
    ns.db.spec[CharKey()] = i
    ns.cache = {}
    if ns.AuctionDirty then ns.AuctionDirty() end
    if ns.RefreshUI then ns.RefreshUI() end
end

function ns.CycleSpec()
    local list = ns.Weights[ns.Class()]
    if not list then return end
    local i = (ns.SpecIndex() or 0) % #list + 1
    ns.SetSpec(i)
    local s = list[i]
    ns.Print(("spec set to %s (%s)"):format(s.name, s.role))
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        OutfitterDB = OutfitterDB or {}
        for k, v in pairs(DEFAULTS) do if OutfitterDB[k] == nil then OutfitterDB[k] = v end end
        OutfitterDB.minimap = OutfitterDB.minimap or {}
        if OutfitterDB.minimap.angle == nil then OutfitterDB.minimap.angle = 215 end
        ns.db = OutfitterDB
        ns.cache = {}
    elseif event == "PLAYER_LOGIN" then
        if ns.BuildMinimapButton then pcall(ns.BuildMinimapButton) end
        if ns.StartAlerts then ns.StartAlerts() end
        local s = ns.Spec()
        if s and not ns.db.spec[CharKey()] then
            ns.Print(("hello %s. I guessed your spec as %s from your talents. Type /outfit to change it or see your upgrades."):format(
                ns.Class():sub(1, 1) .. ns.Class():sub(2):lower(), s.name))
        end
    end
end)

SLASH_OUTFITTER1 = "/outfit"
SLASH_OUTFITTER2 = "/outfitter"
SlashCmdList.OUTFITTER = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "spec" then ns.CycleSpec()
    elseif msg == "weights" then
        local s = ns.Spec()
        if not s then ns.Print("no weights for your class") return end
        local keys = {}
        for k in pairs(s.w) do keys[#keys + 1] = k end
        table.sort(keys)
        local parts = {}
        for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. s.w[k] end
        ns.Print(s.name .. ": " .. table.concat(parts, " "))
    elseif msg == "tip" then
        ns.db.showTooltip = not ns.db.showTooltip
        ns.Print("tooltip line " .. (ns.db.showTooltip and "on" or "off"))
    elseif msg == "minimap" then
        ns.db.minimap.hide = not ns.db.minimap.hide
        if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
        ns.Print("minimap button " .. (ns.db.minimap.hide and "hidden" or "shown"))
    elseif msg == "alert" then
        ns.db.alert = not ns.db.alert
        ns.Print("upgrade alerts " .. (ns.db.alert and "on" or "off"))
    elseif msg:match("^gain %d+$") then
        ns.db.minGain = tonumber(msg:match("%d+"))
        ns.cache = {}
        ns.Print(("only suggesting items at least %d%% better"):format(ns.db.minGain))
        if ns.RefreshUI then ns.RefreshUI() end
    elseif msg == "debug" then
        local C = _G.C_Container
        ns.Print(("api: C_Container=%s C_Item=%s GetItemInfoInstant=%s"):format(tostring(C ~= nil), tostring(C_Item ~= nil), tostring((C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant) ~= nil)))
        local items = ns.BagItems()
        ns.Print(#items .. " items found in bags")
        for i = 1, math.min(#items, 6) do
            local it = items[i]
            local r = ns.Compare(it.link)
            ns.Print(("%s loc=%s gain=%s"):format(it.link, tostring(ns.EquipLoc(it.link)), r and tostring(r.gain and math.floor(r.gain)) or "not gear"))
        end
        local a, sv = ns.AH or {}, ns.db and ns.db.ah
        local saved = 0
        if sv and sv.items then for _ in pairs(sv.items) do saved = saved + 1 end end
        ns.Print(("auction: saved listings=%d running=%s ready=%s done=%s/%s errors=%s found=%d shown=%d"):format(saved, tostring(a.running), tostring(a.ready), tostring(a.done), tostring(a.total), tostring(a.errors), (function() local n = 0 for _ in pairs(a.found or {}) do n = n + 1 end return n end)(), #(a.list or {})))
        if a.lastError then ns.Print("auction last error: " .. a.lastError) end
    elseif msg == "weapons" then
        -- every known weapon for your level, with why it does or doesn't beat what you hold
        local Q = ns.QIndex
        if not (Q and Q.ready) then ns.Print("quest index still loading, try again in a moment") return end
        local level = UnitLevel("player") or 1
        local rows = {}
        for id, it in pairs(Q.items) do
            local link = "item:" .. id
            local loc = ns.EquipLoc(link)
            if loc and loc:find("WEAPON", 1, true) or loc == "INVTYPE_RANGEDRIGHT" or loc == "INVTYPE_RANGED" then
                if it.lvl <= level + 5 and it.lvl >= level - 15 then
                    local r = ns.Compare(link)
                    if r then rows[#rows + 1] = { id = id, r = r } end
                end
            end
        end
        table.sort(rows, function(a, b) return (a.r.score or 0) > (b.r.score or 0) end)
        ns.Print(#rows .. " weapons in range (best score first):")
        for i = 1, math.min(#rows, 12) do
            local r = rows[i].r
            ns.Print(("%s score %d vs worn %d, gain %d%%%s%s"):format(LinkOr(rows[i].id), math.floor(r.score or 0), math.floor(r.wornScore or 0), math.floor(r.gain or 0),
                r.unusable and (" - can't use: " .. tostring(r.unusable)) or "", r.tooHigh and (" - needs level " .. r.tooHigh) or ""))
        end
    elseif msg == "unread" then
        -- stat lines on your worn gear that Outfitter does not understand (so they count as zero)
        local n = 0
        for slot = 1, 18 do
            local l = GetInventoryItemLink("player", slot)
            local r = l and ns.ReadItem(l)
            if r and r.unparsed then
                for _, t in ipairs(r.unparsed) do ns.Print(("%s: %s"):format(l, t)) n = n + 1 end
            end
        end
        ns.Print(n == 0 and "Every stat line on your worn gear is understood." or (n .. " stat line(s) are not counted."))
    elseif msg == "help" then
        ns.Print("/outfit  window | spec  next spec | weights | tip  tooltip line | minimap  show/hide button | alert  upgrade alerts | gain N  minimum % better | unread  unknown stat lines | weapons  weapon candidates | debug")
    else
        if ns.ToggleUI then ns.ToggleUI() end
    end
end

-- Tells you in chat when a new upgrade shows up in your bags (once per item per session).
local seen, primed, timer = {}, false, false
function ns.StartAlerts()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:SetScript("OnEvent", function()
        if timer or not ns.db.alert then return end
        timer = true
        C_Timer.After(1.5, function()
            timer = false
            if not ns.FindUpgrades then return end
            ns.cache = {}
            local ok, list = pcall(ns.FindUpgrades)
            if not ok or not list then return end
            for _, u in ipairs(list) do
                if not u.tooHigh and not seen[u.link] then
                    seen[u.link] = true
                    if primed then
                        local slot = ns.SLOT_NAMES[u.slot] or "?"
                        ns.Print(("upgrade in your bags: %s for %s (%s)"):format(u.link, slot,
                            u.empty and "empty slot" or (u.gain > 300 and "big upgrade" or ("+%d%%"):format(math.floor(u.gain + 0.5)))))
                    end
                end
            end
        end)
    end)
    -- baseline what is already in your bags so login does not spam
    C_Timer.After(10, function()
        if ns.FindUpgrades and not primed then
            local ok, list = pcall(ns.FindUpgrades)
            if ok and list then for _, u in ipairs(list) do seen[u.link] = true end end
            primed = true
        end
    end)
end
