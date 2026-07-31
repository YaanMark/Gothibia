local hasteCondition = Condition(CONDITION_HASTE)
hasteCondition:setParameter(CONDITION_PARAM_TICKS, 30000)
hasteCondition:setFormula(0.3, -24, 0.3, -24)

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	local player = creature:getPlayer()
	if not player then
		return false
	end

	player:addCondition(hasteCondition)

	local pos = player:getPosition()
	pos:sendMagicEffect(223) -- effect 223: RED_GLOW
	pos:sendMagicEffect(273) -- effect 273: RED_EXPLOSION

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Sua pele se reveste com uma armadura de sangue fervente!")
	return true
end

spell:group("support")
spell:id(244)
spell:name("Sanguine Armor")
spell:words("exeta sanguis")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_GREAT_LIGHT)
spell:level(1)
spell:mana(50)
spell:isSelfTarget(true)
spell:isPremium(false)
spell:cooldown(30 * 1000)
spell:groupCooldown(2 * 1000)

spell:vocation("hemomante;true", "arch hemomante;true")
spell:register()
