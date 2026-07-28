local OPCODE_ADMIN_DEBUG = 192

local adminDebugOpcode = CreatureEvent("AdminDebugOpcode")

-- Lista de nomes de personagens autorizados manualmente (opcional):
local AUTHORIZED_PLAYERS = {}

function hasAdminAccess(player)
	if not player then return false end

	-- 1. Verifica por nome na lista de autorizados
	local name = player:getName()
	if name then
		for _, allowedName in ipairs(AUTHORIZED_PLAYERS) do
			if allowedName:lower() == name:lower() then
				return true
			end
		end
	end

	-- 2. Verifica por Grupo (Tutor, Senior Tutor, GM, CM, GOD)
	local group = player:getGroup()
	if group then
		if group:getAccess() then return true end
		if group:getId() and group:getId() >= 2 then return true end
	end

	-- 3. Verifica por Tipo de Conta (AccountType >= 2)
	if player:getAccountType() and player:getAccountType() >= 2 then
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

	-- Segurança: Envia resultado falso se não for autorizado
	if not isGM then
		local response = json.encode({ cmd = "accessResult", allowed = false })
		player:sendExtendedOpcode(OPCODE_ADMIN_DEBUG, response)
		return
	end
end

adminDebugOpcode:register()
