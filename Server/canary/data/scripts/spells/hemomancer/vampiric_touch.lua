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

	local minDmg = math.floor((level / 5) + (maglevel * 3.5) + 30)
	local maxDmg = math.floor((level / 5) + (maglevel * 5.5) + 60)
	local damage = math.random(minDmg, maxDmg)

	-- Aplica dano ao alvo com efeitos viscerais de sangue (effect 215 e effect 1)
	local targetPos = target:getPosition()
	targetPos:sendMagicEffect(215)
	targetPos:sendMagicEffect(1) -- DRAWBLOOD

	doTargetCombatHealth(player, target, COMBAT_DEATHDAMAGE, -damage, -damage, 215)

	-- Roubo de Vida (Lifesteal): Restaura 100% do dano causado diretamente para a vida do Hemomante
	player:addHealth(damage)

	-- Efeitos visuais no invocador (effect 223 e 14)
	local playerPos = player:getPosition()
	playerPos:sendMagicEffect(223) -- RED GLOW
	playerPos:sendMagicEffect(14)  -- REDSHIMMER

	return true
end

spell:group("attack")
spell:id(242)
spell:name("Vampiric Touch")
spell:words("exori vita sanguis")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_ORRIBLE_EXECUTION)
spell:level(1)
spell:mana(25)
spell:isPremium(false)
spell:needTarget(true)
spell:blockWalls(true)
spell:cooldown(4 * 1000)
spell:groupCooldown(2 * 1000)

spell:vocation("hemomante;true", "arch hemomante;true")
spell:register()
