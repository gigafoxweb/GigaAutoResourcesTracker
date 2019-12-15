local addonName, addonData = ...

addonData.core = {}

addonData.core.trackersList = {
    {
        name = 'findMinerals',
        id = 2580,
        priority = 1000
    },
    {
        name = 'findHerbs',
        id = 2383,
        priority = 500
    }
}

addonData.core.getDefaultCharacterCoreSettings = function()
    return {
        trackersList = addonData.core.trackersList
    };
end

addonData.core.getCharacterTrackersList = function()
    return characterCoreSettings.trackersList;
end

addonData.core.LoadCharacterSettings = function()
    if not characterCoreSettings then
        characterCoreSettings = {}
    end

    local defaultSettings = addonData.core.getDefaultCharacterCoreSettings();

    for setting, value in pairs(defaultSettings) do
        if characterCoreSettings[setting] == nil then
            characterCoreSettings[setting] = value
        end
    end
end

addonData.core.trackerExists = function(trackerName)
    for _, tracker in ipairs(addonData.core.trackersList) do
        if (tracker.name == trackerName) then
            return true
        end
    end

    return false
end

addonData.core.setTrackersPriority = function(trackerName, priority)
    for index, tracker in ipairs(characterCoreSettings.trackersList) do
        if (tracker.name == trackerName) then
            characterCoreSettings.trackersList[index].priority = priority

            break
        end
    end

    table.sort(characterCoreSettings.trackersList, function(a, b) return a.priority > b.priority end)
end

addonData.core.resetTrackersListSettings = function()
    characterCoreSettings.trackersList = addonData.core.trackersList
end

addonData.core.coreFrame = CreateFrame("Frame", addonName .. "CoreFrame", UIParent)
addonData.core.coreFrame:RegisterEvent("ADDON_LOADED")

local CoreFrameOnEvent = function (self, event, ...)
    local args = {... }

    if args[1] ~= "GigaAutoResourcesTracker" then
        return
    end

    if (event == 'ADDON_LOADED') then
        addonData.core.LoadCharacterSettings()
    end
end

addonData.core.coreFrame:HookScript("OnEvent", CoreFrameOnEvent)
