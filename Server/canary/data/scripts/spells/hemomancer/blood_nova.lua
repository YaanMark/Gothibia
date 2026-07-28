local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_DEATHDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, 63) -- effect 63: MORTAREA

local area = createCombatArea(AREA_SQUARE3X3)
combat:setArea(area)

function onGetFormulaValues(player, level, maglevel)
	local min = (level / 5) + (maglevel * 3.2) + 25
	local max = (level / 5) + (maglevel * 4.8) + 50
	return -min, -max
end

combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")

local spell = Spell("instant")

function spell.onCastSpell(creature, var)
	local player = creature:getPlayer()
	if player then
		local pos = player:getPosition()
		pos:sendMagicEffect(30) -- effect 30: RED_RINGS
		pos:sendMagicEffect(64) -- effect 64
	end
	return combat:execute(creature, var)
end

spell:group("attack")
spell:id(243)
spell:name("Blood Nova")
spell:words("exori gran sanguis")
spell:castSound(SOUND_EFFECT_TYPE_SPELL_ORRIBLE_EXECUTION)
spell:level(50)
spell:mana(140)
spell:isPremium(false)
spell:isSelfTarget(true)
spell:cooldown(4 * 1000)
spell:groupCooldown(2 * 1000)

spell:vocation("hemomante;true", "arch hemomante;true")
spell:register()
