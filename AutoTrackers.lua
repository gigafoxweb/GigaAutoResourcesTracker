local addonName = ...
local events = CreateFrame("Frame")
local window, refresh, ready, pending
local lastAttempt = -10
local lastError
local settingsPanel, settingsRefresh, settingsCategory
local restoreRequested, wasDead = false, false
local restoreAttempts = 0

local function RequestRestore()
    restoreRequested = true
    restoreAttempts = 0
    lastAttempt = -10
end

local function Available()
    return C_Minimap and C_Minimap.GetNumTrackingTypes
        and C_Minimap.GetTrackingInfo and C_Minimap.SetTracking
end

local function Trackers()
    local list = {}
    if not Available() then return list end
    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info, texture, active, category, subType, spellID = C_Minimap.GetTrackingInfo(index)
        if type(info) ~= "table" then
            info = { name = info, texture = texture, active = active,
                type = category, subType = subType, spellID = spellID }
        end
        -- Exclude service/vendor minimap filters; show tracking abilities only.
        if info.name and (info.type == "spell" or (info.spellID and info.spellID > 0)) then
            list[#list + 1] = { index = index, name = info.name, texture = info.texture, spellID = info.spellID,
                active = info.active == true or info.active == 1,
                key = info.spellID and info.spellID > 0 and ("spell:" .. info.spellID)
                    or ("name:" .. info.name) }
        end
    end
    return list
end

local function Priority(info)
    local ids = { [2383] = 1, [2580] = 1, [43308] = 2, [19883] = 3, [5225] = 3 }
    if ids[info.spellID] then return ids[info.spellID] end
    -- Some clients omit spellID from tracking entries; compare localized spell names.
    if C_Spell and C_Spell.GetSpellName then
        for id, priority in pairs(ids) do
            if info.name == C_Spell.GetSpellName(id) then return priority end
        end
    end
    return 4
end

local function EnsureSelection(trackers)
    if AutoTrackersDB.selected and not AutoTrackersDB.automaticSelection then return end
    local best
    for _, info in ipairs(trackers) do
        if not best or Priority(info) < Priority(best)
            or (Priority(info) == Priority(best) and info.key == AutoTrackersDB.selected) then
            best = info
        end
    end
    if best then
        AutoTrackersDB.selected = best.key
        AutoTrackersDB.selectedName = best.name
        AutoTrackersDB.automaticSelection = true
    end
end

local function ActiveTracker(trackers)
    for _, info in ipairs(trackers) do
        if info.active then return info end
    end
end

local function Restore()
    if not ready or not Available() then return end
    if AutoTrackersDB.mode ~= "always" and not restoreRequested then return end
    local trackers = Trackers()
    EnsureSelection(trackers)
    -- Any active tracking ability satisfies the request, including a manual choice.
    -- Clear pending recovery even in combat so it cannot override that choice later.
    if ActiveTracker(trackers) then
        restoreRequested = false
        return
    end
    if UnitIsDeadOrGhost("player") or InCombatLockdown() then return end
    for _, info in ipairs(trackers) do
        if info.key == AutoTrackersDB.selected then
            if not info.active and GetTime() - lastAttempt >= 2 then
                lastAttempt = GetTime()
                restoreAttempts = restoreAttempts + 1
                local ok, err = pcall(C_Minimap.SetTracking, info.index, true)
                -- Finish this one-time restore after the API accepts it. Later
                -- manual changes must not start another restore in recovery mode.
                if ok or restoreAttempts >= 5 then restoreRequested = false end
                if not ok and tostring(err) ~= lastError then
                    lastError = tostring(err)
                    print("|cffffcc00Auto Trackers:|r " .. lastError)
                end
            end
            return
        end
    end
end

local function Schedule()
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        Restore()
        if window and window:IsShown() then refresh() end
        if settingsPanel and settingsPanel:IsShown() then settingsRefresh() end
    end)
end

local function BuildOptions(window)
        local description = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        description:SetPoint("TOPLEFT", 18, -40)
        description:SetWidth(350)
        description:SetJustifyH("LEFT")
        description:SetText("Choose a fallback for when no tracking is active.\nYour settings are saved for this character.")

        local modeRows = {}
        local modeHint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        modeHint:SetPoint("TOPLEFT", 20, -146)
        modeHint:SetWidth(345)
        modeHint:SetJustifyH("LEFT")
        for i, mode in ipairs({
            { key = "recovery", label = "Restore after login or resurrection" },
            { key = "always", label = "Keep tracking active" },
        }) do
            local button = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
            button:SetSize(28, 28)
            button:SetPoint("TOPLEFT", 16, -78 - (i - 1) * 30)
            button.key = mode.key
            local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("LEFT", button, "RIGHT", 4, 0)
            label:SetText(mode.label)
            button:SetScript("OnClick", function(self)
                if AutoTrackersDB.mode ~= self.key then
                    AutoTrackersDB.mode = self.key
                    restoreRequested = false
                    if self.key == "always" then RequestRestore() end
                end
                for _, row in ipairs(modeRows) do
                    row:SetChecked(row.key == AutoTrackersDB.mode)
                end
                Schedule()
            end)
            modeRows[i] = button
        end

        local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -195)
        scroll:SetPoint("BOTTOMRIGHT", -34, 250)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(330, 1)
        scroll:SetScrollChild(content)

        local status = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("BOTTOMLEFT", 18, 210)
        status:SetWidth(350)
        status:SetJustifyH("LEFT")

        local credit = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        credit:SetPoint("BOTTOM", 0, 186)
        credit:SetText("Made by Shadowstride")

        local thanks = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        thanks:SetPoint("TOP", credit, "BOTTOM", 0, -8)
        thanks:SetWidth(350)
        thanks:SetJustifyH("CENTER")
        thanks:SetText("Thanks for using Auto Trackers! I hope you're enjoying it.\nIf you'd like to support my work,\nyou can do so on Donatello.")

        local donationURL = "https://donatello.to/shadowstride"
        local donationLink = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
        donationLink:SetSize(300, 22)
        donationLink:SetPoint("BOTTOM", 0, 109)
        donationLink:SetAutoFocus(false)
        donationLink:SetFontObject("GameFontHighlightSmall")
        donationLink:SetJustifyH("CENTER")
        donationLink:SetText(donationURL)
        donationLink:SetCursorPosition(0)
        donationLink:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        donationLink:SetScript("OnMouseUp", function(self) self:HighlightText() end)
        donationLink:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                self:SetText(donationURL)
                self:HighlightText()
            end
        end)
        donationLink:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        donationLink:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        donationLink:SetScript("OnHide", function(self) self:ClearFocus() end)

        local donationHint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        donationHint:SetPoint("BOTTOM", 0, 92)
        donationHint:SetText("Click the link, then press Ctrl+C to copy")

        local bugReportTitle = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bugReportTitle:SetPoint("BOTTOM", 0, 64)
        bugReportTitle:SetText("Found a bug? Leave a comment on CurseForge:")

        local bugReportURL = "https://www.curseforge.com/wow/addons/auto-trackers/comments"
        local bugReportLink = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
        bugReportLink:SetSize(350, 22)
        bugReportLink:SetPoint("BOTTOM", 0, 34)
        bugReportLink:SetAutoFocus(false)
        bugReportLink:SetFontObject("GameFontHighlightSmall")
        bugReportLink:SetJustifyH("LEFT")
        bugReportLink:SetText(bugReportURL)
        bugReportLink:SetCursorPosition(0)
        bugReportLink:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        bugReportLink:SetScript("OnMouseUp", function(self) self:HighlightText() end)
        bugReportLink:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                self:SetText(bugReportURL)
                self:HighlightText()
            end
        end)
        bugReportLink:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        bugReportLink:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        bugReportLink:SetScript("OnHide", function(self) self:ClearFocus() end)

        local bugReportHint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        bugReportHint:SetPoint("BOTTOM", 0, 16)
        bugReportHint:SetText("Click the link, then press Ctrl+C to copy")
        local rows = {}

        local update
        update = function()
            for _, row in ipairs(modeRows) do
                row:SetChecked(row.key == AutoTrackersDB.mode)
            end
            if AutoTrackersDB.mode == "always" then
                modeHint:SetText("Enables your choice whenever no tracking is active.\nLeaves other active tracking abilities unchanged.")
            else
                modeHint:SetText("After login, /reload or resurrection, enables your\nchoice only if no tracking ability is active.")
            end
            local trackers = Trackers()
            local activeTracker = ActiveTracker(trackers)
            EnsureSelection(trackers)
            local options = trackers
            for _, row in ipairs(rows) do row:Hide() end
            local selected
            for i, info in ipairs(options) do
                local row = rows[i]
                if not row then
                    row = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
                    row:SetSize(28, 28)
                    row:SetPoint("TOPLEFT", 0, -(i - 1) * 32)
                    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    row.label:SetPoint("LEFT", row, "RIGHT", 4, 0)
                    row.label:SetWidth(290)
                    row.label:SetJustifyH("LEFT")
                    row:SetScript("OnClick", function(self)
                        AutoTrackersDB.selected = self.key
                        AutoTrackersDB.selectedName = self.trackerName
                        AutoTrackersDB.automaticSelection = false
                        lastError = nil
                        RequestRestore()
                        Restore()
                        update()
                        Schedule()
                    end)
                    rows[i] = row
                end
                row.key, row.trackerName = info.key, info.key and info.name or nil
                row.label:SetText(info.name)
                row:SetChecked(AutoTrackersDB.selected == info.key)
                row:Show()
                if info.key and info.key == AutoTrackersDB.selected then selected = info end
            end
            content:SetHeight(math.max(1, #options * 32))
            if not Available() then
                status:SetText("Tracking API is unavailable in this client.")
            elseif activeTracker then
                status:SetText("Active: " .. activeTracker.name)
            elseif not AutoTrackersDB.selected then
                status:SetText("No tracking abilities available on this character.")
            elseif not selected then
                status:SetText("Saved ability is currently unavailable: " .. (AutoTrackersDB.selectedName or "unknown"))
            elseif UnitIsDeadOrGhost("player") then
                status:SetText("Waiting for resurrection: " .. selected.name)
            elseif AutoTrackersDB.mode ~= "always" and not restoreRequested then
                status:SetText("Inactive: " .. selected.name .. ". Manual changes are respected.")
            elseif InCombatLockdown() then
                status:SetText("Waiting until combat ends: " .. selected.name)
            else
                status:SetText("Waiting to restore: " .. selected.name)
            end
        end
        window:SetScript("OnShow", update)
        return update
end

local function RegisterSettings()
    if settingsCategory then return end
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    settingsPanel = CreateFrame("Frame", "AutoTrackersSettingsPanel", UIParent)
    settingsPanel:Hide()
    local title = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -14)
    title:SetText("Auto Trackers")
    settingsRefresh = BuildOptions(settingsPanel)
    settingsCategory = Settings.RegisterCanvasLayoutCategory(settingsPanel, "Auto Trackers")
    Settings.RegisterAddOnCategory(settingsCategory)
end

local function ShowOptions()
    if not ready then return end
    if not window then
        window = CreateFrame("Frame", "AutoTrackersOptions", UIParent, "BasicFrameTemplateWithInset")
        window:Hide()
        window:SetSize(390, 660)
        window:SetPoint("CENTER")
        window:SetFrameStrata("DIALOG")
        window:SetClampedToScreen(true)
        window:SetMovable(true)
        window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        window.TitleText:SetText("Auto Trackers")
        table.insert(UISpecialFrames, "AutoTrackersOptions")
        refresh = BuildOptions(window)
    end
    window:Show()
    refresh()
end

SLASH_AUTOTRACKERS1 = "/shadowstride-auto-tracker"
SlashCmdList.AUTOTRACKERS = ShowOptions

events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addonName then
            if ready then RegisterSettings() end
            return
        end
        if type(AutoTrackersDB) ~= "table" then AutoTrackersDB = {} end
        if type(AutoTrackersDB.selected) ~= "string" then AutoTrackersDB.selected = nil end
        if type(AutoTrackersDB.selectedName) ~= "string" then AutoTrackersDB.selectedName = nil end
        if AutoTrackersDB.mode ~= "always" and AutoTrackersDB.mode ~= "recovery" then
            AutoTrackersDB.mode = "recovery"
        end
        ready = true
        -- Polling only restores in always mode or while a one-time request is pending.
        C_Timer.NewTicker(3, function()
            Restore()
            if window and window:IsShown() then refresh() end
            if settingsPanel and settingsPanel:IsShown() then settingsRefresh() end
        end)
    end
    if ready then
        if event == "PLAYER_LOGIN" then
            wasDead = UnitIsDeadOrGhost("player") and true or false
            RequestRestore()
        elseif event == "PLAYER_DEAD" then
            wasDead = true
            restoreRequested = false
        elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" or event == "PLAYER_ENTERING_WORLD" then
            if UnitIsDeadOrGhost("player") then
                wasDead = true
            elseif wasDead then
                wasDead = false
                RequestRestore()
            end
        end
    end
    if ready then RegisterSettings() end
    Schedule()
end)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
    "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED",
    "MINIMAP_UPDATE_TRACKING" }) do
    events:RegisterEvent(event)
end
