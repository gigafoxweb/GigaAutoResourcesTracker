local addonName, addonData = ...

addonData.utils = {}

addonData.utils.printWithName = function(msg)
	local chatMsg = "|cFF00FFB0" .. addonName .. ": |r" .. msg
	DEFAULT_CHAT_FRAME:AddMessage(chatMsg)
end

addonData.utils.print = function(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg)
end