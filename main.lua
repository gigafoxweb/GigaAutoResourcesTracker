local playerUnghostFrame = CreateFrame('Frame')

playerUnghostFrame:RegisterEvent("PLAYER_UNGHOST")
playerUnghostFrame:RegisterEvent("PLAYER_ALIVE")

playerUnghostFrame:SetScript("OnEvent", function (self, event, addon, ...)
	if ((event =="PLAYER_UNGHOST") or (event == "PLAYER_ALIVE")) then
		local findMineralsSpellID = 2580
		local findHerbsSpellID = 2383

		local miningUsable = IsUsableSpell(findMineralsSpellID);
		local herbalismUsable = IsUsableSpell(findHerbsSpellID);

		if (miningUsable) then
			CastSpellByID(findMineralsSpellID)
		elseif (herbalismUsable) then
			CastSpellByID(findHerbsSpellID)
		end
	end
end)
