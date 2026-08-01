local gearScoreEvent = EventCallback("GearScoreRecalculate")
gearScoreEvent:type("playerOnRecalculateGearScore")
function gearScoreEvent.playerOnRecalculateGearScore(self)
	local gs = 0
	-- Check all equipment slots (1 to 10)
	for slot = CONST_SLOT_HEAD, CONST_SLOT_AMMO do
		local item = self:getSlotItem(slot)
		if item then
			local itemType = item:getType()
			local itemLevel = itemType:getItemLevel() or 0
			local rarity = itemType:getRarity() or 0
			local refine = item:getRefine() or 0
			
			print("Slot: " .. slot .. " | ID: " .. item:getId() .. " | Level: " .. itemLevel .. " | Rarity: " .. rarity .. " | Refine: " .. refine)
			
			gs = gs + itemLevel + rarity + refine
		end
	end
	self:setGearScore(gs)
end
gearScoreEvent:register()

local inventoryEvent = EventCallback("GearScoreInventoryUpdate")
inventoryEvent:type("playerOnInventoryUpdate")
function inventoryEvent.playerOnInventoryUpdate(self, item, slot, equip)
	self:recalculateGearScore()
end
inventoryEvent:register()

local loginEvent = CreatureEvent("GearScoreLogin")
function loginEvent.onLogin(player)
	player:recalculateGearScore()
	return true
end
loginEvent:register()
