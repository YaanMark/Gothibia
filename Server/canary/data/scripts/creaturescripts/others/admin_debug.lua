local OPCODE_ADMIN_DEBUG = 192

local adminDebugOpcode = CreatureEvent("AdminDebugOpcode")

local function hasAdminAccess(player)
	if not player then return false end
	local group = player:getGroup()
	if group and (group:getAccess() or group:getId() >= 3) then
		return true
	end
	if player:getAccountType() >= ACCOUNT_TYPE_GAMEMASTER then
		return true
	end
	return false
end

function adminDebugOpcode.onExtendedOpcode(player, opcode, buffer)
	if opcode ~= OPCODE_ADMIN_DEBUG then
		return
	end

	local isGM = hasAdminAccess(player)

	local status, data = pcall(function() return json.decode(buffer) end)
	if status and type(data) == "table" then
		if data.cmd == "checkAccess" then
			local response = json.encode({ cmd = "accessResult", allowed = isGM })
			player:sendExtendedOpcode(OPCODE_ADMIN_DEBUG, response)
			return
		end
	end

	-- Segurança: Bloqueia comandos para jogadores comuns
	if not isGM then
		local response = json.encode({ cmd = "accessResult", allowed = false })
		player:sendExtendedOpcode(OPCODE_ADMIN_DEBUG, response)
		return
	end
end

adminDebugOpcode:register()
