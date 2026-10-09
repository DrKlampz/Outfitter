local _, ns = ...
local frame
local rows = {}
local tab = "bags"

local ROW_H, ROWS = 24, 12
local stride = ROW_H
local TOP = 90          -- y of the first row
local WIDTH = 470

local function Button(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function Row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, frame)
    r:SetSize(WIDTH - 32, ROW_H)
    r:SetPoint("TOPLEFT", 16, -TOP - (i - 1) * ROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(22, 22)
    r.icon:SetPoint("LEFT", 0, 0)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.name:SetWidth(250)
    r.name:SetJustifyH("LEFT")
    r.name:SetMaxLines(1)
    r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.sub:SetPoint("TOPLEFT", r.icon, "BOTTOMRIGHT", 6, -1)
    r.sub:SetWidth(WIDTH - 32 - 34)
    r.sub:SetJustifyH("LEFT")
    r.sub:SetMaxLines(1)
    r.note = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.note:SetPoint("RIGHT", -2, 0)
    r.note:SetWidth(150)
    r.note:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", function(self)
        if self.link and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            GameTooltip:Show()
        end
    end)
    r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    r:SetScript("OnClick", function(self)
        if self.link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(self.link) end
    end)
    rows[i] = r
    return r
end

local function Resize(n)
    if n < 6 then n = 6 end
    frame:SetHeight(TOP + n * stride + 36)
end

local function Fill(i, link, note, sub, label)
    local r = Row(i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 16, -TOP - (i - 1) * stride)
    r:SetHeight(stride)
    r.sub:SetText(sub or "")
    r.name:ClearAllPoints()
    if sub then r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, -1)
    else r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0) end
    r.note:ClearAllPoints()
    if sub then r.note:SetPoint("TOPRIGHT", -2, -2) else r.note:SetPoint("RIGHT", -2, 0) end
    r.link = link
    local tex = ns.ItemIcon(link) or "Interface\\Icons\\INV_Misc_QuestionMark"
    r.icon:SetTexture(tex)
    r.name:SetText(label or link or "")
    r.note:SetText(note or "")
    r:Show()
end

function ns.RefreshUI()
    if not frame or not frame:IsShown() then return end
    for _, r in ipairs(rows) do r:Hide() end
    stride = ROW_H
    frame.empty:SetWidth(WIDTH - 40)
    local spec = ns.Spec()
    local class = ns.Class()
    if not spec then
        frame.info:SetText("Outfitter has no weights for your class.")
        frame.specBtn:Hide()
        return
    end
    frame.specBtn:Show()
    frame.specBtn.text:SetText(spec.name)
    frame.info:SetText(("%s |cffaaaaaa(%s)|r   level %d"):format(class:sub(1, 1) .. class:sub(2):lower(), spec.role, UnitLevel("player") or 0))
    for k, b in pairs(frame.tabs) do b:SetEnabled(k ~= tab) end
    if tab == "bags" then
        local ok, list = pcall(ns.FindUpgrades)
        if not ok then
            frame.empty:SetText("|cffff6060Error:|r " .. tostring(list))
            frame.empty:SetWidth(WIDTH - 40)
            frame.empty:Show()
            frame.more:SetText("")
            Resize(6)
            return
        end
        if #list == 0 then
            frame.empty:SetText("Nothing in your bags beats what you're wearing.")
            frame.empty:Show()
        else
            frame.empty:Hide()
        end
        for i = 1, math.min(#list, ROWS) do
            local u = list[i]
            local slot = ns.SLOT_NAMES[u.slot] or "?"
            local note
            if u.empty then note = ("|cff40ff40empty %s|r"):format(slot)
            elseif u.gain > 300 then note = ("|cff40ff40big upgrade|r %s"):format(slot)
            else note = ("|cff40ff40+%d%%|r %s"):format(math.floor(u.gain + 0.5), slot) end
            if u.tooHigh then note = note .. (" |cffffaa00lvl %d|r"):format(u.tooHigh) end
            Fill(i, u.link, note)
        end
        Resize(math.min(#list, ROWS))
        frame.more:SetText(#list > ROWS and ("+%d more"):format(#list - ROWS) or "")
    elseif tab == "worn" then
        frame.empty:Hide()
        local list = ns.EquippedScores()
        Resize(math.min(#list, 19))
        local i = 0
        for _, e in ipairs(list) do
            i = i + 1
            if i > 19 then break end
            if e.link then Fill(i, e.link, ("%s  |cffaaaaaa%d pts|r"):format(ns.SLOT_NAMES[e.slot] or "?", math.floor(e.score + 0.5)))
            else Fill(i, nil, ("|cffff6060empty|r %s"):format(ns.SLOT_NAMES[e.slot] or "?")) end
        end
        frame.more:SetText("")
    elseif tab == "ah" then
        local st = ns.AH
        if not ns.AuctionAvailable() then
            Resize(6)
            frame.empty:SetText("No auction prices yet.\nOpen the Auction House and wait for the scan to finish (Profiteer or Outfitter reads it), then come back.")
            frame.empty:Show()
            frame.more:SetText("")
            return
        end
        if not st.ready then ns.AuctionStart() end
        stride = 34
        if st.running then
            Resize(6)
            frame.empty:SetText(("Checking auction items... %d of %d"):format(st.done, st.total) .. ((st.errors or 0) > 0 and ("\n(%d unreadable, last: %s)"):format(st.errors, tostring(st.lastError):sub(1, 90)) or ""))
            frame.empty:Show()
            frame.more:SetText("")
            return
        end
        local list = st.list
        local shown = math.min(#list, 12)
        if shown == 0 then
            frame.empty:SetText(((st.errors or 0) > 0 and ("%d items couldn't be read (%s). "):format(st.errors, tostring(st.lastError)) or "") .. "Nothing for sale in the last scan beats what you're wearing.")
            frame.empty:Show()
        else
            frame.empty:Hide()
        end
        for i = 1, shown do
            local e = list[i]
            local slot = ns.SLOT_NAMES[e.slot] or "?"
            local note = e.empty and ("|cff40ff40empty %s|r"):format(slot)
                or (e.gain > 300 and ("|cff40ff40big upgrade|r %s"):format(slot)
                or ("|cff40ff40+%d%%|r %s"):format(math.floor(e.gain + 0.5), slot))
            local afford = (GetMoney and GetMoney() or 0) >= e.price
            local age = e.time and time and math.max(0, time() - e.time)
            local ageText = age and (age >= 86400 and ("%dd ago"):format(age / 86400) or age >= 3600 and ("%dh ago"):format(age / 3600) or ("%dm ago"):format(age / 60)) or "?"
            local sub = ("%s%s|r  (%s listed, scanned %s)"):format(afford and "|cffffffff" or "|cffff6060", ns.Money(e.price), tostring(e.n or "?"), ageText)
            Fill(i, e.link, note, sub, e.link)
        end
        Resize(math.max(shown, 5))
        frame.more:SetText(#list > shown and ("+%d more"):format(#list - shown) or "")
    else
        local list, pending, checked = ns.FindSources()
        if not list then
            Resize(6)
            frame.empty:SetText("Nothing to check yet. The Auction tab works for every class.")
            frame.empty:Show()
            frame.more:SetText("")
            return
        end
        stride = 34
        local shown = math.min(#list, 12)
        if shown == 0 then
            frame.empty:SetText(pending > 0 and "Loading item data from the game... reopen in a moment."
                or (checked or 0) == 0 and ("Nothing to check at level %d yet. Where to get uses the built-in cloth lists plus gear your other characters hold or can craft (needs Profiteer). Try the Auction tab."):format(UnitLevel("player") or 0)
                or ("Checked %d known items for level %d: none beat what you're wearing. Try the Auction tab."):format(checked or 0, UnitLevel("player") or 0))
            frame.empty:Show()
        else
            frame.empty:Hide()
        end
        for i = 1, shown do
            local e = list[i]
            local slot = ns.SLOT_NAMES[e.slot] or "?"
            local note = e.empty and ("|cff40ff40empty %s|r"):format(slot)
                or (e.gain > 300 and ("|cff40ff40big upgrade|r %s"):format(slot)
                or ("|cff40ff40+%d%%|r %s"):format(math.floor(e.gain + 0.5), slot))
            note = note .. (e.tooHigh and (" |cffffaa00lvl %d|r"):format(e.tooHigh) or "")
            local src = ("%s: %s"):format(e.how:sub(1, 1):upper() .. e.how:sub(2), e.where)
            if e.note ~= "" then src = src .. " (" .. e.note .. ")" end
            Fill(i, e.link, note, src, ("|cff%s%s|r"):format("1eff00", e.name))
        end
        Resize(math.max(shown, 5))
        frame.more:SetText(#list > shown and ("+%d more"):format(#list - shown) or "")
    end
end

local function Build()
    frame = CreateFrame("Frame", "OutfitterFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WIDTH, 300)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetToplevel(true)
    if frame.TitleText then frame.TitleText:SetText("Outfitter") end
    if frame.title then frame.title:SetText("Outfitter") end
    frame.info = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.info:SetPoint("TOPLEFT", 16, -34)
    -- spec drop-down: a button that opens a list of every spec for the class.
    -- Built by hand (no UIDropDownMenu) so nothing taints the game's menus.
    frame.specBtn = Button(frame, "", 150, function() frame.menu:SetShown(not frame.menu:IsShown()) end)
    frame.specBtn:SetPoint("TOPRIGHT", -14, -32)
    frame.specBtn.text = frame.specBtn:GetFontString() or frame.specBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.specBtn.arrow = frame.specBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.specBtn.arrow:SetPoint("RIGHT", -8, 0)
    frame.specBtn.arrow:SetText("v")
    local menu = CreateFrame("Frame", nil, frame)
    menu:SetFrameStrata("DIALOG")
    menu:SetPoint("TOPRIGHT", frame.specBtn, "BOTTOMRIGHT", 0, 0)
    menu:SetWidth(190)
    menu.bg = menu:CreateTexture(nil, "BACKGROUND")
    menu.bg:SetAllPoints()
    menu.bg:SetColorTexture(0.05, 0.05, 0.08, 0.97)
    menu.items = {}
    menu:Hide()
    frame.menu = menu
    function menu.Populate()
        local list = ns.Weights[ns.Class()] or {}
        local cur = ns.SpecIndex()
        for i, sp in ipairs(list) do
            local b = menu.items[i]
            if not b then
                b = CreateFrame("Button", nil, menu)
                b:SetSize(190, 22)
                b:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
                b.t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                b.t:SetPoint("LEFT", 8, 0)
                b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                b:SetScript("OnClick", function(self)
                    menu:Hide()
                    ns.SetSpec(self.idx)
                end)
                menu.items[i] = b
            end
            b.idx = i
            b.t:SetText((i == cur and "|cffffd100" or "") .. sp.name .. " |cff999999(" .. sp.role .. ")|r")
            b:Show()
        end
        for i = #list + 1, #menu.items do menu.items[i]:Hide() end
        menu:SetHeight(math.max(22, #list * 22))
    end
    menu:SetScript("OnShow", menu.Populate)
    frame.tabs = {}
    local x = 14
    for _, t in ipairs({ { "bags", "Bag upgrades" }, { "worn", "What I wear" }, { "src", "Where to get" }, { "ah", "Auction" } }) do
        local b = Button(frame, t[2], 104, function() tab = t[1] ns.RefreshUI() end)
        b:SetPoint("TOPLEFT", x, -58)
        frame.tabs[t[1]] = b
        x = x + 108
    end
    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.empty:SetPoint("TOP", 0, -TOP - 30)
    frame.more = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.more:SetPoint("BOTTOMLEFT", 16, 12)
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMRIGHT", -16, 12)
    hint:SetText("Hover an item for details")
    frame:SetScript("OnHide", function() menu:Hide() end)
    frame:SetScript("OnShow", function() ns.cache = {} ns.RefreshUI() end)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    ev:SetScript("OnEvent", function(_, event)
        if event == "GET_ITEM_INFO_RECEIVED" then
            if tab ~= "src" or not frame:IsShown() or frame.pend then return end
            frame.pend = true      -- one refresh for a burst of item data
            C_Timer.After(0.5, function() frame.pend = nil ns.RefreshUI() end)
            return
        end
        ns.cache = {}
        if ns.AuctionDirty then ns.AuctionDirty() end
        ns.RefreshUI()
    end)
    table.insert(UISpecialFrames, "OutfitterFrame")
end

function ns.ToggleUI()
    if not frame then Build() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function ns.OpenTab(t)
    if not frame then Build() end
    tab = t
    frame:Show()
    ns.RefreshUI()
end
