/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 * Contributors: https://github.com/opentibiabr/canary/graphs/contributors
 * Website: https://docs.opentibiabr.com/
 */

#include "pch.hpp"
#include "game/tooltip/tooltip.hpp"

using json = nlohmann::json;

std::string TooltipSerializer::serialize(const ItemType &item) {
	return toJsonObject(item).dump();
}

json TooltipSerializer::toJsonObject(const ItemType &item) {
	json j;

	// Basic Identification & Names
	j["id"] = item.id;
	j["clientId"] = item.id;
	j["name"] = item.name;
	j["article"] = item.article;
	j["pluralName"] = item.getPluralName();
	j["description"] = item.description;

	// Combat & Stats
	j["attack"] = item.attack;
	j["defense"] = item.defense;
	j["extraDefense"] = item.extraDefense;
	j["armor"] = item.armor;
	j["weight"] = item.weight;
	j["slotPosition"] = item.slotPosition;

	// Weapon & Ammo
	j["weaponType"] = static_cast<uint8_t>(item.weaponType);
	j["ammoType"] = static_cast<uint8_t>(item.ammoType);
	j["shootRange"] = item.shootRange;

	// Chances
	j["hitChance"] = item.hitChance;
	j["maxHitChance"] = item.maxHitChance;

	// Requirements & Classifications
	j["minReqLevel"] = item.minReqLevel;
	j["minReqMagicLevel"] = item.minReqMagicLevel;
	j["vocationString"] = item.vocationString;
	j["classification"] = item.m_primaryType;
	j["upgradeClassification"] = item.upgradeClassification;

	// Light
	j["lightLevel"] = item.lightLevel;
	j["lightColor"] = item.lightColor;

	// Flags & Attributes
	j["stackable"] = item.stackable;
	j["pickupable"] = item.pickupable;
	j["movable"] = item.movable;
	j["rotatable"] = item.rotatable;
	j["alwaysOnTop"] = (item.alwaysOnTopOrder > 0);
	j["walkStack"] = item.walkStack;

	// Types & Groups
	j["type"] = static_cast<uint8_t>(item.type);
	j["group"] = static_cast<uint8_t>(item.group);

	// Abilities Sub-object (if present)
	if (item.abilities) {
		json ab;
		ab["speed"] = item.abilities->speed;
		ab["manaShield"] = item.abilities->manaShield;
		ab["invisible"] = item.abilities->invisible;
		ab["regeneration"] = item.abilities->regeneration;
		ab["healthGain"] = item.abilities->healthGain;
		ab["healthTicks"] = item.abilities->healthTicks;
		ab["manaGain"] = item.abilities->manaGain;
		ab["manaTicks"] = item.abilities->manaTicks;
		ab["elementDamage"] = item.abilities->elementDamage;
		ab["elementType"] = static_cast<uint8_t>(item.abilities->elementType);

		// Skills
		json skills;
		for (size_t s = 0; s <= SKILL_LAST; ++s) {
			if (item.abilities->skills[s] != 0) {
				skills[std::to_string(s)] = item.abilities->skills[s];
			}
		}
		if (!skills.empty()) {
			ab["skills"] = skills;
		}

		// Stats
		json stats;
		for (size_t st = 0; st <= STAT_LAST; ++st) {
			if (item.abilities->stats[st] != 0) {
				stats[std::to_string(st)] = item.abilities->stats[st];
			}
		}
		if (!stats.empty()) {
			ab["stats"] = stats;
		}

		j["abilities"] = ab;
	}

	// Augments Sub-object (if present)
	if (!item.augments.empty()) {
		json augList = json::array();
		for (const auto &aug : item.augments) {
			if (aug) {
				json augJson;
				augJson["description"] = item.getFormattedAugmentDescription(aug);
				augList.push_back(augJson);
			}
		}
		j["augments"] = augList;
	}

	return j;
}
