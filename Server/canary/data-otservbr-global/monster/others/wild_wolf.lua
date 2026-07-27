local mType = Game.createMonsterType("Wild Wolf")

local monster = {}

monster.description = "a wild wolf"
monster.experience = 25
monster.outfit = {
    lookType =3,
}

monster.health = 90
monster.maxHealth = 90
monster.race = "blood"
monster.corpse = 5968
monster.speed = 190

monster.changeTarget = {
    interval = 4000,
    chance = 8,
}

monster.strategiesTarget = {
    nearest = 100,
}

monster.attacks = {
    {
        name = "melee",
        interval = 2000,
        chance = 100,
        minDamage = -5,
        maxDamage = -15,
    },
    {
        name = "combat",
        interval = 4000,
        chance = 20,
        type = COMBAT_PHYSICALDAMAGE,
        minDamage = -10,
        maxDamage = -20,
        range = 5,
        shootEffect = CONST_ANI_SPEAR,
        target = true,
    },
    {
        name = "combat",
        interval = 6000,
        chance = 15,
        type = COMBAT_POISONDAMAGE,
        minDamage = -3,
        maxDamage = -6,
        range = 1,
        condition = {
            type = CONDITION_POISON,
            totalDamage = 20,
            interval = 2000,
        },
    },
}
monster.defenses = {
    defense = 10,
    armor = 5,
}

monster.elements = {
    { type = COMBAT_PHYSICALDAMAGE, percent = 0 },
    { type = COMBAT_ICEDAMAGE, percent = -10 },  -- levemente fraco a gelo
    { type = COMBAT_FIREDAMAGE, percent = 10 },  -- levemente resistente a fogo (pelagem grossa)
    { type = COMBAT_HOLYDAMAGE, percent = 0 },
    { type = COMBAT_DEATHDAMAGE, percent = 0 },
    { type = COMBAT_ENERGYDAMAGE, percent = 0 },
    { type = COMBAT_EARTHDAMAGE, percent = 0 },
    { type = COMBAT_POISONDAMAGE, percent = 100 }, -- imune ao próprio veneno
}

monster.immunities = {
    { type = "paralyze", condition = true },
    { type = "invisible", condition = true },
    { type = "outfit", condition = false },
    { type = "drunk", condition = false },
    { type = "bleed", condition = false },
}

monster.voices = {
	interval = 5000,
	chance = 10,
	{ text = "GRRR", yell = true },
	{ text = "GRROARR", yell = true },
}

monster.loot = {
    { id = 3031, chance = 100000, maxCount = 15 },
    { id = 2670, chance = 3000}
}

mType:register(monster)