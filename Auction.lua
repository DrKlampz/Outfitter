local _, ns = ...

-- Gear you could buy right now. Prices come from the last full Auction House scan that
-- Profiteer saved; every equippable item in it is read from its real tooltip and scored
-- against what you wear, exactly like the bag upgrades.
local state = { running = false, ready = false, done = 0, total = 0, list = {}, newest = nil }
ns.AH = state

local function Prices()
    local db = _G.ProfiteerDB
    return db and db.prices
end

-- Gear read straight from the full Auction House scan (every listing with its real item link,
-- random suffix and all), saved in OutfitterDB.ah = { time, items = { ["item:..."] = { p = lowest buyout, n = listings } } }
local function Saved()
    local ah = ns.db and ns.db.ah
    if ah and type(ah.items) == "table" and next(ah.items) then return ah end
end

function ns.AuctionAvailable()
    if Saved() then return true end
    local p = Prices()
    return p ~= nil and next(p) ~= nil
end

local ingest
local function IngestStep()
    local C = _G.C_AuctionHouse
    local g = ingest
    if not g or not C then return end
    local last = math.min(g.i + 399, g.n - 1)
    for i = g.i, last do
        local ok = pcall(function()
            local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, id = C.GetReplicateItemInfo(i)
            if not id or not buyout or buyout <= 0 then return end
            local link = C.GetReplicateItemLink and C.GetReplicateItemLink(i)
            local str = type(link) == "string" and link:match("(item:[^|]+)") or ("item:" .. id)
            if g.seen[str] == false then return end
            if g.seen[str] == nil then
                local loc = ns.EquipLoc(str)
                if not loc or not ns.SlotsFor(loc) then g.seen[str] = false return end
                g.seen[str] = true
            end
            local unit = buyout / math.max(1, count or 1)
            local e = g.items[str]
            if not e then g.items[str] = { p = unit, n = 1 }
            else e.n = e.n + 1 if unit < e.p then e.p = unit end end
        end)
        if not ok then g.errors = (g.errors or 0) + 1 end
    end
    g.i = last + 1
    if g.i >= g.n then
        ns.db.ah = { time = time and time() or 0, items = g.items }
        ingest = nil
        ns.AuctionDirty()
        if ns.RefreshUI then ns.RefreshUI() end
    else
        C_Timer.After(0.02, IngestStep)
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
ev:SetScript("OnEvent", function()
    local C = _G.C_AuctionHouse
    if not C or not C.GetNumReplicateItems or ingest then return end
    local n = C.GetNumReplicateItems() or 0
    if n == 0 then return end
    ingest = { i = 0, n = n, items = {}, seen = {} }
    C_Timer.After(0.5, IngestStep)    -- after Profiteer has had its look
end)

-- call when anything that changes the answer happens (gear, level, spec)
function ns.AuctionDirty()
    state.ready = false
end

local BATCH = 60

local function Finish()
    local out = {}
    for _, r in pairs(state.found) do out[#out + 1] = r end
    table.sort(out, function(a, b)
        if a.gain ~= b.gain then return a.gain > b.gain end
        return a.price < b.price
    end)
    state.list = ns.BestPerSlot(out)
    state.running, state.ready = false, true
    if ns.RefreshUI then ns.RefreshUI() end
end

local function Step()
    if not state.running then return end
    local ids, level = state.ids, UnitLevel() or 1
    local last = math.min(state.i + BATCH - 1, #ids)
    for k = state.i, last do
        local id = ids[k]
        local p = state.prices[id]
        local link = state.links and id or ("item:" .. id)
        local ok, err = pcall(function()
            local loc = ns.EquipLoc(link)
            if loc and ns.SlotsFor(loc) then
                local r = ns.Compare(link)
                if r == nil then
                    state.pend[#state.pend + 1] = id          -- item data not loaded yet
                elseif not r.isWorn and not r.unusable and not r.tooHigh
                    and (r.empty or (r.gain and r.gain >= (ns.db.minGain or 3))) then
                    if r.empty then r.gain = 1000 + (r.score or 0) end
                    r.link, r.id, r.price, r.n, r.time = link, id, p.min, p.n, p.time
                    state.found[id] = r
                end
            end
        end)
        if not ok then
            state.errors = (state.errors or 0) + 1
            state.lastError = tostring(err)
        end
    end
    state.i, state.done = last + 1, last
    if state.i > #ids then
        if #state.pend > 0 and state.pass < 3 then
            state.pass = state.pass + 1
            state.ids, state.i, state.pend = state.pend, 1, {}
            C_Timer.After(1.2, Step)                      -- give the game time to send item data
        else
            Finish()
        end
        return
    end
    if ns.RefreshUI then ns.RefreshUI() end
    C_Timer.After(0.03, Step)
end

function ns.AuctionStart()
    if state.running then return end
    local ids, newest = {}, nil
    local prices
    local saved = Saved()
    if saved then
        -- real listings with their links: random-suffix items ("of Frozen Wrath") are read correctly
        prices = {}
        for str, e in pairs(saved.items) do
            prices[str] = { min = e.p, n = e.n, time = saved.time }
            ids[#ids + 1] = str
        end
        newest = saved.time
        state.links = true
    else
        prices = Prices()
        if not prices then return end
        state.links = false
        for id, p in pairs(prices) do
            if type(id) == "number" and type(p) == "table" and p.min and p.min > 0 then
                ids[#ids + 1] = id
                if p.time and (not newest or p.time > newest) then newest = p.time end
            end
        end
    end
    table.sort(ids, function(x, y) return tostring(x) < tostring(y) end)
    state.errors, state.lastError = 0, nil
    state.prices, state.ids, state.i, state.total, state.done = prices, ids, 1, #ids, 0
    state.found, state.pend, state.pass, state.newest = {}, {}, 0, newest
    state.running, state.ready = true, false
    Step()
end
