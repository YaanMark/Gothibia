local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_HEALING)
combat:setParameter(COMBAT_PARAM_EFFECT, 30) -- effect 30: RED_RINGS
combat:setParameter(COMBAT_PARAM_AGGRESSIVE, false)

function onGetFormulaValues(player, level, maglevel)
	local min = (level / 5) + (maglevel * 3.0) + 25
	local max = (level / 5) + (maglevel * 5.2) + 50
	return min, max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	local player = creature:getPlayer()
	if player then
		player:getPosition():sendMagicEffect(14) -- effect 14: REDSHIMMER
	end
	return combat:execute(creature, var)
end

spell:group("healing")
spell:id(241)
spell:name("Blood Transfusion")
spell:words("exura sanguis")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_HEAL_FRIEND)
spell:level(20)
spell:mana(45)
spell:isSelfTarget(true)
spell:isPremium(false)
spell:cooldown(1 * 1000)
spell:groupCooldown(1 * 1000)

spell:vocation("hemomante;true", "arch hemomante;true")
spell:register()
