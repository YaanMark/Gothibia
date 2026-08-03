local pick = Action()

function pick.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	return onUsePick(player, item, fromPosition, target, toPosition, isHotkey)
end

-- Disabled here because it's now registered in custom/mining/mining.lua
-- pick:id(3456)
-- pick:register()
