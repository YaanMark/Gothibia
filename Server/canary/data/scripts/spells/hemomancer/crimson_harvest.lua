local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	local player = creature:getPlayer()
	if not player then
		return false
	end

	local playerPos = player:getPosition()
	local level = player:getLevel()
	local maglevel = player:getMagicLevel()

	local minDmg = math.floor((level / 5) + (maglevel * 5.5) + 80)
	local maxDmg = math.floor((level / 5) + (maglevel * 8.5) + 160)

	-- Efeito supremo do Caster (effect 65, 273 e 295)
	playerPos:sendMagicEffect(65)
	playerPos:sendMagicEffect(273)
	playerPos:sendMagicEffect(295)

	local totalDamageDealt = 0

	-- Seleciona todos os alvos em uma área 5x5 em volta do Hemomante
	local areaSpecs = Game.getSpectators(playerPos, false, false, 3, 3, 3, 3)
	for _, spec in ipairs(areaSpecs) do
		if spec and spec:isMonster() and not spec:getMaster() then
			local dmg = math.random(minDmg, maxDmg)
			spec:getPosition():sendMagicEffect(249) -- effect 249: BLOOD_SPLASH
			spec:getPosition():sendMagicEffect(295) -- effect 295: BLOOD_DRAIN
			doTargetCombatHealth(player, spec, COMBAT_DEATHDAMAGE, -dmg, -dmg, 249)
			totalDamageDealt = totalDamageDealt + dmg
		end
	end

	-- Roubo de Vida Supremo (Lifesteal AOE): Cura 50% de TODO o dano causado a todas as criaturas atingidas
	if totalDamageDealt > 0 then
		local healAmount = math.floor(totalDamageDealt * 0.50)
		player:addHealth(healAmount)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Crimson Harvest drenou %d de vida das suas vítimas!", healAmount))
	end

	return true
end

spell:group("attack")
spell:id(245)
spell:name("Crimson Harvest")
spell:words("exevo gran mas sanguis")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_ORRIBLE_EXECUTION)
spell:level(1)
spell:mana(100)
spell:isPremium(false)
spell:isSelfTarget(true)
spell:cooldown(30 * 1000)
spell:groupCooldown(4 * 1000)

spell:vocation("hemomante;true", "arch hemomante;true")
spell:register()
