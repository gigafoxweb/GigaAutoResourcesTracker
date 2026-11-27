local addonName = ...
local events = CreateFrame("Frame")
local window, refresh, ready, pending
local lastAttempt = -10
local lastError
local settingsPanel, settingsRefresh, settingsCategory
local restoreRequested, wasDead = false, false
local restoreAttempts = 0
local treasureRequested, treasureAttempts = false, 0
local applyRequested, currentEnvironment, worldLoading = false, nil, false
local isHunter, hunterTargetGUID, hunterTargetReadyAt, worldReturnAt, hunterOverride
local hunterSessionTrackers = {}
local hunterTrackingSpells = {
    [1] = 1494, [2] = 19879, [3] = 19878, [4] = 19880,
    [5] = 19882, [6] = 19884, [7] = 19883,
}
local Restore

local function RequestRestore()
    applyRequested = true
    restoreRequested = true
    restoreAttempts = 0
    treasureRequested = true
    treasureAttempts = 0
    lastAttempt = -10
end

local function Available()
    return C_Minimap and C_Minimap.GetNumTrackingTypes
        and C_Minimap.GetTrackingInfo and C_Minimap.SetTracking
end

local function IsTreasure(info)
    return info.spellID == 2481 or (C_Spell and C_Spell.GetSpellName
        and info.name == C_Spell.GetSpellName(2481))
end

local function Trackers(treasureOnly)
    local list = {}
    if not Available() then return list end
    for index = 1, C_Minimap.GetNumTrackingTypes() do
        local info, texture, active, category, subType, spellID = C_Minimap.GetTrackingInfo(index)
        if type(info) ~= "table" then
            info = { name = info, texture = texture, active = active,
                type = category, subType = subType, spellID = spellID }
        end
        -- Exclude service/vendor minimap filters; show tracking abilities only.
        if info.name and (info.type == "spell" or (info.spellID and info.spellID > 0))
            and (not not IsTreasure(info)) == (treasureOnly == true) then
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
    if AutoTrackersDB.selectionDisabled == true then return end
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

local function Environment()
    local _, instanceType = IsInInstance()
    if instanceType == "pvp" then return "battleground" end
    if instanceType == "party" or instanceType == "raid" then return "dungeon" end
    return "world"
end

local function Selection(environment)
    local choice = environment ~= "world" and AutoTrackersDB.environmentSelections[environment] or "inherit"
    if choice == "disabled" then return nil end
    if choice == "inherit" then
        if AutoTrackersDB.selectionDisabled then return nil end
        return AutoTrackersDB.selected
    end
    return choice
end

local function Matches(info, key)
    if info.key == key then return true end
    local id = key and tonumber(key:match("^spell:(%d+)$"))
    return id and C_Spell and C_Spell.GetSpellName and info.name == C_Spell.GetSpellName(id)
end

local function FindTracker(trackers, key)
    if not key then return end
    for _, info in ipairs(trackers) do
        if Matches(info, key) then return info end
    end
end

local function HunterTracker(environment, trackers, wanted)
    if not isHunter or environment ~= "world" then return end
    if not hunterOverride and not AutoTrackersDB.hunterTracking[environment] then
        hunterTargetGUID, hunterTargetReadyAt = nil, nil
        return
    end
    if InCombatLockdown() or UnitAffectingCombat("player") or UnitIsDeadOrGhost("player") then
        hunterTargetGUID, hunterTargetReadyAt, worldReturnAt = nil, nil, nil
        return
    end

    local guid, target
    if AutoTrackersDB.hunterTracking[environment] and UnitCanAttack("player", "target")
        and not UnitIsDeadOrGhost("target") then
        local _, creatureTypeID = UnitCreatureType("target")
        if issecretvalue and issecretvalue(creatureTypeID) then
            hunterTargetGUID, hunterTargetReadyAt, worldReturnAt = nil, nil, nil
            return nil, hunterOverride ~= nil
        end
        local spellID = hunterTrackingSpells[creatureTypeID]
        target = spellID and FindTracker(trackers, "spell:" .. spellID)
        guid = target and UnitGUID("target")
        if issecretvalue and issecretvalue(guid) then
            hunterTargetGUID, hunterTargetReadyAt, worldReturnAt = nil, nil, nil
            return nil, hunterOverride ~= nil
        end
    end
    local now = GetTime()
    if guid then
        worldReturnAt = nil
        if guid ~= hunterTargetGUID then
            hunterTargetGUID, hunterTargetReadyAt = guid, now + 0.7
            C_Timer.After(0.7, Restore)
        end
        if now >= hunterTargetReadyAt then return target, true end
        return nil, true
    end

    hunterTargetGUID, hunterTargetReadyAt = nil, nil
    if not hunterOverride then return end
    local sessionTracker = FindTracker(trackers, hunterSessionTrackers[environment])
    if sessionTracker then wanted = sessionTracker.key end
    if not wanted then
        hunterOverride, worldReturnAt = nil, nil
        return
    end
    if not worldReturnAt then
        worldReturnAt = now + 3
        C_Timer.After(3, Restore)
    end
    if now < worldReturnAt then return nil, true end
    local base = FindTracker(trackers, wanted)
    if base and base.active then
        hunterOverride, worldReturnAt = nil, nil
        return
    end
    return base, true, true
end

Restore = function()
    if not ready or not Available() or worldLoading then return end
    local environment = Environment()
    if currentEnvironment and currentEnvironment ~= environment then
        hunterTargetGUID, hunterTargetReadyAt, worldReturnAt, hunterOverride = nil, nil, nil, nil
        RequestRestore()
    end
    currentEnvironment = environment
    local trackers = Trackers()
    EnsureSelection(trackers)
    local wanted = Selection(environment)
    local active = ActiveTracker(trackers)
    local profileTracker = FindTracker(trackers, wanted)
    local sessionTracker = isHunter and environment == "world" and AutoTrackersDB.hunterTracking.world
        and FindTracker(trackers, hunterSessionTrackers[environment])
    if applyRequested and sessionTracker then wanted = sessionTracker.key end
    -- During profile application the active tracker may belong to the previous zone.
    local previous = active
    if applyRequested then previous = sessionTracker or profileTracker end
    local hunterTarget, hunterHandlesPrimary, returning = HunterTracker(environment, trackers, wanted)
    -- Travel/resurrection applies this environment's choice; ordinary ticks respect manual choices.
    if not wanted or (active and (not applyRequested or Matches(active, wanted))) then
        applyRequested = false
        restoreRequested = false
        restoreAttempts = 0
    end
    local treasure = Trackers(true)[1]
    if not AutoTrackersDB.treasureEnabled or (treasure and treasure.active) then
        treasureRequested = false
        treasureAttempts = 0
    end
    local primaryWanted = wanted ~= nil
        and (applyRequested or not active)
        and (AutoTrackersDB.mode == "always" or restoreRequested)
        and (AutoTrackersDB.mode == "always" or restoreAttempts < 5)
    local treasureWanted = AutoTrackersDB.treasureEnabled and treasure and not treasure.active
        and (AutoTrackersDB.mode == "always" or treasureRequested)
        and (AutoTrackersDB.mode == "always" or treasureAttempts < 5)
    primaryWanted = primaryWanted and not hunterHandlesPrimary
    if hunterTarget and hunterTarget.active then
        applyRequested, restoreRequested, restoreAttempts = false, false, 0
        hunterTarget = nil
    end
    if not hunterTarget and not primaryWanted and not treasureWanted then return end
    if UnitIsDeadOrGhost("player") or InCombatLockdown() then return end
    if hunterTarget and (UnitAffectingCombat("player") or UnitCastingInfo("player")
        or UnitChannelInfo("player")) then return end
    if C_Spell and C_Spell.GetSpellCooldown then
        local cooldown = C_Spell.GetSpellCooldown(61304)
        if cooldown and cooldown.duration and cooldown.duration > 0
            and cooldown.startTime + cooldown.duration > GetTime() then return end
    end
    if GetTime() - lastAttempt < 2 then return end
    local target = hunterTarget or (primaryWanted and FindTracker(trackers, wanted))
    if target and not hunterTarget then
        restoreAttempts = restoreAttempts + 1
    elseif not target and treasureWanted then
        target = treasure
        treasureAttempts = treasureAttempts + 1
    end
    if not target then return end
    lastAttempt = GetTime()
    local ok, err = pcall(C_Minimap.SetTracking, target.index, true)
    if ok and hunterTarget and not returning then
        if not hunterOverride then
            hunterSessionTrackers[environment] = previous and previous.key
        end
        hunterOverride = target.key
    end
    -- API acceptance is not proof of activation (for example during a GCD).
    -- The next event/tick verifies the actual state before completing each request.
    if not ok and tostring(err) ~= lastError then
        lastError = tostring(err)
        print("|cffffcc00Auto Trackers:|r " .. lastError)
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
        description:SetText("Choose tracking for each environment.\nYour settings are saved for this character.")

        local modeRows = {}
        local modeHint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        modeHint:SetPoint("TOPLEFT", 18, -146)
        modeHint:SetWidth(350)
        modeHint:SetJustifyH("LEFT")
        for i, mode in ipairs({
            { key = "recovery", label = "Apply on travel or resurrection" },
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
                    treasureRequested = false
                    if self.key == "always" then RequestRestore() end
                end
                for _, row in ipairs(modeRows) do
                    row:SetChecked(row.key == AutoTrackersDB.mode)
                end
                Schedule()
            end)
            modeRows[i] = button
        end

        local editingEnvironment = "world"
        local tabs = {}
        local update
        for i, tab in ipairs({
            { key = "world", label = "World" },
            { key = "battleground", label = "Battlegrounds" },
            { key = "dungeon", label = "Dungeons / raids" },
        }) do
            local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
            button:SetSize(114, 24)
            button:SetPoint("TOPLEFT", 18 + (i - 1) * 118, -222)
            button:SetText(tab.label)
            button.key = tab.key
            button:SetScript("OnClick", function()
                editingEnvironment = tab.key
                update()
            end)
            tabs[#tabs + 1] = button
        end
        local content = CreateFrame("Frame", nil, window)
        content:SetPoint("TOPLEFT", 16, -258)
        content:SetSize(350, 1)

        local status = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("TOPLEFT", content, "BOTTOMLEFT", 2, -12)
        status:SetWidth(350)
        status:SetJustifyH("LEFT")

        local credit = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        credit:SetPoint("TOP", status, "BOTTOM", 0, -20)
        credit:SetWidth(350)
        credit:SetJustifyH("CENTER")
        credit:SetText("Made by Shadowstride")

        local thanks = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        thanks:SetPoint("TOP", credit, "BOTTOM", 0, -8)
        thanks:SetWidth(350)
        thanks:SetJustifyH("CENTER")
        thanks:SetText("Thanks for using Auto Trackers! I hope you're enjoying it.\nIf you'd like to support my work,\nyou can do so on Donatello.")

        local donationURL = "https://donatello.to/shadowstride"
        local donationLink = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
        donationLink:SetSize(300, 22)
        donationLink:SetPoint("TOP", thanks, "BOTTOM", 0, -10)
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
        donationHint:SetPoint("TOP", donationLink, "BOTTOM", 0, -4)
        donationHint:SetText("Click the link, then press Ctrl+C to copy")

        local bugReportTitle = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bugReportTitle:SetPoint("TOP", donationHint, "BOTTOM", 0, -14)
        bugReportTitle:SetText("Found a bug? Leave a comment on CurseForge:")

        local bugReportURL = "https://www.curseforge.com/wow/addons/auto-trackers/comments"
        local bugReportLink = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
        bugReportLink:SetSize(350, 22)
        bugReportLink:SetPoint("TOP", bugReportTitle, "BOTTOM", 0, -8)
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
        bugReportHint:SetPoint("TOP", bugReportLink, "BOTTOM", 0, -4)
        bugReportHint:SetText("Click the link, then press Ctrl+C to copy")
        local rows = {}
        local treasureButton = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
        treasureButton:SetSize(28, 28)
        treasureButton:SetPoint("TOPLEFT", 16, -184)
        local treasureLabel = treasureButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        treasureLabel:SetPoint("LEFT", treasureButton, "RIGHT", 4, 0)
        treasureLabel:SetText("Restore Find Treasure independently")

        local hunterSection, hunterButton
        if isHunter then
            hunterSection = CreateFrame("Frame", nil, content)
            hunterSection:SetSize(350, 50)
            local divider = hunterSection:CreateTexture(nil, "ARTWORK")
            divider:SetPoint("TOPLEFT", 2, 0)
            divider:SetPoint("TOPRIGHT", -2, 0)
            divider:SetHeight(1)
            divider:SetColorTexture(1, 0.82, 0, 0.25)
            local heading = hunterSection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            heading:SetPoint("TOPLEFT", 2, -9)
            heading:SetText("Hunter Target Tracking")
            hunterButton = CreateFrame("CheckButton", nil, hunterSection, "UICheckButtonTemplate")
            hunterButton:SetSize(22, 22)
            hunterButton:SetPoint("TOPLEFT", 1, -25)
            local label = hunterButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetPoint("LEFT", hunterButton, "RIGHT", 4, 0)
            label:SetText("Automatically match your target before combat")
            hunterButton:SetScript("OnClick", function(self)
                AutoTrackersDB.hunterTracking.world = self:GetChecked() == true
                Schedule()
            end)
        end

        update = function()
            for _, tab in ipairs(tabs) do tab:SetEnabled(tab.key ~= editingEnvironment) end
            local hunterOptionShown = hunterButton and editingEnvironment == "world"
            if hunterButton then
                hunterSection:SetShown(hunterOptionShown)
                hunterButton:SetChecked(AutoTrackersDB.hunterTracking.world)
            end
            local treasure = Trackers(true)[1]
            treasureButton:SetShown(treasure ~= nil)
            treasureButton:SetChecked(AutoTrackersDB.treasureEnabled == true)
            if treasure then treasureLabel:SetText(treasure.name .. " (independent)") end
            local tabOffset = treasure and 224 or 184
            for i, tab in ipairs(tabs) do
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", 18 + (i - 1) * 118, -tabOffset)
            end
            content:ClearAllPoints()
            content:SetPoint("TOPLEFT", 16, -(tabOffset + 36))
            for _, row in ipairs(modeRows) do
                row:SetChecked(row.key == AutoTrackersDB.mode)
            end
            if AutoTrackersDB.mode == "always" then
                modeHint:SetText("Applies your choice on travel or resurrection.\nAlso restores it whenever no tracking is active.")
            else
                modeHint:SetText("Applies your choice on login, travel or resurrection.\nManual changes last until the next application.")
            end
            local trackers = Trackers()
            local activeTracker = ActiveTracker(trackers)
            EnsureSelection(trackers)
            local options = {}
            local chosen = editingEnvironment == "world"
                and (AutoTrackersDB.selectionDisabled and "disabled" or AutoTrackersDB.selected)
                or AutoTrackersDB.environmentSelections[editingEnvironment]
            if editingEnvironment ~= "world" then
                options[#options + 1] = { key = "inherit", name = "Same as World" }
            end
            local disabledLabel = hunterOptionShown and AutoTrackersDB.hunterTracking.world
                and "No default tracker" or "No automatic tracking"
            options[#options + 1] = { key = "disabled", name = disabledLabel }
            for _, info in ipairs(trackers) do options[#options + 1] = info end
            for _, row in ipairs(rows) do row:Hide() end
            local selected
            local columns = #options > 6 and 2 or 1
            local columnRows = math.ceil(#options / columns)
            for i, info in ipairs(options) do
                local row = rows[i]
                if not row then
                    row = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
                    row:SetSize(28, 28)
                    row:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
                    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    row.label:SetPoint("LEFT", row, "RIGHT", 4, 0)
                    row.label:SetWidth(290)
                    row.label:SetJustifyH("LEFT")
                    row:SetScript("OnClick", function(self)
                        if editingEnvironment == "world" then
                            AutoTrackersDB.selectionDisabled = self.key == "disabled" or nil
                            AutoTrackersDB.selected = self.key ~= "disabled" and self.key or nil
                            AutoTrackersDB.selectedName = self.key ~= "disabled" and self.trackerName or nil
                            AutoTrackersDB.automaticSelection = false
                        else
                            AutoTrackersDB.environmentSelections[editingEnvironment] = self.key
                        end
                        hunterSessionTrackers[editingEnvironment] = nil
                        lastError = nil
                        RequestRestore()
                        Restore()
                        update()
                        Schedule()
                    end)
                    rows[i] = row
                end
                row:ClearAllPoints()
                local column = math.floor((i - 1) / columnRows)
                row:SetPoint("TOPLEFT", column * 178, -((i - 1) % columnRows) * 26)
                row.label:SetWidth(columns == 2 and 140 or 290)
                row.key, row.trackerName = info.key, info.key and info.name or nil
                row.label:SetText(info.name)
                row:SetChecked(chosen == info.key)
                row:Show()
                if info.key and Matches(info, Selection(Environment())) then selected = info end
            end
            local trackerListHeight = columnRows * 26
            if hunterOptionShown then
                hunterSection:ClearAllPoints()
                hunterSection:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(trackerListHeight + 6))
            end
            content:SetHeight(math.max(1, trackerListHeight + (hunterOptionShown and 56 or 0)))
            if not Available() then
                status:SetText("Tracking API is unavailable in this client.")
            elseif not Selection(Environment()) then
                status:SetText("Automatic tracking disabled for this environment.")
            elseif activeTracker then
                status:SetText("Active: " .. activeTracker.name)
            elseif not Selection(Environment()) then
                status:SetText("No tracking abilities available on this character.")
            elseif not selected then
                status:SetText("Saved ability is currently unavailable: " .. (Selection(Environment()) or "unknown"))
            elseif UnitIsDeadOrGhost("player") then
                status:SetText("Waiting for resurrection: " .. selected.name)
            elseif AutoTrackersDB.mode ~= "always" and not restoreRequested then
                status:SetText("Inactive: " .. selected.name .. ". Manual changes are respected.")
            elseif InCombatLockdown() then
                status:SetText("Waiting until combat ends: " .. selected.name)
            else
                status:SetText("Waiting to restore: " .. selected.name)
            end
            if treasure then
                status:SetText(status:GetText() .. "\n" .. treasure.name .. ": "
                    .. (treasure.active and "active" or (AutoTrackersDB.treasureEnabled
                        and "enabled for restoration" or "automatic restoration off")))
            end
        end
        treasureButton:SetScript("OnClick", function(self)
            AutoTrackersDB.treasureEnabled = self:GetChecked() and true or false
            treasureRequested = AutoTrackersDB.treasureEnabled
            treasureAttempts = 0
            Restore()
            update()
            Schedule()
        end)
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
        window:SetSize(390, isHunter and 718 or 660)
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
        if AutoTrackersDB.treasureEnabled == nil then AutoTrackersDB.treasureEnabled = true end
        if AutoTrackersDB.selected == "spell:2481" or (AutoTrackersDB.selectedName
            and IsTreasure({ name = AutoTrackersDB.selectedName })) then
            AutoTrackersDB.selected = nil
            AutoTrackersDB.selectedName = nil
            AutoTrackersDB.automaticSelection = true
        end
        if AutoTrackersDB.mode ~= "always" and AutoTrackersDB.mode ~= "recovery" then
            AutoTrackersDB.mode = "recovery"
        end
        if type(AutoTrackersDB.environmentSelections) ~= "table" then
            AutoTrackersDB.environmentSelections = {}
        end
        local _, class = UnitClass("player")
        isHunter = class == "HUNTER"
        if type(AutoTrackersDB.hunterTracking) ~= "table" then AutoTrackersDB.hunterTracking = {} end
        AutoTrackersDB.hunterTracking.world = AutoTrackersDB.hunterTracking.world == true
        AutoTrackersDB.hunterTracking.dungeon = nil
        if isHunter then
            events:RegisterEvent("PLAYER_TARGET_CHANGED")
            events:RegisterEvent("PLAYER_REGEN_DISABLED")
            events:RegisterUnitEvent("UNIT_HEALTH", "target")
            events:RegisterUnitEvent("UNIT_FLAGS", "target")
        end
        local choices = AutoTrackersDB.environmentSelections
        if type(choices.battleground) ~= "string" then
            choices.battleground = isHunter and "spell:19883" or "inherit"
        end
        if type(choices.dungeon) ~= "string" then choices.dungeon = "inherit" end
        -- Old battleground overrides are replaced by explicit environment choices.
        AutoTrackersDB.battlegroundReturn = nil
        AutoTrackersDB.battlegroundHumanoids = nil
        ready = true
        -- Polling only restores in always mode or while a one-time request is pending.
        C_Timer.NewTicker(3, function()
            Restore()
            if window and window:IsShown() then refresh() end
            if settingsPanel and settingsPanel:IsShown() then settingsRefresh() end
        end)
    end
    if ready then
        if event == "UNIT_HEALTH" or event == "UNIT_FLAGS" or event == "PLAYER_TARGET_CHANGED" then
            if Environment() ~= "world" then return end
            if not hunterOverride and not AutoTrackersDB.hunterTracking.world then return end
            if InCombatLockdown() then return end
            if event == "UNIT_HEALTH" and not UnitIsDeadOrGhost("target") then return end
            if event == "PLAYER_TARGET_CHANGED" then hunterTargetGUID, hunterTargetReadyAt = nil, nil end
        end
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_DEAD" then
            hunterTargetGUID, hunterTargetReadyAt, worldReturnAt = nil, nil, nil
        end
        if event == "PLAYER_LEAVING_WORLD" then
            worldLoading = true
        elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
            worldLoading = false
        end
        if event == "PLAYER_LOGIN" then
            wasDead = UnitIsDeadOrGhost("player") and true or false
            RequestRestore()
        elseif event == "PLAYER_DEAD" then
            wasDead = true
            restoreRequested = false
            treasureRequested = false
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
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD",
    "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED",
    "MINIMAP_UPDATE_TRACKING" }) do
    events:RegisterEvent(event)
end
