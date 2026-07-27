/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 * Contributors: https://github.com/opentibiabr/canary/graphs/contributors
 * Website: https://docs.opentibiabr.com/
 */

#pragma once

#include "items/items.hpp"
#include <nlohmann/json.hpp>

class TooltipSerializer {
public:
	TooltipSerializer() = delete;

	/**
	 * @brief Serializes an ItemType into a JSON string for client Tooltip rendering.
	 * @param item The ItemType to serialize.
	 * @return JSON string representing the ItemType attributes.
	 */
	static std::string serialize(const ItemType &item);

	/**
	 * @brief Constructs a nlohmann::json object containing all ItemType fields.
	 * @param item The ItemType to serialize.
	 * @return nlohmann::json object.
	 */
	static nlohmann::json toJsonObject(const ItemType &item);
};
