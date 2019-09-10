local playerUnghostFrame = CreateFrame('Frame')

playerUnghostFrame:RegisterEvent("PLAYER_UNGHOST")
playerUnghostFrame:RegisterEvent("PLAYER_ALIVE")

playerUnghostFrame:HookScript("OnEvent", function ()
	local findMineralsSpellName = 'Find Minerals';
	local findHerbsSpellName = 'Find Herbs';

	local miningUsable = IsUsableSpell(findMineralsSpellName);
	local herbalismUsable = IsUsableSpell(findHerbsSpellName);

	if (miningUsable) then
		CastSpellByName(findMineralsSpellName);
	elseif (herbalismUsable) then
		CastSpellByName(findHerbsSpellName);
	end
end)