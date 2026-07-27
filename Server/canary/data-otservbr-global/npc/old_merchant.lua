local internalNpcName = "Old Merchant"
local npcType = Game.createNpcType(internalNpcName)
local npcConfig = {}

npcConfig.name = internalNpcName
npcConfig.description = internalNpcName

npcConfig.health = 100
npcConfig.maxHealth = npcConfig.health
npcConfig.walkInterval = 2000  -- de quanto em quanto tempo (ms) ele anda sozinho; 0 = parado
npcConfig.walkRadius = 2       -- raio (em tiles) que ele pode andar a partir do ponto de spawn

npcConfig.outfit = {
    lookType = 128,
    lookHead = 58,
    lookBody = 43,
    lookLegs = 38,
    lookFeet = 76,
    lookAddons = 0,
}

npcConfig.flags = {
    floorchange = false,
    profession = "trader", -- muda o balão de fala pra ícone de comércio
}
npcConfig.speechBubble = SPEECHBUBBLE_TRADE

local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)

npcType.onThink = function(npc, interval) npcHandler:onThink(npc, interval) end
npcType.onAppear = function(npc, creature) npcHandler:onAppear(npc, creature) end
npcType.onDisappear = function(npc, creature) npcHandler:onDisappear(npc, creature) end
npcType.onMove = function(npc, creature, fromPosition, toPosition) npcHandler:onMove(npc, creature, fromPosition, toPosition) end
npcType.onSay = function(npc, creature, type, message) npcHandler:onSay(npc, creature, type, message) end
npcType.onCloseChannel = function(npc, creature) npcHandler:onCloseChannel(npc, creature) end

npcConfig.shop = {
    { itemName = "backpack", clientId = 2854, buy = 10 },
    { itemName = "torch", clientId = 2920, buy = 5, sell = 1 },
    { itemName = "rope", clientId = 3003, buy = 50, sell = 8 },
}

npcType.onBuyItem = function(npc, player, itemId, subType, amount, ignore, inBackpacks, totalCost)
    npc:sellItem(player, itemId, amount, subType, 0, ignore, inBackpacks)
end
npcType.onSellItem = function(npc, player, itemId, subtype, amount, ignore, name, totalCost)
    player:sendTextMessage(MESSAGE_TRADE, string.format("Vendeu %ix %s por %i gold.", amount, name, totalCost))
end
npcType.onCheckItem = function(npc, player, clientId, subType) end

npcHandler:addModule(FocusModule:new(), npcConfig.name, true, true, true)
npcType:register(npcConfig)