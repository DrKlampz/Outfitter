local ADDON_NAME, ns = ...
-- Loot roll helper: while a group loot roll is open, a small panel says whether each item is an upgrade for your
-- spec and which button to press. It only advises: it never rolls for you.
local R = {}
ns.Roll = R

local ROWH, MAXROWS = 38, 4
local PAD, TOPH, WIDTH = 14, 34, 360
local rolls = {}     -- list of { id, link, name, tex, verdict, color, expires, tries }
local frame

local function Setting() return not ns.db or ns.db.rollHelper ~= false end
local function Chat() return ns.db and ns.db.rollChat == true end

-- what to do with this item, from Compare(): returns text, r, g, b
local function Verdict(link)
    local r = ns.Compare and ns.Compare(link)
    if r == nil then
        local equip = ns.EquipLoc and ns.EquipLoc(link)
        if equip then return nil end                                   -- gear whose numbers are not readable yet: ask again
        return "Not gear: greed if you want the gold", 0.75, 0.75, 0.75
    end
    if r.unusable then return "Cannot use: greed or pass", 0.9, 0.35, 0.35 end
    if r.tooHigh then return "Needs level " .. r.tooHigh .. ": greed", 0.95, 0.75, 0.3 end
    if r.empty then return "Empty slot: NEED", 0.3, 1, 0.3 end
    local gain = r.gain or 0
    if gain >= (ns.db and ns.db.minGain or 3) then
        return string.format("Upgrade +%d%%: NEED", math.floor(gain + 0.5)), 0.3, 1, 0.3
    end
    return "Not an upgrade: greed", 0.75, 0.75, 0.75
end

local function Build()
    if frame then return frame end
    frame = CreateFrame("Frame", "GearhawkRollFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetFrameStrata("HIGH")
    frame:SetSize(WIDTH, 10)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        frame:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
        frame:SetBackdropBorderColor(0.2, 0.8, 1, 1)
    end
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", PAD, -10)
    frame.title:SetText("Gearhawk: loot roll advice")
    frame.rule = frame:CreateTexture(nil, "ARTWORK")
    frame.rule:SetColorTexture(1, 1, 1, 0.12)
    frame.rule:SetHeight(1)
    frame.rule:SetPoint("TOPLEFT", PAD, -TOPH + 6)
    frame.rule:SetPoint("TOPRIGHT", -PAD, -TOPH + 6)
    frame.rows = {}
    for i = 1, MAXROWS do
        local row = CreateFrame("Frame", nil, frame)
        row:SetHeight(ROWH - 4)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TOPH - (i - 1) * ROWH)
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -TOPH - (i - 1) * ROWH)
        row.accent = row:CreateTexture(nil, "ARTWORK")
        row.accent:SetWidth(3)
        row.accent:SetPoint("TOPLEFT", 0, 0)
        row.accent:SetPoint("BOTTOMLEFT", 0, 0)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(30, 30)
        row.icon:SetPoint("LEFT", 10, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -1)
        row.name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.say = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.say:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 1)
        row.say:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.say:SetJustifyH("LEFT")
        row.say:SetWordWrap(false)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            if self.link then GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetHyperlink(self.link) GameTooltip:Show() end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:Hide()
        frame.rows[i] = row
    end
    frame:Hide()
    if ns.WinLook and ns.WinLook.Attach then pcall(ns.WinLook.Attach, "roll", frame) end
    return frame
end

local function Draw()
    if not Setting() then if frame then frame:Hide() end return end
    local n = math.min(#rolls, MAXROWS)
    if n == 0 then if frame then frame:Hide() end return end
    Build()
    for i = 1, MAXROWS do
        local row, e = frame.rows[i], rolls[i]
        if e and i <= n then
            row.link = e.link
            row.icon:SetTexture(e.tex or 134400)
            row.name:SetText(e.name or e.link or "?")
            row.say:SetText(e.verdict or "reading the item...")
            local c = e.color or { 0.7, 0.7, 0.7 }
            row.say:SetTextColor(c[1], c[2], c[3])
            row.accent:SetColorTexture(c[1], c[2], c[3], 0.9)
            row:Show()
        else
            row:Hide()
        end
    end
    frame:SetHeight(TOPH + n * ROWH + 6)
    frame:Show()
end

local function Resolve(e)
    local text, r, g, b = Verdict(e.link)
    if text then
        e.verdict, e.color = text, { r, g, b }
        if Chat() and not e.said then e.said = true ns.Print((e.name or "item") .. ": " .. text) end
        return true
    end
    return false
end

local function Remove(id)
    for i = #rolls, 1, -1 do if rolls[i].id == id then table.remove(rolls, i) end end
    Draw()
end

local function Tries(e)
    e.tries = (e.tries or 0) + 1
    if Resolve(e) then Draw() return end
    if e.tries < 8 and C_Timer and C_Timer.After then
        C_Timer.After(0.4, function() if e.live then Tries(e) end end)
    else
        e.verdict = "Could not read the item"
        Draw()
    end
end

local function Start(rollID, rollTime)
    if not Setting() then return end
    local link = GetLootRollItemLink and GetLootRollItemLink(rollID)
    local tex, name
    if GetLootRollItemInfo then tex, name = GetLootRollItemInfo(rollID) end
    if not link then return end
    local e = { id = rollID, link = link, tex = tex, name = link, live = true,
        expires = GetTime() + ((tonumber(rollTime) or 60000) / 1000) + 3 }
    rolls[#rolls + 1] = e
    Draw()
    Tries(e)
end

local function Prune()
    local now, changed = GetTime(), false
    for i = #rolls, 1, -1 do
        if rolls[i].expires < now then rolls[i].live = false table.remove(rolls, i) changed = true end
    end
    if changed then Draw() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("START_LOOT_ROLL")
f:RegisterEvent("CANCEL_LOOT_ROLL")
f:RegisterEvent("LOOT_ITEM_ROLL_WON")
f:SetScript("OnEvent", function(_, event, a, b)
    if event == "START_LOOT_ROLL" then
        pcall(Start, a, b)
    elseif event == "CANCEL_LOOT_ROLL" then
        for _, e in ipairs(rolls) do if e.id == a then e.live = false end end
        Remove(a)
    end
end)
f:SetScript("OnUpdate", function(self, dt)
    self.t = (self.t or 0) + dt
    if self.t > 1 then self.t = 0 if #rolls > 0 then Prune() end end
end)

function R.Toggle()
    ns.db.rollHelper = (ns.db.rollHelper == false)
    ns.Print("loot roll advice " .. (ns.db.rollHelper == false and "off" or "on"))
end
