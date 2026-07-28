local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_DEATHDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, 1) -- effect 1: DRAWBLOOD
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, CONST_ANI_DEATH)

function onGetFormulaValues(player, level, maglevel)
	local min = (level / 5) + (maglevel * 2.2) + 10
	local max = (level / 5) + (maglevel * 3.4) + 20
	return -min, -max
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

spell:group("attack")
spell:id(240)
spell:name("Sanguine Bolt")
spell:words("exori sanguis")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_ORRIBLE_EXECUTION)
spell:level(12)
spell:mana(20)
spell:isPremium(false)
spell:needTarget(true)
spell:blockWalls(true)
spell:cooldown(2 * 1000)
spell:groupCooldown(2 * 1000)

spell:vocation("hemomante;true", "arch hemomante;true")
spell:register()
