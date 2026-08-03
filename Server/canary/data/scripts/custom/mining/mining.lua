local MiningConfig = {
    -- Storages to save the player's mining skill
    storageSkill = 65000,
    storageTries = 65001,

    -- Tools that can be used for mining (e.g. Pick)
    pickaxes = {3456},

    -- Rocks configuration
    -- Format: [rock_item_id] = depleted_item_id
    rocks = {
        [5632] = 5633, 
        [1285] = 1354, 
        [7062] = 7063, 
        [7739] = 7740,
        [21581] = 21582,
        [16135] = 16137
    },

    -- Time for the depleted rock to turn back into a normal rock (in seconds)
    respawnTime = 60,

    -- Ores that can be obtained
    -- id: item ID of the ore
    -- weight: relative chance to get this ore (higher = more common)
    -- minSkill: minimum mining skill required to find this ore
    -- exp: experience added to the mining skill when this ore is found
    ores = {
        {id = 5880, weight = 100, minSkill = 1, exp = 10, name = "iron ore"},
        {id = 3040, weight = 40, minSkill = 10, exp = 25, name = "gold nugget"},
        {id = 3027, weight = 10, minSkill = 25, exp = 50, name = "black pearl"},
        {id = 3028, weight = 5, minSkill = 40, exp = 100, name = "small diamond"}
    },

    -- Skill configuration
    -- To advance a level, the player needs: baseTries * (multiplier ^ currentSkill) tries/exp
    baseTries = 50,
    multiplier = 1.2,
    
    -- Success chance to extract an ore (in %)
    -- Final chance = baseSuccessChance + (currentSkill * skillBonusMultiplier)
    baseSuccessChance = 30,
    skillBonusMultiplier = 0.5, -- e.g. at skill 40, chance is 30 + 20 = 50%
    maxSuccessChance = 90
}

local miningAction = Action()

for _, pickId in ipairs(MiningConfig.pickaxes) do
    miningAction:id(pickId)
end
miningAction:allowFarUse(true)

function miningAction.onUse(player, item, fromPosition, target, toPosition, isHotkey)
    if not target or not target:isItem() then
        return false
    end

    local targetId = target:getId()
    local depletedId = MiningConfig.rocks[targetId]
    
    -- If it's not a configured mineable rock, let the default C++ pickaxe script handle it (secret holes)
    if not depletedId then
        return onUsePick(player, item, fromPosition, target, toPosition, isHotkey)
    end
    
    -- Get player skill
    local skill = math.max(1, player:getStorageValue(MiningConfig.storageSkill))
    
    -- Calculate success chance
    local chance = math.min(MiningConfig.maxSuccessChance, MiningConfig.baseSuccessChance + (skill * MiningConfig.skillBonusMultiplier))
    
    local success = math.random(1, 100) <= chance
    
    if success then
        -- Pick a random ore based on weight and skill
        local availableOres = {}
        local totalWeight = 0
        
        for _, ore in ipairs(MiningConfig.ores) do
            if skill >= ore.minSkill then
                table.insert(availableOres, ore)
                totalWeight = totalWeight + ore.weight
            end
        end
        
        if totalWeight > 0 then
            local roll = math.random(1, totalWeight)
            local currentWeight = 0
            local selectedOre = nil
            
            for _, ore in ipairs(availableOres) do
                currentWeight = currentWeight + ore.weight
                if roll <= currentWeight then
                    selectedOre = ore
                    break
                end
            end
            
            if selectedOre then
                -- Give item
                player:addItem(selectedOre.id, 1)
                player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You mined a " .. selectedOre.name .. ".")
                toPosition:sendMagicEffect(CONST_ME_BLOCKHIT)
                
                -- Add skill exp
                local tries = math.max(0, player:getStorageValue(MiningConfig.storageTries))
                tries = tries + selectedOre.exp
                
                local reqTries = MiningConfig.baseTries * (MiningConfig.multiplier ^ skill)
                
                if tries >= reqTries then
                    player:setStorageValue(MiningConfig.storageSkill, skill + 1)
                    player:setStorageValue(MiningConfig.storageTries, 0)
                    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You advanced to mining level " .. (skill + 1) .. ".")
                    player:getPosition():sendMagicEffect(CONST_ME_MAGIC_GREEN)
                else
                    player:setStorageValue(MiningConfig.storageTries, tries)
                end
            end
        else
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You failed to mine anything.")
            toPosition:sendMagicEffect(CONST_ME_POFF)
        end
    else
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You failed to mine anything.")
        toPosition:sendMagicEffect(CONST_ME_POFF)
    end
    
    -- Transform rock to depleted state regardless of success to prevent infinite spam
    target:transform(depletedId)
    
    -- Schedule respawn
    local targetPos = toPosition
    addEvent(function()
        local tile = Tile(targetPos)
        if tile then
            local depletedRock = tile:getItemById(depletedId)
            if depletedRock then
                depletedRock:transform(targetId)
            end
        end
    end, MiningConfig.respawnTime * 1000)
    
    return true
end

miningAction:register()
