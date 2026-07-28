--------------------------------------------------------------------
------------- SUBSTITUIR FUNCTIONS - REPLACE FUNCTIONS -------------
--------------------------------------------------------------------

function refresh()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    resetNotificationTracking()

    if expSpeedEvent then
        expSpeedEvent:cancel()
        expSpeedEvent = nil
    end
    expSpeedEvent = cycleEvent(checkExpSpeed, 30 * 1000)

    onExperienceChange(player, player:getExperience())
    onLevelChange(player, player:getLevel(), player:getLevelPercent())
    onHealthChange(player, player:getHealth(), player:getMaxHealth())
    onManaChange(player, player:getMana(), player:getMaxMana())
    onSoulChange(player, player:getSoul())
    onFreeCapacityChange(player, player:getFreeCapacity())
    onStaminaChange(player, player:getStamina())
    onMagicLevelChange(player, player:getMagicLevel(), player:getMagicLevelPercent())
    onOfflineTrainingChange(player, player:getOfflineTrainingTime())
    onRegenerationChange(player, player:getRegenerationTime())
    onSpeedChange(player, player:getSpeed())

    for i = Skill.Fist, Skill.Transcendence do
        onSkillChange(player, i, player:getSkillLevel(i), player:getSkillLevelPercent(i))
    end
    update()
    updateHeight()
    if g_game.getClientVersion() >= 1410 then
        onFlatDamageHealingChange(player, statsCache.flatDamageHealing)
        onAttackInfoChange(player, statsCache.attackValue, statsCache.attackElement)
        onConvertedDamageChange(player, statsCache.convertedDamage, statsCache.convertedElement)
        onImbuementsChange(player, statsCache.lifeLeech, statsCache.manaLeech, statsCache.critChance, statsCache.critDamage, statsCache.onslaught)
        onDefenseInfoChange(player, statsCache.defense, statsCache.armor, statsCache.mitigation, statsCache.dodge, statsCache.damageReflection)
        onCombatAbsorbValuesChange(player, statsCache.combatAbsorbValues)
        onForgeBonusesChange(player, statsCache.momentum, statsCache.transcendence, statsCache.amplification)
    end

    scheduleEvent(enableNotifications, 5000)
end

function onLevelChange(localPlayer, value, percent)
    setSkillValue('level', comma_value(value))
    local text = tr('You have %s percent to go', 100 - percent)

    setSkillPercent('level', percent, text)

    -- Notificacao de Level Up
    if notificationsReady and previousLevel and value > previousLevel then
        modules.game_notification.show({
            title   = "Level Up!",
            message = "Voce alcancou o nivel " .. value .. "!",
            color   = "#FFD700",
            duration = 4000,
        })
    end
    previousLevel = value
end

function onMagicLevelChange(localPlayer, magiclevel, percent)
    setSkillValue('magiclevel', magiclevel)
    setSkillPercent('magiclevel', percent, tr('You have %s percent to go', 100 - percent))

    onBaseMagicLevelChange(localPlayer, localPlayer:getBaseMagicLevel())

    -- Notificacao de Magic Level Up
    if notificationsReady and previousMagicLevel and magiclevel > previousMagicLevel then
        modules.game_notification.show({
            title   = "Magic Level Up!",
            message = "Magic Level: " .. magiclevel,
            color   = "#00BFFF",
            duration = 3500,
        })
    end
    previousMagicLevel = magiclevel
end

function onSkillChange(localPlayer, id, level, percent)
    setSkillValue('skillId' .. id, level)
    setSkillPercent('skillId' .. id, percent, tr('You have %s percent to go', 100 - percent))

    onBaseSkillChange(localPlayer, id, localPlayer:getSkillBaseLevel(id))

    if id > Skill.ManaLeechAmount then
	    toggleSkill('skillId' .. id, level > 0)
    end

    -- Skill tracking: salva base level para comparacao em onBaseSkillChange
    if id <= 6 then
        local baseLevel = localPlayer:getSkillBaseLevel(id)
        if not previousSkills[id] then
            previousSkills[id] = baseLevel
        end
    end
end

function onBaseSkillChange(localPlayer, id, baseLevel)
    setSkillBase('skillId' .. id, localPlayer:getSkillLevel(id), baseLevel)

    -- Notificacao de Skill Up (apenas skills 0-6)
    -- Usa onBaseSkillChange que so dispara em mudanca real de base level
    -- (ignora bonus de equipamento e spells temporarias)
    if id <= 6 then
        local prev = previousSkills[id]
        if notificationsReady and prev and baseLevel > prev then
            local skillName = SKILL_NAMES[id] or ("Skill " .. id)
            modules.game_notification.show({
                title   = "Skill Up!",
                message = skillName .. ": " .. baseLevel,
                color   = "#7CFC00",
                duration = 3500,
            })
        end
        previousSkills[id] = baseLevel
    end
end

-------------------------------------------------------------------------------------------
----- ADICIONAR OS CODIGOS ABAIXO DE function onExperienceChange(localPlayer, value) ------
----- Add the following code to function onExperienceChange(localPlayer, value) -----------
-------------------------------------------------------------------------------------------

-- ======== Notification tracking ========
local previousLevel = nil
local previousSkills = {}
local previousMagicLevel = nil
local lastHungryNotif = 0
local lastCapacityNotif = 0
local notificationsReady = false

local SKILL_NAMES = {
    [0] = "Fist",
    [1] = "Club",
    [2] = "Sword Fighting",
    [3] = "Axe Fighting",
    [4] = "Distance Fighting",
    [5] = "Shielding",
    [6] = "Fishing",
}

function enableNotifications()
    notificationsReady = true
end

function resetNotificationTracking()
    notificationsReady = false
    previousLevel = nil
    previousSkills = {}
    previousMagicLevel = nil
end

