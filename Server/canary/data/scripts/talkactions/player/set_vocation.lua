local setVocation = TalkAction("/vocation", "/voc")

local initialVocations = {
	["sorcerer"] = VOCATION.ID.SORCERER,
	["1"] = VOCATION.ID.SORCERER,
	["druid"] = VOCATION.ID.DRUID,
	["2"] = VOCATION.ID.DRUID,
	["paladin"] = VOCATION.ID.PALADIN,
	["3"] = VOCATION.ID.PALADIN,
	["knight"] = VOCATION.ID.KNIGHT,
	["4"] = VOCATION.ID.KNIGHT,
	["monk"] = VOCATION.ID.MONK,
	["9"] = VOCATION.ID.MONK,
	["hemomante"] = VOCATION.ID.HEMOMANTE,
	["11"] = VOCATION.ID.HEMOMANTE,
}

local starterKits = {
	[VOCATION.ID.SORCERER] = {
		items = { { 3059, 1 }, { 3074, 1 }, { 7991, 1 }, { 7992, 1 }, { 3362, 1 }, { 3552, 1 }, { 3572, 1 } },
		container = { { 3003, 1 }, { 5710, 1 }, { 268, 10 } },
	},
	[VOCATION.ID.DRUID] = {
		items = { { 3059, 1 }, { 3066, 1 }, { 7991, 1 }, { 7992, 1 }, { 3362, 1 }, { 3552, 1 }, { 3572, 1 } },
		container = { { 3003, 1 }, { 5710, 1 }, { 268, 10 } },
	},
	[VOCATION.ID.PALADIN] = {
		items = { { 3425, 1 }, { 3277, 1 }, { 3571, 1 }, { 8095, 1 }, { 3552, 1 }, { 3572, 1 }, { 3374, 1 } },
		container = { { 3003, 1 }, { 5710, 1 }, { 266, 10 }, { 3350, 1 }, { 3447, 50 } },
	},
	[VOCATION.ID.KNIGHT] = {
		items = { { 3425, 1 }, { 7773, 1 }, { 3359, 1 }, { 3354, 1 }, { 3372, 1 }, { 3552, 1 }, { 3572, 1 } },
		container = { { 7774, 1 }, { 3327, 1 }, { 3003, 1 }, { 5710, 1 }, { 266, 10 } },
	},
	[VOCATION.ID.MONK] = {
		items = { { 50171, 1 }, { 3359, 1 }, { 3354, 1 }, { 3372, 1 }, { 3552, 1 }, { 3572, 1 } },
		container = { { 3425, 1 }, { 3003, 1 }, { 5710, 1 }, { 266, 10 } },
	},
	[VOCATION.ID.HEMOMANTE] = {
		items = { { 3059, 1 }, { 3074, 1 }, { 7991, 1 }, { 7992, 1 }, { 3362, 1 }, { 3552, 1 }, { 3572, 1 } },
		container = { { 3003, 1 }, { 5710, 1 }, { 268, 10 } },
	},
}

function setVocation.onSay(player, words, param)
	if param == "" then
		player:sendTextMessage(MESSAGE_INFO_DESCR, "Uso correto: /vocation <nomeDaClasse>\nOpcoes iniciais: Sorcerer, Druid, Paladin, Knight, Monk, Hemomante.")
		return true
	end

	local vocId = initialVocations[input]

	if not vocId then
		player:sendCancelMessage("Vocacao invalida! Escolha entre: Sorcerer, Druid, Paladin, Knight, Monk ou Hemomante.")
		return true
	end

	player:setVocation(vocId)

	-- Automatically learn all Hemomancer spells & set custom Hemomancer outfit
	if vocId == VOCATION.ID.HEMOMANTE or vocId == VOCATION.ID.ARCH_HEMOMANTE then
		local spellsToLearn = {
			"Sanguine Bolt",
			"Blood Transfusion",
			"Vampiric Touch",
			"Blood Nova",
			"Sanguine Armor",
			"Crimson Harvest",
		}
		for _, spellName in ipairs(spellsToLearn) do
			player:learnSpell(spellName)
		end

		-- Set official Hemomancer Outfit (1680 male, 1681 female)
		local hemomancerOutfit = {
			lookType = player:getSex() == PLAYERSEX_FEMALE and 1681 or 1680,
			lookHead = 114, -- Dark Red / Carmine
			lookBody = 114,
			lookLegs = 114,
			lookFeet = 114,
			lookAddons = 0,
			lookMount = 0
		}
		player:setOutfit(hemomancerOutfit)
	end

	-- Deliver starter kit if available
	local kit = starterKits[vocId]
	if kit then
		if kit.items then
			for _, item in ipairs(kit.items) do
				player:addItem(item[1], item[2])
			end
		end

		local backpack = player:addItem(2854)
		if backpack and kit.container then
			for _, item in ipairs(kit.container) do
				backpack:addItem(item[1], item[2])
			end
		end
	end

	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_RED)
	player:sendTextMessage(MESSAGE_INFO_DESCR, "Parabens! Sua vocacao foi definida com sucesso para: " .. player:getVocation():getName() .. "!")
	return true
end

setVocation:separator(" ")
setVocation:groupType("normal")
setVocation:register()
