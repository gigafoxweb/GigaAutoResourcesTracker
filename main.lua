local addonName, addonData = ...

addonData.main = {}

addonData.main.playerUnghostFrame = CreateFrame('Frame')

addonData.main.playerUnghostFrame:RegisterEvent("PLAYER_UNGHOST")
addonData.main.playerUnghostFrame:RegisterEvent("PLAYER_ALIVE")

addonData.main.playerUnghostFrame:HookScript("OnEvent", function ()
	for _, tracker in ipairs(addonData.core.getCharacterTrackersList()) do
		if (IsSpellKnown(tracker.id)) then
			CastSpellByID(tracker.id)

			break
		end
	end
end)