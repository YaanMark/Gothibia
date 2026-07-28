local setVocation = TalkAction("/vocation", "/voc")

function setVocation.onSay(player, words, param)
	if param == "" then
		player:sendCancelMessage("Uso correto: /vocation Hemomante OU /vocation 11")
		return true
	end

	local vocNameOrId = param:trimSpace()
	local vocId = tonumber(vocNameOrId)

	if not vocId then
		local voc = Vocation(vocNameOrId)
		if voc then
			vocId = voc:getId()
		end
	end

	if not vocId then
		player:sendCancelMessage("Vocacao '" .. vocNameOrId .. "' nao foi encontrada.")
		return true
	end

	player:setVocation(vocId)
	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_RED)
	player:sendTextMessage(MESSAGE_INFO_DESCR, "Sua vocacao foi alterada com sucesso para: " .. player:getVocation():getName() .. " (ID: " .. vocId .. ")!")
	return true
end

setVocation:groupType("god")
setVocation:register()
