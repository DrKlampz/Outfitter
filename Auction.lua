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

function ns.AuctionAvailable()
    local p = Prices()
    return p ~= nil and next(p) ~= nil
end

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
        local link = "item:" .. id
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
    local prices = Prices()
    if not prices then return end
    local ids, newest = {}, nil
    for id, p in pairs(prices) do
        if type(id) == "number" and type(p) == "table" and p.min and p.min > 0 then
            ids[#ids + 1] = id
            if p.time and (not newest or p.time > newest) then newest = p.time end
        end
    end
    table.sort(ids)
    state.prices, state.ids, state.i, state.total, state.done = prices, ids, 1, #ids, 0
    state.found, state.pend, state.pass, state.newest = {}, {}, 0, newest
    state.running, state.ready = true, false
    Step()
end
