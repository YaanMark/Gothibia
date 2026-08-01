Refinement = {}

function Refinement.canRefine(item)
    local itemType = item:getType()
    local rarity = itemType:getRarity() or 0
    local currentRefine = item:getRefine() or 0
    local maxRefine = RefinementConfig.MaxRefine[rarity] or 5
    
    if currentRefine >= maxRefine then
        return false, "O item ja atingiu o nivel maximo de refino para a sua raridade."
    end
    return true
end

function Refinement.refineItem(player, item)
    local canRefine, msg = Refinement.canRefine(item)
    if not canRefine then
        player:sendTextMessage(MESSAGE_INFO_DESCR, msg)
        return false
    end

    local currentRefine = item:getRefine() or 0
    local nextRefine = currentRefine + 1
    local config = RefinementConfig.Levels[nextRefine]
    
    if not config then
        player:sendTextMessage(MESSAGE_INFO_DESCR, "Nao foi possivel encontrar configuracao para este nivel de refino.")
        return false
    end

    -- Check gold
    if player:getBankBalance() < config.gold and player:getMoney() < config.gold then
        player:sendTextMessage(MESSAGE_INFO_DESCR, "Voce nao tem ouro suficiente. Necessario: " .. config.gold)
        return false
    end

    -- Check materials
    for _, mat in pairs(config.materials) do
        if player:getItemCount(mat.id) < mat.count then
            player:sendTextMessage(MESSAGE_INFO_DESCR, "Voce nao tem materiais suficientes. Necessario item: " .. mat.id .. ", quantidade: " .. mat.count)
            return false
        end
    end

    -- Consume gold and materials
    if not player:removeMoneyBank(config.gold) then
        player:removeMoney(config.gold)
    end
    for _, mat in pairs(config.materials) do
        player:removeItem(mat.id, mat.count)
    end

    -- Chance
    local success = math.random(1, 100) <= config.chance
    if success then
        item:setRefine(nextRefine)
        
        -- Custom logic to update item name or stats here
        player:sendTextMessage(MESSAGE_INFO_DESCR, "Refinamento realizado com sucesso! Novo nivel: +" .. nextRefine)
        player:getPosition():sendMagicEffect(CONST_ME_FIREWORK_YELLOW)
    else
        -- Fail logic
        if nextRefine <= 3 then
            -- no penalty
            player:sendTextMessage(MESSAGE_INFO_DESCR, "O refinamento falhou, mas nao houve penalidade.")
        elseif nextRefine <= 6 then
            -- lose 1 level
            local newRefine = math.max(0, currentRefine - 1)
            item:setRefine(newRefine)
            player:sendTextMessage(MESSAGE_INFO_DESCR, "O refinamento falhou e seu item perdeu 1 nivel de refino.")
        else
            -- lose 2 levels
            local newRefine = math.max(0, currentRefine - 2)
            item:setRefine(newRefine)
            player:sendTextMessage(MESSAGE_INFO_DESCR, "O refinamento falhou e seu item perdeu 2 niveis de refino.")
        end
        player:getPosition():sendMagicEffect(CONST_ME_POFF)
    end
    
    -- Recalculate gear score
    player:recalculateGearScore()
    return true
end
