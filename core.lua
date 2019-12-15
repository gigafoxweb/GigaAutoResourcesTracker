local addonName, addonData = ...

addonData.core = {}
addonData.core.version = '1.1.0'

addonData.core.getDefaultCharacterSettings = function()
    return {
        trackersList = addonData.core.getDefaultCharacterTrackerList()
    }
end

addonData.core.getDefaultCharacterTrackerList = function()
    local trackersList = {}
    for index, tracker in ipairs(addonData.config.trackersList) do
        trackersList[index] = {
            name = tracker.name,
            id = tracker.id,
            priority = tracker.priority,
        }
    end

    return trackersList
end

addonData.core.getCharacterTrackersList = function()
    return GARTCharacterSettings.trackersList
end

addonData.core.loadVersion = function()
    if not GARTCoreVersion then
        GARTCoreVersion = addonData.core.version
    end
end

addonData.core.loadCharacterSettings = function()
    if not GARTCharacterSettings then
        GARTCharacterSettings = {}
    end

    local defaultSettings = addonData.core.getDefaultCharacterSettings()

    for setting, value in pairs(defaultSettings) do
        if GARTCharacterSettings[setting] == nil then
            GARTCharacterSettings[setting] = value
        end
    end
end

addonData.core.trackerExists = function(trackerName)
    for _, tracker in ipairs(addonData.config.trackersList) do
        if (tracker.name == trackerName) then
            return true
        end
    end

    return false
end

addonData.core.setTrackersPriority = function(trackerName, priority)
    for _, tracker in ipairs(GARTCharacterSettings.trackersList) do
        if (tracker.name == trackerName) then
            tracker.priority = priority

            break
        end
    end

    table.sort(GARTCharacterSettings.trackersList, function(a, b) return a.priority > b.priority end)
end

addonData.core.resetTrackersListSettings = function()
    GARTCharacterSettings.trackersList = addonData.core.getDefaultCharacterTrackerList()
end

addonData.core.coreFrame = CreateFrame("Frame", addonName .. "CoreFrame", UIParent)
addonData.core.coreFrame:RegisterEvent("ADDON_LOADED")

local CoreFrameOnEvent = function (self, event, ...)
    local args = {... }

    if args[1] ~= "GigaAutoResourcesTracker" then
        return
    end

    if (event ~= 'ADDON_LOADED') then
        return
    end

    addonData.core.loadVersion()
    addonData.core.loadCharacterSettings()

    addonData.utils.printWithName('Thank you for using this addon! Hope it makes your Azeroth life a little easier :)')
    addonData.utils.printWithName('Version: ' .. addonData.core.version .. '. Use "/gart" command for help.')
    addonData.utils.printWithName('If you found issues or want live feedback: https://www.curseforge.com/wow/addons/gigaautoresourcestracker.')

    if (addonData.core.version ~= GARTCoreVersion) then
        addonData.utils.printWithName('Addon has been updated from version: ' .. GARTCoreVersion .. ' to version: ' .. addonData.core.version .. '.')
        addonData.utils.printWithName('Settings were restored to default.')

        addonData.core.resetTrackersListSettings()
        GARTCoreVersion = addonData.core.version
    end
end

addonData.core.coreFrame:HookScript("OnEvent", CoreFrameOnEvent)
