-- Sistema Admin Debug
-- Opcode: 192
-- Acesso: accessLevel >= 3 OU nome na lista ALLOWED_PLAYERS

local OPCODE = 192
local TASK_POINT_STORAGE = 99999

local ALLOWED_PLAYERS = {
    ["Kina Teste"] = true,
    ["Kina Viny"] = true,
}

local printNomenclature = ">>>>>> [ADMIN DEBUG] "

local RELOAD_TYPES = {
    ["scripts"]    = RELOAD_TYPE_SCRIPTS,
    ["monsters"]   = RELOAD_TYPE_MONSTERS,
    ["npcs"]       = RELOAD_TYPE_NPCS,
    ["items"]      = RELOAD_TYPE_ITEMS,
    ["raids"]      = RELOAD_TYPE_RAIDS,
    ["mounts"]     = RELOAD_TYPE_MOUNTS,
    ["imbuements"] = RELOAD_TYPE_IMBUEMENTS,
    ["globalevents"] = RELOAD_TYPE_GLOBALEVENTS,
    ["all"]        = RELOAD_TYPE_ALL,
}

-- Skill names usados pelo cliente
local SKILL_MAP = {
    ["level"]  = "level",
    ["magic"]  = "magic",
    ["sword"]  = "sword",
    ["axe"]    = "axe",
    ["club"]   = "club",
    ["dist"]   = "dist",
    ["shield"] = "shield",
    ["fish"]   = "fish",
}

local function isAllowed(player)
    if player:getGroup():getAccess() then return true end
    if ALLOWED_PLAYERS[player:getName()] then return true end
    return false
end

local function deny(player)
    player:sendTextMessage(MESSAGE_STATUS, "Voce nao tem permissao de administrador.")
end

local function getTarget(player, name)
    if not name or name == "" then return player end
    local target = Player(name)
    if not target then
        player:sendTextMessage(MESSAGE_STATUS, "Jogador '" .. name .. "' nao encontrado ou offline.")
        return nil
    end
    return target
end

local function applyBoost(target, minutes)
    if minutes <= 0 then return end
    local maxMinutes = math.min(minutes, 180)
    -- Converte minutos para segundos e aplica o boost
    target:setXpBoostTime(maxMinutes * 60)
end

local AdminDebugExtended = CreatureEvent("AdminDebugExtended")
AdminDebugExtended:type("extendedopcode")

function AdminDebugExtended.onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE then return end
    if not isAllowed(player) then deny(player); return end

    local ok, data = pcall(json.decode, buffer)
    if not ok or type(data) ~= "table" then return end

    local cmd = data.cmd
    if not cmd then return end

    if cmd == "addXp" then
        local amount = math.max(1, math.floor(tonumber(data.value) or 0))
        player:addExperience(amount, false)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] +" .. amount .. " XP concedido.")
        print(printNomenclature .. "Adicionado " .. amount .. " XP para " .. player:getName() .. ".")

    elseif cmd == "addBoost" then
        local minutes = math.max(1, math.min(180, math.floor(tonumber(data.value) or 30)))
        local currentBoost = player:getXpBoostTime()
        local newBoost = math.min(currentBoost + (minutes * 60), 12 * 3600)  -- Max 12 horas
        player:setXpBoostTime(newBoost)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] +" .. minutes .. " min de Boost (Total: " .. math.floor(newBoost / 60) .. " min).")
        print(printNomenclature .. "Adicionado " .. minutes .. " min de Boost para " .. player:getName() .. ". Total: " .. math.floor(newBoost / 60) .. " min.")

    elseif cmd == "addBank" then
        local amount = math.max(1, math.floor(tonumber(data.value) or 0))
        player:setBankBalance(player:getBankBalance() + amount)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] +" .. amount .. " gold no banco.")
        print(printNomenclature .. "Adicionado " .. amount .. " gold ao banco de " .. player:getName() .. ".")

    elseif cmd == "goTo" then
        local cityName = tostring(data.value or "Thais"):lower()
        local found = nil
        for _, town in ipairs(Game.getTowns()) do
            if town:getName():lower() == cityName then
                found = town
                break
            end
        end
        if found then
            player:teleportTo(found:getTemplePosition())
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Teleportado para " .. found:getName() .. ".")
            print(printNomenclature .. player:getName() .. " teleportado para " .. found:getName() .. ".")
        else
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Cidade '" .. cityName .. "' nao encontrada.")
        end

    elseif cmd == "tpToPlayer" then
        local name = tostring(data.value or "")
        local target = Player(name)
        if target then
            player:teleportTo(target:getPosition())
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Teleportado ate " .. target:getName() .. ".")
            print(printNomenclature .. player:getName() .. " teleportado ate " .. target:getName() .. ".")
        else
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Jogador '" .. name .. "' nao encontrado.")
        end

    elseif cmd == "addPreyCards" then
        local amount = math.max(1, math.floor(tonumber(data.value) or 10))
        player:addPreyCards(amount)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] +" .. amount .. " Prey Cards.")
        print(printNomenclature .. "Adicionado " .. amount .. " Prey Cards para " .. player:getName() .. ".")

    elseif cmd == "addTaskPoints" then
        local amount = math.max(1, math.floor(tonumber(data.value) or 100))
        local current = player:getStorageValue(TASK_POINT_STORAGE)
        if current < 0 then current = 0 end
        player:setStorageValue(TASK_POINT_STORAGE, current + amount)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] +" .. amount .. " Task Points.")
        print(printNomenclature .. "Adicionado " .. amount .. " Task Points para " .. player:getName() .. ".")

    elseif cmd == "darItemMe" then
        local itemId  = math.max(100, math.floor(tonumber(data.itemId)  or 2160))
        local itemQty = math.max(1,   math.floor(tonumber(data.itemQty) or 1))
        local item = Game.createItem(itemId, itemQty)
        if item then
            player:addItemEx(item, true)
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Item " .. itemId .. " x" .. itemQty .. " adicionado.")
            print(printNomenclature .. "Item " .. itemId .. " x" .. itemQty .. " adicionado a " .. player:getName() .. ".")
        end

    elseif cmd == "invocarMonstro" then
        local name = tostring(data.value or "Rat")
        local qty  = math.max(1, math.min(50, math.floor(tonumber(data.qty) or 1)))
        local basePos = player:getPosition()
        local spawned = 0
        for i = 1, qty do
            local pos = Position(basePos.x + (i % 5), basePos.y + math.floor((i - 1) / 5), basePos.z)
            local monster = Game.createMonster(name, pos, true, true)
            if monster then spawned = spawned + 1 end
        end
        if spawned > 0 then
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] " .. spawned .. "x " .. name .. " invocado(s).")
            print(printNomenclature .. "Monstro " .. name .. " x" .. spawned .. " invocado(s) por " .. player:getName() .. ".")
        else
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Monstro '" .. name .. "' nao encontrado.")
        end

    elseif cmd == "addMount" then
        local value = tostring(data.value or "all"):lower()
        if value == "all" then
            local count = 0
            for i = 1, 255 do
                if not player:hasMount(i) then
                    player:tameMount(i)
                    count = count + 1
                end
            end
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] " .. count .. " mounts adicionados.")
            print(printNomenclature .. count .. " mounts adicionados para " .. player:getName() .. ".")
        else
            local id = math.max(1, math.floor(tonumber(value) or 1))
            player:tameMount(id)
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Mount " .. id .. " adicionado.")
            print(printNomenclature .. "Mount " .. id .. " adicionado para " .. player:getName() .. ".")
        end

    elseif cmd == "addSkill" then
        local skillName = tostring(data.skill or "level"):lower()
        local qty       = math.max(1, math.floor(tonumber(data.qty) or 1))
        if skillName == "level" then
            local needed = 0
            for i = player:getLevel(), player:getLevel() + qty - 1 do
                needed = needed + Game.getExperienceForLevel(i + 1) - Game.getExperienceForLevel(i)
            end
            player:addExperience(needed, false)
        elseif skillName == "magic" then
            local needed = 0
            for i = player:getMagicLevel(), player:getMagicLevel() + qty - 1 do
                needed = needed + 1600 * math.pow(1.1, i)
            end
            player:addManaSpent(math.floor(needed))
        else
            local skillConst = SKILL_SWORD
            local curLevel   = player:getSkillLevel(SKILL_SWORD)
            if skillName == "axe"    then skillConst = SKILL_AXE;      curLevel = player:getSkillLevel(SKILL_AXE)
            elseif skillName == "club"   then skillConst = SKILL_CLUB;     curLevel = player:getSkillLevel(SKILL_CLUB)
            elseif skillName == "dist"   then skillConst = SKILL_DISTANCE; curLevel = player:getSkillLevel(SKILL_DISTANCE)
            elseif skillName == "shield" then skillConst = SKILL_SHIELD;   curLevel = player:getSkillLevel(SKILL_SHIELD)
            elseif skillName == "fish"   then skillConst = SKILL_FISHING;  curLevel = player:getSkillLevel(SKILL_FISHING)
            end
            local needed = 0
            for i = curLevel, curLevel + qty - 1 do
                needed = needed + 50 * math.pow(1.1, i)
            end
            player:addSkillTries(skillConst, math.floor(needed))
        end
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] +" .. qty .. " " .. skillName .. ".")
        print(printNomenclature .. "Adicionado " .. qty .. " " .. skillName .. " para " .. player:getName() .. ".")

    elseif cmd == "addCharm" then
        local amount = math.max(1, math.floor(tonumber(data.value) or 1000))
        if player.addCharmPoints then
            player:addCharmPoints(amount)
            print(printNomenclature .. "Adicionado " .. amount .. " charm points para " .. player:getName() .. ".")
        else
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] addCharmPoints nao disponivel nesta versao.")
        end

    elseif cmd == "goToHouse" then
        local targetName = tostring(data.value or "")
        local target = (targetName ~= "" and Player(targetName)) or player
        if not target then
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Jogador nao encontrado."); return
        end
        local houses = Game.getHouses()
        local found = false
        for _, house in ipairs(houses) do
            if house:getOwnerGuid() == target:getGuid() then
                player:teleportTo(house:getExitPosition())
                player:sendTextMessage(MESSAGE_STATUS, "[Admin] Teleportado para saida da casa de " .. target:getName() .. ".")
                print(printNomenclature .. player:getName() .. " teleportado para casa de " .. target:getName() .. ".")
                found = true
                break
            end
        end
        if not found then
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] " .. target:getName() .. " nao possui casa.")
        end

    elseif cmd == "clearXpBoost" then
        player:setXpBoostTime(0)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] XP Boost zerado.")
        print(printNomenclature .. "XP Boost zerado para " .. player:getName() .. ".")

    elseif cmd == "restoreHpMp" then
        player:addHealth(player:getMaxHealth() - player:getHealth())
        player:addMana(player:getMaxMana() - player:getMana())
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] HP e MP restaurados.")
        print(printNomenclature .. "HP e MP restaurados para " .. player:getName() .. ".")

    elseif cmd == "clearConditions" then
        for _, cid in ipairs({CONDITION_POISON, CONDITION_FIRE, CONDITION_ENERGY, CONDITION_CURSED,
                               CONDITION_DROWN, CONDITION_BLEEDING, CONDITION_FREEZING, CONDITION_DAZZLED}) do
            player:removeCondition(cid)
        end
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] Condicoes removidas.")
        print(printNomenclature .. "Condicoes removidas para " .. player:getName() .. ".")

    elseif cmd == "fullBless" then
        for i = 1, 8 do
            player:addBlessing(i, 1)
        end
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] Full Bless aplicado.")
        print(printNomenclature .. "Full Bless aplicado para " .. player:getName() .. ".")

    elseif cmd == "removeBless" then
        for i = 1, 8 do
            player:removeBlessing(i, player:getBlessingCount(i))
        end
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] Blessings removidas.")
        print(printNomenclature .. "Blessings removidas para " .. player:getName() .. ".")

    elseif cmd == "clearBank" then
        player:setBankBalance(0)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] Banco zerado.")
        print(printNomenclature .. "Banco zerado para " .. player:getName() .. ".")

    elseif cmd == "save" then
        saveServer()
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] Servidor salvo.")
        print(printNomenclature .. "Servidor salvo.")

    elseif cmd == "reload" then
        local typeName = tostring(data.value or "scripts"):lower()
        local reloadType = RELOAD_TYPES[typeName]
        if reloadType then
            Game.reload(reloadType)
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Reload '" .. typeName .. "' executado.")
            print(printNomenclature .. "Reload '" .. typeName .. "' executado.")
        else
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Tipo de reload invalido: " .. typeName .. ". Use: scripts, monsters, npcs, items, raids, mounts, imbuements, globalevents, all")
        end

    elseif cmd == "closeServer" then
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] Fechando servidor...")
        Game.setGameState(GAME_STATE_CLOSED)
        print(printNomenclature .. "Servidor fechado.")

    elseif cmd == "openServer" then
        Game.setGameState(GAME_STATE_NORMAL)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] Servidor aberto.")
        print(printNomenclature .. "Servidor aberto.")

    elseif cmd == "broadcast" then
        local msg = tostring(data.value or "")
        if #msg > 0 then
            for _, p in ipairs(Game.getPlayers()) do
                p:sendTextMessage(MESSAGE_ADMINISTRATOR, "[Broadcast] " .. msg)
            end
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Broadcast enviado.")
            print(printNomenclature .. "Broadcast enviado: " .. msg)
        end

    elseif cmd == "ghost" then
        if player.isInGhostMode then
            local ghosted = player:isInGhostMode()
            player:setGhostMode(not ghosted)
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Ghost " .. (not ghosted and "ativado" or "desativado") .. ".")
            print(printNomenclature .. "Ghost " .. (not ghosted and "ativado" or "desativado") .. " para " .. player:getName() .. ".")
        else
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Ghost nao disponivel nesta versao.")
            print(printNomenclature .. "Ghost nao disponivel para " .. player:getName() .. ".")
        end

    elseif cmd == "ipBan" then
        local name = tostring(data.value or "")
        if #name == 0 then return end
        local target = Player(name)
        if target then
            local ip = target:getIp()
            -- Banimento de IP via banco (tabela ip_bans do Canary)
            db.asyncQuery(string.format(
                "INSERT IGNORE INTO ip_bans (ip, reason, banned_at, expires_at, banned_by) VALUES (%d, 'Admin ban', UNIX_TIMESTAMP(), UNIX_TIMESTAMP() + 86400*30, %d)",
                ip, player:getAccountId()
            ))
            target:sendTextMessage(MESSAGE_STATUS, "Voce foi banido por um administrador.")
            target:remove()
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] IP ban aplicado a " .. name .. " (30 dias).")
            print(printNomenclature .. "IP ban aplicado a " .. name .. " por " .. player:getName() .. ".")
        else
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Jogador '" .. name .. "' nao encontrado ou offline.")
        end

    elseif cmd == "unban" then
        local name = tostring(data.value or "")
        if #name == 0 then return end
        -- Busca accountId pelo nome do personagem
        local resultId = db.storeQuery(string.format(
            "SELECT account_id FROM players WHERE name = %s", db.escapeString(name)
        ))
        if resultId then
            local accountId = result.getNumber(resultId, "account_id")
            result.free(resultId)
            db.asyncQuery(string.format(
                "DELETE FROM account_bans WHERE account_id = %d", accountId
            ))
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Ban de conta de '" .. name .. "' removido.")
            print(printNomenclature .. "Ban de " .. name .. " removido por " .. player:getName() .. ".")
        else
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Personagem '" .. name .. "' nao encontrado.")
        end
        -- Remove IP ban baseando-se no IP atual (se online)
        local onlineTarget = Player(name)
        if onlineTarget then
            db.asyncQuery(string.format(
                "DELETE FROM ip_bans WHERE ip = %d", onlineTarget:getIp()
            ))
        end

    elseif cmd == "kick" then
        local name = tostring(data.value or "")
        if #name == 0 then return end
        local target = Player(name)
        if target then
            target:sendTextMessage(MESSAGE_STATUS, "Voce foi desconectado por um administrador.")
            target:remove()
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] " .. name .. " foi kickado.")
            print(printNomenclature .. name .. " foi kickado por " .. player:getName() .. ".")
        else
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Jogador '" .. name .. "' nao encontrado.")
        end

    elseif cmd == "spy" then
        local name = tostring(data.value or "")
        if #name == 0 then return end
        local target = Player(name)
        if not target then
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Jogador '" .. name .. "' nao encontrado.")
            return
        end
        local info = {
            "=== SPY: " .. target:getName() .. " ===",
            "Level: " .. target:getLevel() .. "  Voc: " .. target:getVocation():getName(),
            "HP: " .. target:getHealth() .. "/" .. target:getMaxHealth() ..
            "  MP: " .. target:getMana() .. "/" .. target:getMaxMana(),
            "Pos: " .. tostring(target:getPosition()),
            "Conta: " .. target:getAccountId(),
            "IP: " .. target:getIp(),
        }
        for _, line in ipairs(info) do
            player:sendTextMessage(MESSAGE_STATUS, line)
        end
        print(printNomenclature .. "Spy em " .. target:getName() .. " executado por " .. player:getName() .. ".")

    elseif cmd == "darItemPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        local itemId  = math.max(100, math.floor(tonumber(data.itemId)  or 2160))
        local itemQty = math.max(1,   math.floor(tonumber(data.itemQty) or 1))
        local item = Game.createItem(itemId, itemQty)
        if item then
            target:addItemEx(item, true)
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Item " .. itemId .. " x" .. itemQty .. " dado a " .. target:getName() .. ".")
            print(printNomenclature .. "Item " .. itemId .. " x" .. itemQty .. " dado a " .. target:getName() .. " por " .. player:getName() .. ".")
        end

    elseif cmd == "darXpPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        local amount = math.max(1, math.floor(tonumber(data.value) or 1000000))
        target:addExperience(amount, false)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] +" .. amount .. " XP para " .. target:getName() .. ".")
        print(printNomenclature .. "Adicionado " .. amount .. " XP para " .. target:getName() .. " por " .. player:getName() .. ".")

    elseif cmd == "addBoostPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        local minutes = math.max(1, math.min(180, math.floor(tonumber(data.value) or 30)))
        local currentBoost = target:getXpBoostTime()
        local newBoost = math.min(currentBoost + (minutes * 60), 12 * 3600)  -- Max 12 horas
        target:setXpBoostTime(newBoost)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] +" .. minutes .. " min de Boost para " .. target:getName() .. " (Total: " .. math.floor(newBoost / 60) .. " min).")
        print(printNomenclature .. "Adicionado " .. minutes .. " min de Boost a " .. target:getName() .. " por " .. player:getName() .. ". Total: " .. math.floor(newBoost / 60) .. " min.")

    elseif cmd == "addPreyPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        local amount = math.max(1, math.floor(tonumber(data.value) or 10))
        target:addPreyCards(amount)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] +" .. amount .. " Prey Cards para " .. target:getName() .. ".")
        print(printNomenclature .. "Adicionado " .. amount .. " Prey Cards a " .. target:getName() .. " por " .. player:getName() .. ".")

    elseif cmd == "addTaskPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        local amount = math.max(1, math.floor(tonumber(data.value) or 100))
        local current = target:getStorageValue(TASK_POINT_STORAGE)
        if current < 0 then current = 0 end
        target:setStorageValue(TASK_POINT_STORAGE, current + amount)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] +" .. amount .. " Task Points para " .. target:getName() .. ".")
        print(printNomenclature .. "Adicionado " .. amount .. " Task Points a " .. target:getName() .. " por " .. player:getName() .. ".")

    elseif cmd == "addBankPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        local amount = math.max(1, math.floor(tonumber(data.value) or 100000))
        target:setBankBalance(target:getBankBalance() + amount)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] +" .. amount .. " gold no banco de " .. target:getName() .. ".")
        print(printNomenclature .. "Adicionado " .. amount .. " gold ao banco de " .. target:getName() .. " por " .. player:getName() .. ".")

    elseif cmd == "addMountPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        local value = tostring(data.value or "all"):lower()
        if value == "all" then
            local count = 0
            for i = 1, 255 do
                if not target:hasMount(i) then target:tameMount(i); count = count + 1 end
            end
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] " .. count .. " mounts para " .. target:getName() .. ".")
            print(printNomenclature .. count .. " mounts adicionados a " .. target:getName() .. " por " .. player:getName() .. ".")
        else
            local id = math.max(1, math.floor(tonumber(value) or 1))
            target:tameMount(id)
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Mount " .. id .. " para " .. target:getName() .. ".")
            print(printNomenclature .. "Mount " .. id .. " adicionado a " .. target:getName() .. " por " .. player:getName() .. ".")
        end

    elseif cmd == "addSkillPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        local skillName = tostring(data.skill or "level"):lower()
        local qty       = math.max(1, math.floor(tonumber(data.qty) or 1))
        if skillName == "level" then
            local needed = 0
            for i = target:getLevel(), target:getLevel() + qty - 1 do
                needed = needed + Game.getExperienceForLevel(i + 1) - Game.getExperienceForLevel(i)
            end
            target:addExperience(needed, false)
        elseif skillName == "magic" then
            local needed = 0
            for i = target:getMagicLevel(), target:getMagicLevel() + qty - 1 do
                needed = needed + 1600 * math.pow(1.1, i)
            end
            target:addManaSpent(math.floor(needed))
        else
            local skillConst = SKILL_SWORD
            local curLevel = target:getSkillLevel(SKILL_SWORD)
            if skillName == "axe"    then skillConst = SKILL_AXE;      curLevel = target:getSkillLevel(SKILL_AXE)
            elseif skillName == "club"   then skillConst = SKILL_CLUB;     curLevel = target:getSkillLevel(SKILL_CLUB)
            elseif skillName == "dist"   then skillConst = SKILL_DISTANCE; curLevel = target:getSkillLevel(SKILL_DISTANCE)
            elseif skillName == "shield" then skillConst = SKILL_SHIELD;   curLevel = target:getSkillLevel(SKILL_SHIELD)
            elseif skillName == "fish"   then skillConst = SKILL_FISHING;  curLevel = target:getSkillLevel(SKILL_FISHING)
            end
            local needed = 0
            for i = curLevel, curLevel + qty - 1 do
                needed = needed + 50 * math.pow(1.1, i)
            end
            target:addSkillTries(skillConst, math.floor(needed))
        end
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] +" .. qty .. " " .. skillName .. " para " .. target:getName() .. ".")
        print(printNomenclature .. "Adicionado " .. qty .. " " .. skillName .. " a " .. target:getName() .. " por " .. player:getName() .. ".")

    elseif cmd == "addCharmPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        local amount = math.max(1, math.floor(tonumber(data.value) or 1000))
        if target.addCharmPoints then
            target:addCharmPoints(amount)
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] +" .. amount .. " charm points para " .. target:getName() .. ".")
            print(printNomenclature .. "Adicionado " .. amount .. " charm points a " .. target:getName() .. " por " .. player:getName() .. ".")
        else
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] addCharmPoints nao disponivel.")
        end

    elseif cmd == "goToHousePlayer" then
        local target = getTarget(player, tostring(data.target or data.value or ""))
        if not target then return end
        local houses = Game.getHouses()
        local found = false
        for _, house in ipairs(houses) do
            if house:getOwnerGuid() == target:getGuid() then
                player:teleportTo(house:getExitPosition())
                player:sendTextMessage(MESSAGE_STATUS, "[Admin] Teleportado para saida da casa de " .. target:getName() .. ".")
                print(printNomenclature .. player:getName() .. " teleportado para casa de " .. target:getName() .. ".")
                found = true
                break
            end
        end
        if not found then
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] " .. target:getName() .. " nao possui casa.")
        end

    elseif cmd == "tpToMe" then
        local name = tostring(data.target or "")
        local target = Player(name)
        if target then
            target:teleportTo(player:getPosition())
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] " .. target:getName() .. " teleportado ate voce.")
            print(printNomenclature .. target:getName() .. " teleportado ate " .. player:getName() .. ".")
        else
            player:sendTextMessage(MESSAGE_STATUS, "[Admin] Jogador '" .. name .. "' nao encontrado.")
        end


    elseif cmd == "clearXpBoostPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        target:setXpBoostTime(0)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] XP Boost de " .. target:getName() .. " zerado.")
        print(printNomenclature .. "XP Boost zerado para " .. target:getName() .. " por " .. player:getName() .. ".")

    elseif cmd == "restoreHpMpPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        target:addHealth(target:getMaxHealth() - target:getHealth())
        target:addMana(target:getMaxMana() - target:getMana())
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] HP/MP de " .. target:getName() .. " restaurados.")
        print(printNomenclature .. "HP/MP restaurados para " .. target:getName() .. " por " .. player:getName() .. ".")

    elseif cmd == "clearConditionsPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        for _, cid in ipairs({CONDITION_POISON, CONDITION_FIRE, CONDITION_ENERGY, CONDITION_CURSED,
                               CONDITION_DROWN, CONDITION_BLEEDING, CONDITION_FREEZING, CONDITION_DAZZLED}) do
            target:removeCondition(cid)
        end
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] Condicoes de " .. target:getName() .. " removidas.")
        print(printNomenclature .. "Condicoes removidas para " .. target:getName() .. " por " .. player:getName() .. ".")

    elseif cmd == "fullBlessPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        for i = 1, 8 do target:addBlessing(i, 1) end
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] Full Bless em " .. target:getName() .. ".")
        print(printNomenclature .. "Full Bless aplicado a " .. target:getName() .. " por " .. player:getName() .. ".")

    elseif cmd == "removeBlessPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        for i = 1, 8 do target:removeBlessing(i, target:getBlessingCount(i)) end
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] Blessings de " .. target:getName() .. " removidas.")
        print(printNomenclature .. "Blessings removidas de " .. target:getName() .. " por " .. player:getName() .. ".")

    elseif cmd == "clearBankPlayer" then
        local target = getTarget(player, tostring(data.target or ""))
        if not target then return end
        target:setBankBalance(0)
        player:sendTextMessage(MESSAGE_STATUS, "[Admin] Banco de " .. target:getName() .. " zerado.")
        print(printNomenclature .. "Banco zerado para " .. target:getName() .. " por " .. player:getName() .. ".")

    end
end

AdminDebugExtended:register()

local AdminDebugLogin = CreatureEvent("AdminDebugLogin")
AdminDebugLogin:type("login")

function AdminDebugLogin.onLogin(player)
    player:registerEvent("AdminDebugExtended")
    return true
end

AdminDebugLogin:register()