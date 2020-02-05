local addonName, addonData = ...

addonData.main = {}

addonData.main.playerUnghostFrame = CreateFrame('Frame')

addonData.main.playerUnghostFrame:RegisterEvent("PLAYER_UNGHOST")
addonData.main.playerUnghostFrame:RegisterEvent("PLAYER_ALIVE")
addonData.main.playerUnghostFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

addonData.main.playerUnghostFrame:HookScript("OnEvent", function (_, event, arg1, arg2)
	if event == "PLAYER_ENTERING_WORLD" then
		--[[
			arg1 is "isInitialLogin" and arg2 is "isReloadingUi"
			Check if the event triggers without any of them and if it does then stop the function.
			The event also triggers when changing zones but with false, so if both of them are false then that means you zoned and wont have to trigger the reapplication.
		]]
		if not arg1 and not arg2 then return end
	end
	for _, tracker in ipairs(addonData.core.getCharacterTrackersList()) do
		if (IsSpellKnown(tracker.id)) then
			CastSpellByID(tracker.id)

			break
		end
	end
end)
