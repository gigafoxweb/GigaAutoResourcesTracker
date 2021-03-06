local addonName, addonData = ...

local helpCmd = 'help'
local showTrackersListCmd = 'show-trackers-list'
local setTrackerPriorityCmd = 'set-tracker-priority'
local resetTrackersListSettingsCmd = 'reset-trackers-list-settings'

addonData.cmd = {}

addonData.cmd.help = function()
    -- ToDo write utility for lists output
    addonData.utils.printWithName('GigaAutoResourcesTracler is used to make important tracker spell always enabled.')
    addonData.utils.printWithName('You can use commands to configure trackers priority.')
    addonData.utils.printWithName('Usage example: "' .. setTrackerPriorityCmd .. ' findHerbs 1500".')
    addonData.utils.printWithName('commands list:')
    addonData.utils.print('  - ' .. showTrackersListCmd)
    addonData.utils.print('    Shows available trackers list.')
    addonData.utils.print('  - ' .. setTrackerPriorityCmd)
    addonData.utils.print('    Set tracker priority. Higher priority = higher in the list.')
    addonData.utils.print('    - args:')
    addonData.utils.print('      - trackerName (can be found using "' .. showTrackersListCmd .. '" command)')
    addonData.utils.print('      - priority (number)')
    addonData.utils.print('  - ' .. resetTrackersListSettingsCmd)
    addonData.utils.print('    Resets trackers list settings to default values.')
end

addonData.cmd.showTrackersList = function()
    addonData.utils.printWithName('Trackers list:')

    for index, tracker in ipairs(addonData.core.getCharacterTrackersList()) do
        addonData.utils.print(index .. '. name: ' .. tracker.name .. ', priority: ' .. tracker.priority)
    end
end

addonData.cmd.setTrackerPriority = function(args)
    local trackerName, priority = strsplit(' ', args, 2)

    if (trackerName == nil or addonData.core.trackerExists(trackerName) == false) then
        addonData.utils.printWithName('trackerName is not valid.')
        return
    end

    if (tonumber(priority) == nil) then
        addonData.utils.printWithName('priority is not valid.')
        return
    end

    addonData.core.setTrackersPriority(trackerName, tonumber(priority))
    addonData.utils.printWithName(trackerName .. ' priority was setted to ' .. priority .. '.')
    addonData.cmd.showTrackersList()
end

addonData.cmd.resetTrackersListSettings = function()
    addonData.core.resetTrackersListSettings()
    addonData.utils.printWithName('Trackers list settings were resseted to default values.')
    addonData.cmd.showTrackersList()
end

SLASH_GIGAAUTORESOURCESTRACKER_CONFIG1 = "/GigaAutoResourcesTracker"
SLASH_GIGAAUTORESOURCESTRACKER_CONFIG2 = "/gigaautoresourcestracker"
SLASH_GIGAAUTORESOURCESTRACKER_CONFIG3 = "/gart"
SlashCmdList["GIGAAUTORESOURCESTRACKER_CONFIG"] = function(msg)
    local cmd, args = strsplit(' ', msg, 2)

    if (cmd == helpCmd or cmd == '') then
        addonData.cmd.help()
    elseif (cmd == showTrackersListCmd) then
        addonData.cmd.showTrackersList()
    elseif (cmd == setTrackerPriorityCmd) then
        addonData.cmd.setTrackerPriority(args)
    elseif (cmd == resetTrackersListSettingsCmd) then
        addonData.cmd.resetTrackersListSettings()
    else
        addonData.utils.printWithName('Undefined command: ' .. cmd .. '.')
    end
end
