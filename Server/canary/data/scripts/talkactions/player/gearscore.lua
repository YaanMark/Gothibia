local gearScore = TalkAction("!gearscore")

function gearScore.onSay(player, words, param)
	player:recalculateGearScore()
	local gs = player:getGearScore()
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Your Gear Score is: " .. gs)
	return false
end

gearScore:separator(" ")
gearScore:groupType("normal")
gearScore:register()
