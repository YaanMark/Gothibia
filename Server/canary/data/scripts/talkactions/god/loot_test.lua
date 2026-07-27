local simulateLoot = TalkAction("/loot")

function simulateLoot.onSay(player, words, param)
    -- Lê os parâmetros: nome do monstro e quantidade de simulações
    local splitParams = param:split(",")
    local monsterName = splitParams[1]
    
    if not monsterName then
        player:sendCancelMessage("Usage: /loot MonsterName, Count")
        return false
    end
    
    monsterName = monsterName:trimSpace()
    
    -- Quantidade padrão de simulações
    local count = 100
    if splitParams[2] then
        count = tonumber(splitParams[2]) or 100
    end
    
    -- Verifica se o monstro existe
    local mType = MonsterType(monsterName)
    if not mType then
        player:sendCancelMessage("Monster '" .. monsterName .. "' not found.")
        return false
    end
    
    -- Confere se o monstro possui loot configurado
    local lootList = mType:getLoot()
    if not lootList or #lootList == 0 then
        player:sendTextMessage(
            MESSAGE_STATUS_CONSOLE_BLUE,
            "Monster " .. mType:getName() .. " has no configured loot."
        )
        return true
    end
    
    local totalLoot = {}
    
    -- Configuração da simulação
    -- Usa o player que executou o comando apenas para manter compatibilidade
    -- gut = false para simular o loot base, sem influência de charms/luck
    local lootConfig = {
        factor = 1.0,
        gut = false
    }
    
    -- Executa a simulação X vezes
    for i = 1, count do
        -- Gera o loot usando a função nativa do servidor
        -- Assim o resultado respeita exatamente as regras reais do jogo
        local drops = mType:generateLootRoll(lootConfig, {}, player)
        
        for itemId, dropData in pairs(drops) do
            totalLoot[itemId] = (totalLoot[itemId] or 0) + dropData.count
        end
    end
    
    -- Monta o texto de saída
    local description = "Loot Simulation for " .. count .. "x " .. mType:getName() .. ":\n\n"
    
    -- Organiza os itens por quantidade (maior → menor)
    local sortedLoot = {}
    for itemId, amount in pairs(totalLoot) do
        table.insert(sortedLoot, {id = itemId, amount = amount})
    end
    
    table.sort(sortedLoot, function(a, b)
        return a.amount > b.amount
    end)
    
    for _, item in ipairs(sortedLoot) do
        local iType = ItemType(item.id)
        local iName = iType and iType:getName() or "ID: " .. item.id
        
        local chanceReal = (item.amount / count) * 100
        local avgAmount = item.amount / count
        
        -- Exemplo:
        -- "250x Gold Coin (95.0% chance) [Avg: 2.50]"
        description = description ..
            string.format(
                "%dx %s (%.1f%% chance) [Avg: %.2f]\n",
                item.amount,
                iName,
                chanceReal,
                avgAmount
            )
    end
    
    if #sortedLoot == 0 then
        description = description .. "No items dropped."
    end
    
    -- Mostra o resultado em uma janela de texto
    player:showTextDialog(3043, description) -- Ícone de Crystal Coin
    return true
end

simulateLoot:separator(" ")
simulateLoot:groupType("god")
simulateLoot:register()