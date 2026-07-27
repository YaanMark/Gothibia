local talk = TalkAction("!spawnnpc")

function talk.onSay(player, words, param)
    local position = player:getPosition()
    local npc = Game.createNpc("Old Merchant", position)

    if npc then
        player:sendTextMessage(MESSAGE_INFO_DESCR, "NPC spawnado!")
    else
        player:sendTextMessage(MESSAGE_INFO_DESCR, "Falha ao spawnar — confere se o nome bate certinho com o registrado no npcType.")
    end

    return false
end

talk:groupType("gamemaster")
talk:register()