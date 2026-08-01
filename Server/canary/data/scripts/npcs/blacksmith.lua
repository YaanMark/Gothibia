local internalNpcName = "Blacksmith"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000
npcConfig.walkRadius = 2

npcConfig.outfit = {
	lookType = 128,
	lookHead = 0, lookBody = 0, lookLegs = 0, lookFeet = 0, lookAddons = 0,
}

npcConfig.flags = {
	floorchange = false,
	profession = "normal",
}
npcConfig.speechBubble = SPEECHBUBBLE_NORMAL

local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)

npcType.onThink = function(npc, interval) npcHandler:onThink(npc, interval) end
npcType.onAppear = function(npc, creature) npcHandler:onAppear(npc, creature) end
npcType.onDisappear = function(npc, creature) npcHandler:onDisappear(npc, creature) end
npcType.onMove = function(npc, creature, fromPosition, toPosition) npcHandler:onMove(npc, creature, fromPosition, toPosition) end
npcType.onSay = function(npc, creature, type, message) npcHandler:onSay(npc, creature, type, message) end
npcType.onCloseChannel = function(npc, creature) npcHandler:onCloseChannel(npc, creature) end

local function creatureSayCallback(npc, creature, type, message)
	local player = Player(creature)
	local playerId = player:getId()

	if not npcHandler:checkInteraction(npc, creature) then
		return false
	end

	if MsgContains(message, "refine") then
		local item = player:getSlotItem(CONST_SLOT_LEFT)
		if not item then
			npcHandler:say("Coloque o item que deseja refinar na sua mao esquerda (slot de escudo/arma).", npc, creature)
			return true
		end

		local canRefine, msg = Refinement.canRefine(item)
		if not canRefine then
			npcHandler:say(msg, npc, creature)
			return true
		end

		local currentRefine = item:getRefine() or 0
		local nextRefine = currentRefine + 1
		local config = RefinementConfig.Levels[nextRefine]

		if not config then
			npcHandler:say("Nao ha configuracao de refino para este nivel.", npc, creature)
			return true
		end

		npcHandler:say(string.format("Para refinar este item para o nivel +%d, voce precisa de %d gold. Deseja prosseguir? (yes/no)", nextRefine, config.gold), npc, creature)
		npcHandler:setTopic(playerId, 1)
		return true

	elseif MsgContains(message, "yes") and npcHandler:getTopic(playerId) == 1 then
		npcHandler:setTopic(playerId, 0)
		local item = player:getSlotItem(CONST_SLOT_LEFT)
		if not item then
			npcHandler:say("Onde esta o item?", npc, creature)
			return true
		end

		if Refinement.refineItem(player, item) then
			npcHandler:say("Pronto! Seu item foi refinado.", npc, creature)
		else
			npcHandler:say("Infelizmente o refino falhou ou voce nao tem os requisitos.", npc, creature)
		end
		return true

	elseif MsgContains(message, "no") and npcHandler:getTopic(playerId) == 1 then
		npcHandler:setTopic(playerId, 0)
		npcHandler:say("Tudo bem, volte quando estiver pronto.", npc, creature)
		return true
	end

	return true
end

npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)
npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)
npcType:register(npcConfig)
