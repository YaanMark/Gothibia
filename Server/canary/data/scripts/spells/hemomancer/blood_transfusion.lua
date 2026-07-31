local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	local target = creature:getTarget()
	if not target or not target:isCreature() then
		return false
	end

	local player = creature:getPlayer()
	if not player then
		return false
	end

	local level = player:getLevel()
	local maglevel = player:getMagicLevel()

	-- Formula de dano moderado (nivel 1)
	local minDmg = math.floor((level / 5) + (maglevel * 2.0) + 15)
	local maxDmg = math.floor((level / 5) + (maglevel * 3.2) + 30)
	local damage = math.random(minDmg, maxDmg)

	-- Efeitos no alvo ao roubar sangue
	local targetPos = target:getPosition()
	targetPos:sendMagicEffect(215)
	targetPos:sendMagicEffect(1) -- DRAWBLOOD

	doTargetCombatHealth(player, target, COMBAT_DEATHDAMAGE, -damage, -damage, 215)

	-- Roubo de Vida: cura 50% do dano causado diretamente no Hemomante
	local healAmount = math.floor(damage * 0.5)
	if healAmount > 0 then
		player:addHealth(healAmount)
	end

	-- Efeito visual de anel de sangue no conjurador (effect 30: RED_RINGS)
	local playerPos = player:getPosition()
	playerPos:sendMagicEffect(30)

	return true
end

spell:group("attack")
spell:id(241)
spell:name("Blood Transfusion")
spell:words("exura sanguis")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_HEAL_FRIEND)
spell:level(1)
spell:mana(10)
spell:needTarget(true)
spell:blockWalls(true)
spell:isPremium(false)
spell:cooldown(1 * 1000)
spell:groupCooldown(1 * 1000)

spell:vocation("hemomante;true", "arch hemomante;true")
spell:register()
