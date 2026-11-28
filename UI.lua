local _, ns = ...
local frame
local rows = {}
local tab = "bags"

local ROW_H, ROWS = 24, 12
local stride = ROW_H
local usedH = 0         -- height of the rows placed so far (rows can wrap onto extra lines)
local wrapSub = false   -- Where-to-get rows let the second line wrap instead of cutting it off
local TOP = 90          -- y of the first row
local WIDTH = 500

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
        if self.wear and not (IsModifiedClick and IsModifiedClick("CHATLINK")) then ns.ProfWear(self.wear) return end
        if self.link and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(self.link) end
    end)
    rows[i] = r
    return r
end

local function Resize(n)
    if n < 6 then n = 6 end
    frame:SetHeight(TOP + n * stride + 36 + (tab == "src" and 22 or 0))
    if frame.srcFilter then frame.srcFilter:SetShown(tab == "src") end
end

-- "item:1234::::" strings show as raw text; turn them into the real colored item link once the game knows it
local function LinkText(link)
    if type(link) ~= "string" or link:find("|H", 1, true) then return link end
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if fn then
        local ok, name, full = pcall(fn, link)
        if ok and type(full) == "string" then return full end
        if ok and type(name) == "string" then return name end
    end
    -- the game has not loaded this item yet (auction items you have never seen): ask for it and show a placeholder
    -- until it arrives, instead of the raw item string
    local id = tonumber(link:match("item:(%d+)"))
    if id then
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
        return "Item " .. id .. " (loading...)"
    end
    return link
end

local function Fill(i, link, note, sub, label, icon, equip)
    local r = Row(i)
    r:ClearAllPoints()
    r.sub:SetMaxLines(wrapSub and 0 or 1)
    r.sub:SetWordWrap(wrapSub)
    r.sub:SetText(sub or "")
    local h = stride
    if wrapSub and sub then
        -- count lines ourselves (the game only knows the real height after it has laid the text out)
        local plain = sub:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        local lines = 0
        for seg in (plain .. "\n"):gmatch("(.-)\n") do lines = lines + math.max(1, math.ceil(#seg / 62)) end
        h = 26 + lines * 12
        local sh = r.sub.GetStringHeight and r.sub:GetStringHeight()
        if type(sh) == "number" and sh > 0 then h = math.max(h, 18 + sh + 8) end
        h = math.max(h, stride)
    end
    if i == 1 then usedH = 0 end
    r:SetPoint("TOPLEFT", 16, -TOP - (wrapSub and usedH or (i - 1) * stride))
    r:SetHeight(h)
    usedH = usedH + h
    r.icon:ClearAllPoints()
    if sub then r.icon:SetPoint("TOPLEFT", 0, -2) else r.icon:SetPoint("LEFT", 0, 0) end   -- keep the icon on the first line of a tall row
    r.name:ClearAllPoints()
    if sub then r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, -1)
    else r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0) end
    r.note:ClearAllPoints()
    if sub then r.note:SetPoint("TOPRIGHT", -2, -2) else r.note:SetPoint("RIGHT", -2, 0) end
    r.link = link
    r.wear = equip
    local tex = icon or ns.ItemIcon(link) or "Interface\\Icons\\INV_Misc_QuestionMark"
    r.icon:SetTexture(tex)
    r.name:SetText(label or LinkText(link) or "")
    r.note:SetText(note or "")
    r:Show()
end


local function Clean(t) return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
-- Professions tab: gear and consumables that raise a profession skill or speed it up
local function DrawProf()
    frame.empty:Hide()
    frame.more:SetText("")
    local groups, pending = ns.ProfGear()
    if pending > 0 and not frame.retry and (frame.retries or 0) < 60 then
        frame.retry = true
        frame.retries = (frame.retries or 0) + 1
        C_Timer.After(0.4, function() frame.retry = nil ns.RefreshUI() end)
    end
    stride = 34
    wrapSub = true
    local n = 0
    for _, g in ipairs(groups) do
        if n < 40 then
            n = n + 1
            local total = g.total > 0 and ("|cff40ff40worn +%d|r"):format(g.total) or "|cffaaaaaanone worn|r"
            Fill(n, nil, total, #g.bag > 0 and ("%d in your bags"):format(#g.bag) or "nothing else in your bags", "|cffffd100" .. g.prof.name .. "|r", g.prof.icon)
        end
        for _, w in ipairs(g.worn) do
            if n < 40 then
                n = n + 1
                Fill(n, w.link, "|cff40ff40worn|r", w.text, nil)
            end
        end
        for _, b in ipairs(g.bag) do
            if n < 40 then
                n = n + 1
                local note, sub = b.value > 0 and ("|cff40ff40+%d|r"):format(b.value) or "|cff40ff40faster|r", b.text
                local equip
                if b.use then
                    note = "|cffffd100use it|r"
                elseif b.swapSlot then
                    local slotName = ns.SLOT_NAMES and ns.SLOT_NAMES[b.swapSlot] or "slot"
                    local over = b.swapLink and (LinkText(b.swapLink) or "?") or "empty"
                    sub = sub .. "\n|cffaaaaaaClick to wear in " .. slotName:lower() .. ", replacing " .. Clean(over)
                    if b.swapValue > 0 then sub = sub .. " (+" .. b.swapValue .. ")" end
                    if b.gain then
                        sub = sub .. (b.gain >= 0 and "  |cff40ff40" or "  |cffff8040") .. ("%+d%% overall"):format(math.floor(b.gain + 0.5))
                    end
                    sub = sub .. "|r"
                    equip = b
                end
                Fill(n, b.link, note, sub, nil, nil, equip)
            end
        end
    end
    if n == 0 then
        if pending > 0 then
            frame.empty:SetText("Loading item data from the game... one moment.")
        else
            frame.empty:SetText("Nothing you wear or carry changes a profession skill. Fishing hats and poles, mining and skinning gear show up here as soon as you have them.")
        end
        frame.empty:Show()
    end
    Resize(math.max(n, 5))
    frame:SetHeight(TOP + math.max(usedH, 5 * stride) + 36)
end

local combatDirty
function ns.RefreshUI()
    if not frame or not frame:IsShown() then return end
    if InCombatLockdown and InCombatLockdown() then combatDirty = true return end   -- redo after the fight
    for _, r in ipairs(rows) do r:Hide() end
    stride = ROW_H
    wrapSub = false
    usedH = 0
    frame.empty:SetWidth(WIDTH - 40)
    local spec = ns.Spec()
    local class = ns.Class()
    if not spec then
        frame.info:SetText("Gearhawk has no weights for your class.")
        frame.specBtn:Hide()
        return
    end
    frame.specBtn:Show()
    frame.specBtn.text:SetText(spec.name)
    frame.info:SetText(("%s |cffaaaaaa(%s)|r   level %d"):format(class:sub(1, 1) .. class:sub(2):lower(), spec.role, UnitLevel("player") or 0))
    for k, b in pairs(frame.tabs) do b:SetEnabled(k ~= tab) end
    if tab == "prof" then DrawProf() return end
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
        for i = 1, math.min(#list, ROWS) do if list[i].combo then stride = 34 wrapSub = true break end end   -- pairs get a second line
        for i = 1, math.min(#list, ROWS) do
            local u = list[i]
            local slot = ns.SLOT_NAMES[u.slot] or "?"
            local note
            if u.empty then note = ("|cff40ff40empty %s|r"):format(slot)
            elseif u.gain > 300 then note = ("|cff40ff40big upgrade|r %s"):format(slot)
            else note = ("|cff40ff40+%d%%|r %s"):format(math.floor(u.gain + 0.5), slot) end
            if u.tooHigh then note = note .. (" |cffffaa00lvl %d|r"):format(u.tooHigh) end
            local sub
            if u.combo and LinkText then
                local pn = LinkText(u.combo)
                if pn then sub = "|cffaaaaaaas a pair with " .. Clean(pn) .. (u.comboOwned == "bag" and " (also in your bags)" or " (worn)") .. "|r" end
            end
            Fill(i, u.link, note, sub)
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
            frame.empty:SetText("No auction prices yet.\nOpen the Auction House and wait for the scan to finish (Gearhawk reads it, and so can another installed add-on that saves scans), then come back.")
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
            frame.empty:SetText(((st.errors or 0) > 0 and ("%d items couldn't be read (%s). "):format(st.errors, tostring(st.lastError)) or "") .. "Nothing for sale in the last scan beats what you're wearing."
                .. (st.why and (("\n|cffaaaaaaOf %d listings: %d need a higher level than %d, %d can't be used by your class or skills, %d are no better than yours, %d aren't gear.|r"):format(st.total or 0, st.why.tooHigh, UnitLevel("player") or 0, st.why.unusable, st.why.noGain, st.why.notGear)) or ""))
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
            Fill(i, e.link, note, sub)
        end
        Resize(math.max(shown, 5))
        frame.more:SetText(#list > shown and ("+%d more"):format(#list - shown) or "")
    else
        for _, cb in ipairs(frame.srcFilter.boxes) do cb:SetChecked(ns.SourceOn(cb.kind)) end
        local list, pending, checked = ns.FindSources()
        if not list then
            Resize(6)
            frame.empty:SetText("Nothing to check yet. The Auction tab works for every class.")
            frame.empty:Show()
            frame.more:SetText("")
            return
        end
        stride = 34
        wrapSub = true
        if pending > 0 and not frame.retry and (frame.retries or 0) < 60 then
            frame.retry = true      -- still working through the list: look again shortly (at most ~25 seconds)
            frame.retries = (frame.retries or 0) + 1
            C_Timer.After(0.4, function() frame.retry = nil ns.RefreshUI() end)
        end
        local shown = #list
        if shown == 0 then
            frame.empty:SetText(pending > 0 and "Loading item data from the game... one moment."
                or (checked or 0) == 0 and ("Nothing to check at level %d yet. What to get uses the built-in cloth lists plus gear your other characters hold or can craft (shown when that saved data is available). Try the Auction tab."):format(UnitLevel("player") or 0)
                or ("Checked %d known items for level %d: none beat what you're wearing. Try the Auction tab."):format(checked or 0, UnitLevel("player") or 0))
            frame.empty:Show()
        else
            frame.empty:Hide()
        end
        -- vendors you have visited that turned out not to sell the item: listed last, with a note
        do
            local ok, rest = {}, {}
            for _, e in ipairs(list) do
                if ns.VendorOutOfStock and ns.VendorOutOfStock(e) then rest[#rest + 1] = e else ok[#ok + 1] = e end
            end
            for _, e in ipairs(rest) do ok[#ok + 1] = e end
            list = ok
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
            local gone = ns.VendorOutOfStock and ns.VendorOutOfStock(e)
            if gone then
                src = src .. "\n|cffff6060You checked " .. gone .. ": not for sale right now|r"
            elseif e.how == "vendor" and ns.VendorCost then
                local c = ns.VendorCost(e.id)
                src = src .. (c and ("\n|cffffd100Cost: " .. c .. "|r") or "\n|cffaaaaaaCost: unknown until you visit the vendor|r")
            end
            local real = LinkText(e.link)
            Fill(i, e.link, note, src, (real and real ~= e.link) and real or ("|cff%s%s|r"):format("1eff00", e.name))
        end
        Resize(5)
        if shown > 0 then frame:SetHeight(TOP + math.max(usedH, 5 * stride) + 36 + 22) end   -- +22: the Quest/Dungeon/Battleground/Vendor row sits at the bottom
        frame.more:SetText("")
    end
end

local function Build()
    frame = ns.WinLook.NewWindow("GearhawkFrame")
    frame:SetSize(WIDTH, 300)
    if ns.WinLook then ns.WinLook.Attach("main", frame) end
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetToplevel(true)
    if frame.TitleText then frame.TitleText:SetText("Gearhawk") end
    if frame.title then frame.title:SetText("Gearhawk") end
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
    for _, t in ipairs({ { "bags", "Inventory" }, { "worn", "Equipped" }, { "src", "What to get" }, { "ah", "Auction" }, { "prof", "Professions" }, { "bis", "Best in slot" } }) do
        local b = Button(frame, t[2], 78, function()
            if t[1] == "bis" then if ns.ToggleBis then ns.ToggleBis() end return end    -- opens its own window
            tab = t[1] ns.RefreshUI()
        end)
        b:SetPoint("TOPLEFT", x, -58)
        frame.tabs[t[1]] = b
        x = x + 80
    end
    -- What to get: which kinds of source this character wants to see
    frame.srcFilter = CreateFrame("Frame", nil, frame)
    frame.srcFilter:SetSize(WIDTH - 28, 20)
    frame.srcFilter:SetPoint("BOTTOMLEFT", 14, 30)
    frame.srcFilter.boxes = {}
    local fx = 0
    for _, k in ipairs({ { "quest", "Quest" }, { "dungeon", "Dungeon" }, { "battleground", "Battleground" }, { "vendor", "Vendor" } }) do
        local cb = CreateFrame("CheckButton", nil, frame.srcFilter, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("LEFT", fx, 0)
        cb.kind = k[1]
        local fs = cb.Text or cb.text or cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetText(k[2])
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", cb, "RIGHT", 0, 1)
        cb.label = fs
        cb:SetScript("OnClick", function(self)
            ns.SetSourceOn(self.kind, self:GetChecked() and true or false)
            ns.cache = {}
            ns.RefreshUI()
        end)
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Show " .. self.label:GetText():lower() .. " gear in What to get", 1, 1, 1)
            GameTooltip:AddLine("Saved for this character only.", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
        frame.srcFilter.boxes[#frame.srcFilter.boxes + 1] = cb
        fx = fx + 28 + math.max(40, (fs:GetStringWidth() or 40))
    end
    frame.srcFilter:Hide()
    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.empty:SetPoint("TOP", 0, -TOP - 30)
    frame.more = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.more:SetPoint("BOTTOMLEFT", 16, 12)
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMRIGHT", -16, 12)
    hint:SetText("Hover an item for details")
    frame:SetScript("OnHide", function() menu:Hide() end)
    frame:SetScript("OnShow", function() ns.cache = {} ns.srcTries = {} frame.retries = 0 ns.RefreshUI() end)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("BAG_UPDATE_DELAYED")
    ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if combatDirty then combatDirty = nil ns.cache = {} ns.RefreshUI() end
            return
        end
        if event == "GET_ITEM_INFO_RECEIVED" then
            if (tab ~= "src" and tab ~= "ah") or not frame:IsShown() or frame.pend then return end
            frame.pend = true      -- one refresh for a burst of item data
            C_Timer.After(0.5, function() frame.pend = nil ns.RefreshUI() end)
            return
        end
        ns.cache = {}
        ns.srcTries = {} frame.retries = 0
        -- only a change to what you wear (or your level) changes the auction answer; bag shuffles don't
        if event ~= "BAG_UPDATE_DELAYED" and ns.AuctionDirty then ns.AuctionDirty() end
        ns.RefreshUI()
    end)
    table.insert(UISpecialFrames, "GearhawkFrame")
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
