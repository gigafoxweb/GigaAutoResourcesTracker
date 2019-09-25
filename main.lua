
local playerUnghostFrame = CreateFrame('Frame')

playerUnghostFrame:RegisterEvent("PLAYER_UNGHOST")
playerUnghostFrame:RegisterEvent("PLAYER_ALIVE")

playerUnghostFrame:HookScript("OnEvent", function ()
	local findMineralsSpellID = 2580
	local findHerbsSpellID = 2383

	local miningUsable = IsSpellKnown(findMineralsSpellID);
	local herbalismUsable = IsSpellKnown(findHerbsSpellID);

	if (miningUsable) then
		CastSpellByID(findMineralsSpellID)
	elseif (herbalismUsable) then
		CastSpellByID(findHerbsSpellID)
	end
end)