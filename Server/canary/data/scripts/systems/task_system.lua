-- ===========================================================================
-- TASK SYSTEM - Guia de uso
-- ===========================================================================
-- Como adicionar uma task ao sistema:
--
-- Edite os arquivos JSON em: data/scripts/systems/tasksJson/
--   configTasks.json          -> tasks principais (em sequencia)
--   configTasksExclusivas.json -> tasks independentes (exclusive)
--   configTasksBoss.json      -> tasks de bosses
--   shopItems.json            -> itens da loja de Task Points
--
-- Formato de cada task nos JSONs:
--   {
--     "nameOfTheTask": "Nome da Task (display)",
--     "creature": "Nome da Criatura (MonsterType)",
--     "locked": false,
--     "repeatable": true,
--     "killsRequired": 100,
--     "rewards": {
--       "moneyReward": 1000,
--       "pointsReward": 10,
--       "itemRewards": [ { "itemId": 2148, "count": 100 } ]
--     }
--   },
--
-- NOTA: expReward foi removido. A exp e calculada automaticamente:
--   baseExp  = (xp da criatura) * killsRequired
--   tasks/exclusive: expFinal = (baseExp * stage) / 5
--   boss:            expFinal = (baseExp * stage) * 1.3
--
-- Como funciona:
--  - O player abre o modulo no cliente (Ctrl+A ou botao na topbar)
--  - Tasks sao liberadas em ordem: so pode comecar a #N se ja concluiu a #(N-1)
--  - Tasks com `repeatable = true` podem ser refeitas quantas vezes quiser apos concluidas
--  - Tasks sem `repeatable` (ou `repeatable = false`) so podem ser feitas uma vez
--  - Ao atingir o numero de kills, o cliente recebe uma notificacao "Task Ready!"
--  - No NPC ou pelo botao Finish, o player reivindica a recompensa
--  - Task Points acumulados podem ser trocados por itens na aba Shop
--
-- Storages usadas (nao colida com outros sistemas!):
--  - 10001–13000     : kills restantes para task normal ativa
--  - 13001–16000     : 1 quando task normal concluida
--  - 16001–19000     : kills restantes para task exclusiva ativa
--  - 19001–22000     : 1 quando task exclusiva concluida
--  - 22001–25000     : kills restantes para task boss ativa
--  - 25001–28000     : 1 quando task boss concluida
--  - 99999           : total de Task Points do player
-- Para editar itens/tasks, edite os arquivos JSON em tasksJson/ (nao e necessario reiniciar para ver mudancas no proximo startup).
-- ===========================================================================

if not Player.sendExtendedJSONOpcode then
	function Player.sendExtendedJSONOpcode(self, opcode, data)
		if type(data) == "table" then
			return self:sendExtendedOpcode(opcode, json.encode(data))
		else
			return self:sendExtendedOpcode(opcode, tostring(data))
		end
	end
end

local taskPointStorage = 99999   -- storage que guarda os Task Points do player
local completedBaseStorage = 13000 -- 13001–16000: task normal concluída

local exclusiveBaseStorage = 16000          -- 16001–19000: task exclusiva ativa
local exclusiveCompletedBaseStorage = 19000 -- 19001–22000: task exclusiva concluída

local bossBaseStorage = 22000          -- 22001–25000: task boss ativa
local bossCompletedBaseStorage = 25000 -- 25001–28000: task boss concluída

-- ===========================================================================
-- CONFIGURACAO: Tasks diarias aleatorias
--   true  = sorteia 42 tasks por periodo (comportamento padrao)
--   false = exibe TODAS as tasks do configTasks.json sempre (sem rotacao)
-- ===========================================================================
local DAILY_TASKS_ENABLED = false

-- ===========================================================================
-- SHOP: itens carregados de tasksJson/shopItems.json
-- Para adicionar/editar itens da loja, edite o arquivo shopItems.json
-- ===========================================================================
local shopItems = {}

-- Retorna o timestamp do inicio do periodo atual de daily tasks
-- O periodo comeca no server save e dura 24h (ex: se save=05:00, periodo vai de 05:00 a 04:59 do dia seguinte)
local function getCurrentDailyPeriod()
	local nextSave = GetNextOccurrence(configManager.getString(configKeys.GLOBAL_SERVER_SAVE_TIME))
	return tostring(nextSave - (24 * 60 * 60))
end

-- Carrega um arquivo JSON e retorna a tabela decodificada (array Lua)
local function loadJsonFile(path)
    local file = io.open(path, "r")
    if not file then
        if not string.find(path, "dailyTasks.json") then
            logger.error("[vini21 - TaskSystem] ERRO: arquivo nao encontrado: " .. path)
        end
        return {}
    end
    local content = file:read("*all")
    file:close()
    local ok, result = pcall(json.decode, content)
    if not ok or type(result) ~= "table" then
        logger.error("[vini21 - TaskSystem] ERRO ao decodificar JSON: " .. path)
        return {}
    end
    return result
end

-- ===========================================================================
-- FORMULA DE CALCULO DE EXP DA TASK
-- ===========================================================================
-- A exp e calculada automaticamente a partir da criatura:
--   1. baseExp   = (xp da criatura no servidor) * killsRequired
--   2. expFinal  = formula por tipo (veja TaskExpFormulas abaixo)
--
-- Campos relevantes:
--   creature      -> nome da criatura no JSON (ex: "Snake")
--   monsterExp    -> xp base da criatura lida via MonsterType:experience()
--   killsRequired -> quantidade de kills da task
--   stage         -> multiplicador de xp do nivel do player (stages.lua)
--
-- Formulas por tipo:
--   tasks / exclusive : expFinal = floor((baseExp * stage) / 5)
--   boss              : expFinal = floor((baseExp * stage) * 1.3)
--
-- Exemplo: Demon (xp=6000), kills=300, stage=8
--   baseExp  = 6000 * 300 = 1.800.000
--   tasks    = floor((1.800.000 * 8) / 5)   = 2.880.000 exp
--   boss     = floor((1.800.000 * 8) * 1.3) = 18.720.000 exp
-- ===========================================================================

-- Retorna o multiplicador de exp do stage para o nivel informado (le experienceStages de stages.lua)
local function getStageMultiplier(level)
    if type(experienceStages) ~= "table" then return 1 end
    for _, stage in ipairs(experienceStages) do
        local minlevel = stage.minlevel or 1
        local maxlevel = stage.maxlevel  -- nil = infinito
        if level >= minlevel and (not maxlevel or level <= maxlevel) then
            return stage.multiplier or 1
        end
    end
    return 1
end

-- ─────────────────────────────────────────────────────────────────────────────
-- FÓRMULAS DE EXP POR TIPO DE TASK
-- baseExp      = valor bruto definido no JSON  (ex: 500)
-- stageMultiplier = multiplicador do stage do player (ex: 8 para lvl 501-600)
-- ─────────────────────────────────────────────────────────────────────────────
local TaskExpFormulas = {
    -- Tasks normais: dividido por 5 para balancear com o ganho continuo de kills
    tasks     = function(baseExp, stageMultiplier) return math.floor((baseExp * stageMultiplier) / 5) end,
    -- Boss: multiplicado por 1.3 pois sao mais dificeis de completar (kills menores, monstros mais fortes)
    boss      = function(baseExp, stageMultiplier) return math.floor((baseExp * stageMultiplier) * 1.3) end,
    -- Exclusive: mesma formula das tasks normais
    exclusive = function(baseExp, stageMultiplier) return math.floor((baseExp * stageMultiplier)  / 5) end,
}

local function calcTaskExp(baseExp, stageMultiplier, taskType)
    local formula = TaskExpFormulas[taskType] or TaskExpFormulas.tasks
    return formula(baseExp, stageMultiplier)
end

-- ===========================================================================
-- LOG DE TASKS CONCLUIDAS
-- Grava em data/scripts/systems/logs/task_completed_log.txt cada task finalizada
-- ===========================================================================
local function logTaskCompleted(playerName, playerLevel, stageMultiplier, taskName, creatureName, monsterUnitExp, taskType, expGained, pointsGained, moneyGained, killsRequired)
    local basePath = "data/scripts/systems/logs/"
    local logPath = basePath .. "task_completed_log.txt"
    local file = io.open(logPath, "a")
    if not file then return end
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    file:write(string.format(
        "[%s] Player: \"%s\" (Lv.%d, Stage: x%.1f) | Task: \"%s\" | Creature: \"%s\" (XP unit: %d) | Kills: %d | Type: %s | Exp ganho: %d | Pontos: %d | Dinheiro: %d gp\n",
        timestamp, playerName, playerLevel, stageMultiplier, taskName, creatureName, monsterUnitExp, killsRequired or 0, taskType, expGained, pointsGained, moneyGained))
    file:close()
end

-- ===========================================================================
-- LOG DE COMPRAS NO SHOP
-- Grava em data/scripts/systems/logs/task_shop_log.txt cada compra realizada no shop
-- ===========================================================================
local function logShopPurchase(playerName, playerLevel, itemName, itemId, pointsSpent, pointsRemaining)
    local basePath = "data/scripts/systems/logs/"
    local logPath = basePath .. "task_shop_log.txt"
    local file = io.open(logPath, "a")
    if not file then return end
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    file:write(string.format(
        "[%s] Player: \"%s\" (Lv.%d) | Item: \"%s\" (ID: %d) | Pontos gastos: %d | Saldo remaining: %d pts\n",
        timestamp, playerName, playerLevel, itemName, itemId, pointsSpent, pointsRemaining))
    file:close()
end

local ElementsTypes = {
	physical = 0,
	fire = 1,
	earth = 2,
	energy = 3,
	ice = 9,
	holy = 10,
	death = 11,
	healing = 7
}

local function parseMonsterElements(mType)
	local elementMap = mType:getElementList() or {}
	local function getElementPercent(typeId)
		local val = elementMap[typeId]
		if not val then return 100 end
		
		-- Converte reducao de dano do servidor para porcentagem de resistencia:
		--   0   = sem reducao (100% neutro)
		--   100 = imune (0% de dano)
		--   negativo = vulneravel (acima de 100% de dano recebido)
		local resistance = 100 - val
		if val < 0 then
			resistance = 100 + math.abs(val)
		end
		
		return resistance
	end
	return {
		physical = getElementPercent(ElementsTypes.physical),
		fire = getElementPercent(ElementsTypes.fire),
		earth = getElementPercent(ElementsTypes.earth),
		energy = getElementPercent(ElementsTypes.energy),
		ice = getElementPercent(ElementsTypes.ice),
		holy = getElementPercent(ElementsTypes.holy),
		death = getElementPercent(ElementsTypes.death),
		healing = getElementPercent(ElementsTypes.healing)
	}
end

TaskSystem = {
    list = {},
    exclusiveList = {},
    bossList = {},
    dailyTasksIds = {},
    dailyTasksDate = "",
    baseStorage = 10000, -- 10001-13000: task normal ativa
    -- =====================================================
    -- Limites de tasks simultaneas por categoria:
    --   exclusiveMaximumTasks = nil  -> sem limite (tasks exclusivas)
    --   Altere os valores abaixo para ajustar facilmente
    -- =====================================================
    maximumTasksNormal = 5,  -- maximo de tasks normais ativas ao mesmo tempo
    maximumTasksBoss   = 5,  -- maximo de tasks boss   ativas ao mesmo tempo
    countForParty = true,
    maxDist = 7,
    players = {},
    loadDatabase = function()
        if (#TaskSystem.list > 0) then
            return true
        end

		-- Carrega as configuracoes dos arquivos JSON
		local basePath = "data/scripts/systems/tasksJson/"
		local configTasks           = loadJsonFile(basePath .. "configTasks.json")
		local configTasksExclusivas = loadJsonFile(basePath .. "configTasksExclusivas.json")
		local configTasksBoss       = loadJsonFile(basePath .. "configTasksBoss.json")
		shopItems                   = loadJsonFile(basePath .. "shopItems.json")

		-- Ordena shop por preco crescente
		table.sort(shopItems, function(a, b) return (a.price or 0) < (b.price or 0) end)

		for i = 1, #configTasks do
			local taskConfig = configTasks[i]
			local creatureName = taskConfig.creature or taskConfig.nameOfTheTask
			local currentLooktype = taskConfig.looktype
			
			if not currentLooktype then
				local mType = MonsterType(creatureName)
				if mType then
					local outfit = mType:outfit()
					currentLooktype = {
						type = outfit.lookType,
						auxType = outfit.lookTypeEx,
						head = outfit.lookHead,
						body = outfit.lookBody,
						legs = outfit.lookLegs,
						feet = outfit.lookFeet,
						addons = outfit.lookAddons,
						mount = outfit.lookMount
					}
				end
			end

			-- Get creature stats
			local maxHealth = 0
			local speed = 0
			local armor = 0
			local monsterExp = 0
			local elements = {}
			local mType = MonsterType(creatureName)
			if mType then
				maxHealth = mType:maxHealth() or 0
				speed = mType:baseSpeed() or 0
				armor = mType:armor() or 0
				monsterExp = mType:experience() or 0
				elements = parseMonsterElements(mType)
			end

			local rewardsList = {}
			if taskConfig.rewards.itemRewards then
				for _, reward in ipairs(taskConfig.rewards.itemRewards) do
					local iType = ItemType(reward.itemId)
					table.insert(rewardsList, {
						itemId = reward.itemId,
						clientId = reward.itemId, -- no Canary o server ID e igual ao client ID
						count = reward.count,
						name = iType and iType:getName() or tostring(reward.itemId)
					})
				end
			end

            table.insert(TaskSystem.list, {
                id = i,
                name = '' ..taskConfig.nameOfTheTask..'',
                creature = creatureName,
                looktype = currentLooktype or { type = 127 }, -- fallback se a criatura nao existir no servidor
                kills = taskConfig.killsRequired,
                -- Exp base = xp da criatura * killsRequired (formula final aplicada no finish via calcTaskExp)
                exp = monsterExp * taskConfig.killsRequired,
				-- dinheiro automatico: (kills * vida maxima da criatura) / 2
				moneyReward = (taskConfig.killsRequired * maxHealth) / 2,
				taskPoints = taskConfig.rewards.pointsReward,
				itemRewards = rewardsList,
                repeatable = taskConfig.repeatable or false,
                suggestedlocation = taskConfig.suggestedlocation or nil,
                maxHealth = maxHealth,
				speed = speed,
				armor = armor,
				monsterExp = monsterExp,
				elements = elements
            })
        end
        -- Load exclusive tasks
        for i = 1, #configTasksExclusivas do
            local taskConfig = configTasksExclusivas[i]
            local creatureName = taskConfig.creature or taskConfig.nameOfTheTask
            local currentLooktype = taskConfig.looktype
            if not currentLooktype then
                local mType = MonsterType(creatureName)
                if mType then
                    local outfit = mType:outfit()
                    currentLooktype = {
                        type = outfit.lookType, auxType = outfit.lookTypeEx,
                        head = outfit.lookHead,   body = outfit.lookBody,
                        legs = outfit.lookLegs,   feet = outfit.lookFeet,
                        addons = outfit.lookAddons, mount = outfit.lookMount
                    }
                end
            end
            
            -- Get creature stats
            local maxHealth = 0
            local speed = 0
            local armor = 0
            local monsterExp = 0
            local elements = {}
            local mType = MonsterType(creatureName)
            if mType then
                maxHealth = mType:maxHealth() or 0
                speed = mType:baseSpeed() or 0
                armor = mType:armor() or 0
                monsterExp = mType:experience() or 0
                elements = parseMonsterElements(mType)
            end
            
            local rewardsList = {}
            if taskConfig.rewards.itemRewards then
                for _, reward in ipairs(taskConfig.rewards.itemRewards) do
                    local iType = ItemType(reward.itemId)
                    table.insert(rewardsList, {
                        itemId = reward.itemId, clientId = reward.itemId,
                        count = reward.count,
                        name = iType and iType:getName() or tostring(reward.itemId)
                    })
                end
            end
            table.insert(TaskSystem.exclusiveList, {
                id = i,
                name = taskConfig.nameOfTheTask,
                creature = creatureName,
                looktype = currentLooktype or { type = 127 },
                kills = taskConfig.killsRequired,
                exp = monsterExp * taskConfig.killsRequired,
                -- moneyReward = 2 * (killsRequired * maxHealth da criatura)
                moneyReward = 2 * (taskConfig.killsRequired * maxHealth),
                taskPoints = taskConfig.rewards.pointsReward,
                itemRewards = rewardsList,
                repeatable = taskConfig.repeatable or false,
                locked = taskConfig.locked or false,
                suggestedlocation = taskConfig.suggestedlocation or nil,
                maxHealth = maxHealth,
                speed = speed,
                armor = armor,
                monsterExp = monsterExp,
                elements = elements
            })
        end
        -- Ordena tasks exclusivas por exp crescente (id/storage nao muda)
        table.sort(TaskSystem.exclusiveList, function(a, b) return (a.monsterExp or 0) < (b.monsterExp or 0) end)
        -- Load boss tasks
        for i = 1, #configTasksBoss do
            local taskConfig = configTasksBoss[i]
            local creatureName = taskConfig.creature or taskConfig.nameOfTheTask
            local currentLooktype = taskConfig.looktype
            if not currentLooktype then
                local mType = MonsterType(creatureName)
                if mType then
                    local outfit = mType:outfit()
                    currentLooktype = {
                        type = outfit.lookType, auxType = outfit.lookTypeEx,
                        head = outfit.lookHead,   body = outfit.lookBody,
                        legs = outfit.lookLegs,   feet = outfit.lookFeet,
                        addons = outfit.lookAddons, mount = outfit.lookMount
                    }
                end
            end
            
            -- Get creature stats
            local maxHealth = 0
            local speed = 0
            local armor = 0
            local monsterExp = 0
            local elements = {}
            local mType = MonsterType(creatureName)
            if mType then
                maxHealth = mType:maxHealth() or 0
                speed = mType:baseSpeed() or 0
                armor = mType:armor() or 0
                monsterExp = mType:experience() or 0
                elements = parseMonsterElements(mType)
            end
            
            local rewardsList = {}
            if taskConfig.rewards.itemRewards then
                for _, reward in ipairs(taskConfig.rewards.itemRewards) do
                    local iType = ItemType(reward.itemId)
                    table.insert(rewardsList, {
                        itemId = reward.itemId, clientId = reward.itemId,
                        count = reward.count,
                        name = iType and iType:getName() or tostring(reward.itemId)
                    })
                end
            end
            table.insert(TaskSystem.bossList, {
                id = i,
                name = taskConfig.nameOfTheTask,
                creature = creatureName,
                looktype = currentLooktype or { type = 127 },
                kills = taskConfig.killsRequired,
                exp = monsterExp * taskConfig.killsRequired,
                -- moneyReward = 2 * (killsRequired * maxHealth da criatura)
                moneyReward = 2 * (taskConfig.killsRequired * maxHealth),
                taskPoints = taskConfig.rewards.pointsReward,
                itemRewards = rewardsList,
                repeatable = taskConfig.repeatable or false,
                suggestedlocation = taskConfig.suggestedlocation or nil,
                maxHealth = maxHealth,
                speed = speed,
                armor = armor,
                monsterExp = monsterExp,
                elements = elements
            })
        end
        -- Ordena tasks boss por exp crescente (id/storage nao muda)
        table.sort(TaskSystem.bossList, function(a, b) return (a.monsterExp or 0) < (b.monsterExp or 0) end)
        logger.info("[vini21 - TaskSystem] ============================================")
        logger.info("[vini21 - TaskSystem] JSONs carregados com sucesso!")
        logger.info("[vini21 - TaskSystem]   Tasks normais:    " .. #TaskSystem.list)
        logger.info("[vini21 - TaskSystem]   Tasks exclusivas: " .. #TaskSystem.exclusiveList)
        logger.info("[vini21 - TaskSystem]   Tasks boss:       " .. #TaskSystem.bossList)
        logger.info("[vini21 - TaskSystem]   Shop items:       " .. #shopItems)
        logger.info("[vini21 - TaskSystem] ============================================")
        
        TaskSystem.generateDailyTasks(false)
        if DAILY_TASKS_ENABLED then
            addEvent(TaskSystem.checkMidnightTasks, 60000)
        end
        
        return true
    end,
    generateDailyTasks = function(forceNew)
        if not DAILY_TASKS_ENABLED then
            -- Modo fixo: sem rotacao, exibe todas as tasks sempre
            TaskSystem.dailyTasksIds = {}
            for _, t in ipairs(TaskSystem.list) do
                table.insert(TaskSystem.dailyTasksIds, t.id)
            end
            TaskSystem.dailyTasksDate = "disabled"
            logger.info("[vini21 - TaskSystem] Daily Tasks aleatorias DESATIVADAS - exibindo todas as " .. #TaskSystem.dailyTasksIds .. " tasks")
            return
        end
        local period = getCurrentDailyPeriod()  -- timestamp do inicio do periodo atual (baseado no server save)
        local periodLabel = os.date("%Y-%m-%d %H:%M", tonumber(period))  -- para logs legiveis
        local basePath = "data/scripts/systems/tasksJson/"
        local dailyPath = basePath .. "dailyTasks.json"
        
        local currentDaily = loadJsonFile(dailyPath)
        if not forceNew and currentDaily and currentDaily.date == period and currentDaily.tasks and #currentDaily.tasks > 0 then
            TaskSystem.dailyTasksDate = currentDaily.date
            TaskSystem.dailyTasksIds = currentDaily.tasks
            
            local creatureNames = {}
            for _, id in ipairs(TaskSystem.dailyTasksIds) do
                local t = TaskSystem.list[id]
                if t then table.insert(creatureNames, t.name) end
            end
            logger.info("[vini21 - TaskSystem] Daily Tasks carregadas para o periodo " .. periodLabel .. ": " .. table.concat(creatureNames, ", "))
            logger.info("[vini21 - TaskSystem] ============================================")
            return
        end
        
        -- Generate new 42 tasks (3 of each point value)
        local tasksByPoints = {}
        for _, task in ipairs(TaskSystem.list) do
            local pts = task.taskPoints or 1
            if not tasksByPoints[pts] then
                tasksByPoints[pts] = {}
            end
            table.insert(tasksByPoints[pts], task.id)
        end
        
        local selectedIds = {}
        local availablePointBins = {}
        for pts, _ in pairs(tasksByPoints) do
            table.insert(availablePointBins, pts)
        end
        table.sort(availablePointBins)
        
        -- Shuffle each bin to ensure randomization
        for _, pts in ipairs(availablePointBins) do
            local bin = tasksByPoints[pts]
            for i = #bin, 2, -1 do
                local j = math.random(i)
                bin[i], bin[j] = bin[j], bin[i]
            end
        end
        
        -- Select exactly 3 tasks from each point value
        for _, pts in ipairs(availablePointBins) do
            local bin = tasksByPoints[pts]
            local tasksToSelect = math.min(3, #bin)
            for i = 1, tasksToSelect do
                if #bin > 0 then
                    table.insert(selectedIds, table.remove(bin))
                end
            end
        end
        
        TaskSystem.dailyTasksDate = period
        TaskSystem.dailyTasksIds = selectedIds
        
        local file = io.open(dailyPath, "w")
        if file then
            file:write(json.encode({ date = period, tasks = selectedIds }))
            file:close()
        end

        local creatureNames = {}
        for _, id in ipairs(TaskSystem.dailyTasksIds) do
            local t = TaskSystem.list[id]
            if t then table.insert(creatureNames, t.name) end
        end
        logger.info("[vini21 - TaskSystem] 42 Daily Tasks geradas para o periodo " .. periodLabel .. ": " .. table.concat(creatureNames, ", "))

        -- For online players: clear outdated tasks right away
        for _, p in ipairs(Game.getPlayers()) do
            TaskSystem.clearOutdatedTasks(p)
        end
    end,
    clearOutdatedTasks = function(player)
        if not TaskSystem.dailyTasksIds or #TaskSystem.dailyTasksIds == 0 then return end
        local activeIds = TaskSystem.getPlayerTaskIds(player)
        
        local isDaily = {}
        for _, id in ipairs(TaskSystem.dailyTasksIds) do
            isDaily[id] = true
        end

        local abortedAny = false
        for _, taskId in ipairs(activeIds) do
            if not isDaily[taskId] then
                -- Leftovers from previous daily
                player:setStorageValue(TaskSystem.baseStorage + taskId, -1)
                abortedAny = true
            end
        end
        
        if abortedAny then
            if TaskSystem.players[player.uid] then
                TaskSystem.sendData(player, { message = "Sua antiga task diaria expirou e foi cancelada.", color = 'red' })
            else
                player:sendExtendedJSONOpcode(190, { message = "Sua antiga task diaria expirou e foi cancelada.", color = 'red' })
                TaskSystem.sendTrackerUpdate(player)
            end
        end
    end,
    checkMidnightTasks = function()
        if not DAILY_TASKS_ENABLED then
            return  -- rotacao de tasks diarias desativada
        end
        local period = getCurrentDailyPeriod()
        if TaskSystem.dailyTasksDate ~= "" and TaskSystem.dailyTasksDate ~= period then
            local periodLabel = os.date("%Y-%m-%d %H:%M", tonumber(period))
            logger.info("[vini21 - TaskSystem] Novo periodo detectado, gerando daily tasks para " .. periodLabel)
            TaskSystem.generateDailyTasks(true)
        end
        addEvent(TaskSystem.checkMidnightTasks, 60000)
    end,
    getCurrentTasks = function(player)
        local tasks = {}

        for _, task in ipairs(TaskSystem.list) do
            local s = player:getStorageValue(TaskSystem.baseStorage + task.id)
            if s >= 0 then
                local playerTask = task
                playerTask.left = s
                playerTask.done = s == 0 and task.kills or (task.kills - s)
                table.insert(tasks, playerTask)
            end
        end

        return tasks
    end,
    getPlayerTaskIds = function(player)
        local tasks = {}

        for _, task in ipairs(TaskSystem.list) do
            if (player:getStorageValue(TaskSystem.baseStorage + task.id) >= 0) then
                table.insert(tasks, task.id)
            end
        end

        return tasks
    end,
    getCompletedIds = function(player)
        local ids = {}
        for _, task in ipairs(TaskSystem.list) do
            if player:getStorageValue(completedBaseStorage + task.id) == 1 then
                table.insert(ids, task.id)
            end
        end
        return ids
    end,
    getPlayerExclusiveTaskIds = function(player)
        local tasks = {}
        for _, task in ipairs(TaskSystem.exclusiveList) do
            if (player:getStorageValue(exclusiveBaseStorage + task.id) >= 0) then
                table.insert(tasks, task.id)
            end
        end
        return tasks
    end,
    getCompletedExclusiveIds = function(player)
        local ids = {}
        for _, task in ipairs(TaskSystem.exclusiveList) do
            if player:getStorageValue(exclusiveCompletedBaseStorage + task.id) == 1 then
                table.insert(ids, task.id)
            end
        end
        return ids
    end,
    getCurrentExclusiveTasks = function(player)
        local tasks = {}
        for _, task in ipairs(TaskSystem.exclusiveList) do
            local s = player:getStorageValue(exclusiveBaseStorage + task.id)
            if s >= 0 then
                local playerTask = task
                playerTask.left = s
                playerTask.done = s == 0 and task.kills or (task.kills - s)
                table.insert(tasks, playerTask)
            end
        end
        return tasks
    end,
    getPlayerBossTaskIds = function(player)
        local tasks = {}
        for _, task in ipairs(TaskSystem.bossList) do
            if (player:getStorageValue(bossBaseStorage + task.id) >= 0) then
                table.insert(tasks, task.id)
            end
        end
        return tasks
    end,
    getCompletedBossIds = function(player)
        local ids = {}
        for _, task in ipairs(TaskSystem.bossList) do
            if player:getStorageValue(bossCompletedBaseStorage + task.id) == 1 then
                table.insert(ids, task.id)
            end
        end
        return ids
    end,
    getCurrentBossTasks = function(player)
        local tasks = {}
        for _, task in ipairs(TaskSystem.bossList) do
            local s = player:getStorageValue(bossBaseStorage + task.id)
            if s >= 0 then
                local playerTask = task
                playerTask.left = s
                playerTask.done = s == 0 and task.kills or (task.kills - s)
                table.insert(tasks, playerTask)
            end
        end
        return tasks
    end,

    getTaskNames = function(player)
        local tasks = {}

        for _, task in ipairs(TaskSystem.list) do
            table.insert(tasks, '{' .. task.name:lower() .. '}')
        end

        return table.concat(tasks, ', ')
    end,
    onAction = function(player, data)
        if (data['action'] == 'tracker') then
            return TaskSystem.sendTrackerUpdate(player)
        elseif (data['action'] == 'info') then
            TaskSystem.players[player.uid] = { tab = 'tasks', taskPage = 1, exPage = 1, shopPage = 1, bossPage = 1, query = '' }
            TaskSystem.sendData(player)
        elseif (data['action'] == 'hide') then
            TaskSystem.players[player.uid] = nil
        elseif (data['action'] == 'page') then
            local tab = data['tab'] or 'tasks'
            local page = math.max(1, tonumber(data['page']) or 1)
            if not TaskSystem.players[player.uid] then
                TaskSystem.players[player.uid] = { tab = 'tasks', taskPage = 1, exPage = 1, shopPage = 1, bossPage = 1, query = '' }
            end
            local state = TaskSystem.players[player.uid]
            state.tab = tab
            -- Nao limpa state.query: preserva a pesquisa ativa ao navegar paginas
            if tab == 'tasks' then state.taskPage = page
            elseif tab == 'exclusive' then state.exPage = page
            elseif tab == 'shop' then state.shopPage = page
            elseif tab == 'boss' then state.bossPage = page
            end
            TaskSystem.sendData(player)
        elseif (data['action'] == 'search') then
            local tab = data['tab'] or 'tasks'
            local query = tostring(data['query'] or '')
            local page = math.max(1, tonumber(data['page']) or 1)
            if not TaskSystem.players[player.uid] then
                TaskSystem.players[player.uid] = { tab = 'tasks', taskPage = 1, exPage = 1, shopPage = 1, bossPage = 1, query = '' }
            end
            local state = TaskSystem.players[player.uid]
            state.tab = tab
            state.query = query
            if tab == 'tasks' then state.taskPage = page
            elseif tab == 'exclusive' then state.exPage = page
            elseif tab == 'shop' then state.shopPage = page
            elseif tab == 'boss' then state.bossPage = page
            end
            TaskSystem.sendData(player)
        elseif (data['action'] == 'start') then
            local playerTaskIds = TaskSystem.getPlayerTaskIds(player)

            if (#playerTaskIds >= TaskSystem.maximumTasksNormal) then
                return player:sendExtendedJSONOpcode(190, {
                    message = "Limite de tasks normais atingido (" .. TaskSystem.maximumTasksNormal .. "/" .. TaskSystem.maximumTasksNormal .. ").",
                    color = 'red'
                })
            end

            for _, task in ipairs(TaskSystem.list) do
                if (task.id == data['entry']) then
                    if (table.contains(playerTaskIds, task.id)) then
                        return player:sendExtendedJSONOpcode(190, {
                            message = 'You already have this task active.',
                            color = 'red'
                        })
                    end



                    -- Block restart if task was already completed and is not repeatable
                    if player:getStorageValue(completedBaseStorage + task.id) == 1 and not task.repeatable then
                        return player:sendExtendedJSONOpcode(190, {
                            message = "This task cannot be repeated.",
                            color = 'red'
                        })
                    end

                    player:setStorageValue(TaskSystem.baseStorage + task.id, task.kills)
                    player:sendExtendedJSONOpcode(190, {
                        message = 'Task started.',
                        color = 'green'
                    })

                    return TaskSystem.sendData(player)
                end
            end

            return player:sendExtendedJSONOpcode(190, {
                message = 'Unknown task.',
                color = 'red'
            })
        elseif (data['action'] == 'cancel') then
            for _, task in ipairs(TaskSystem.list) do
                if (task.id == data['entry']) then
                    local playerTaskIds = TaskSystem.getPlayerTaskIds(player)

                    if (not table.contains(playerTaskIds, task.id)) then
                        return player:sendExtendedJSONOpcode(190, {
                            message = "You don't have this task active.",
                            color = 'red'
                        })
                    end

                    player:setStorageValue(TaskSystem.baseStorage + task.id, -1)
                    player:sendExtendedJSONOpcode(190, {
                        message = 'Task aborted.',
                        color = 'green'
                    })

                    return TaskSystem.sendData(player)
                end
            end

            return player:sendExtendedJSONOpcode(190, {
                message = 'Unknown task.',
                color = 'red'
            })
        elseif (data['action'] == 'finish') then
            for _, task in ipairs(TaskSystem.list) do
                if (task.id == data['entry']) then
                    local playerTaskIds = TaskSystem.getPlayerTaskIds(player)

                    if (not table.contains(playerTaskIds, task.id)) then
                        return player:sendExtendedJSONOpcode(190, {
                            message = "You don't have this task active.",
                            color = 'red'
                        })
                    end

                    local left = player:getStorageValue(TaskSystem.baseStorage + task.id)

                    if (left > 0) then
                        return player:sendExtendedJSONOpcode(190, {
                            message = "Task isn't completed yet.",
                            color = 'red'
                        })
                    end

                    player:setStorageValue(TaskSystem.baseStorage + task.id, -1)
                    player:setStorageValue(completedBaseStorage + task.id, 1)
                    local expGained = calcTaskExp(task.exp, getStageMultiplier(player:getLevel()), 'tasks')
                    player:addExperience(expGained)
                    logTaskCompleted(player:getName(), player:getLevel(), getStageMultiplier(player:getLevel()), task.name, task.creature, task.monsterExp or 0, 'tasks', expGained, task.taskPoints or 0, task.moneyReward or 0, task.kills or 0)

                    if task.moneyReward and task.moneyReward > 0 then
                        player:setBankBalance(player:getBankBalance() + task.moneyReward)
                    end

                    if task.taskPoints then
                        player:setStorageValue(taskPointStorage, (player:getStorageValue(taskPointStorage) + task.taskPoints))
                    end

                    if task.itemRewards then
                        for _, item in ipairs(task.itemRewards) do
                            player:addItem(item.itemId, item.count)
                        end
                    end

                    return TaskSystem.sendData(player, { taskCompleted = true, completedTaskName = task.name, completedTaskId = task.id, completedTaskType = 'normal', taskRepeatable = task.repeatable })
                end
            end

            return player:sendExtendedJSONOpcode(190, {
                message = 'Unknown task.',
                color = 'red'
            })
        elseif (data['action'] == 'shop_buy') then
            for _, s in ipairs(shopItems) do
                if s.itemId == data['itemId'] then
                    local pts = math.max(0, player:getStorageValue(taskPointStorage))
                    if pts < s.price then
                        return player:sendExtendedJSONOpcode(190, {
                            message = "You need " .. s.price .. " pts (you have " .. pts .. ").",
                            color = 'red'
                        })
                    end
                    -- Verificações de posse antes de cobrar os pontos
                    if s.isMountId and player:hasMount(s.itemId) then
                        return player:sendExtendedJSONOpcode(190, { message = "You already own this mount.", color = 'red' })
                    end
                    if s.isOutfit then
                        local looktype = player:getSex() == PLAYERSEX_MALE and s.outfitMale or s.outfitFemale
                        if not looktype then
                            return player:sendExtendedJSONOpcode(190, { message = "Invalid outfit configuration.", color = 'red' })
                        end
                        local addon = s.addon or 0
                        if player:hasOutfit(looktype, addon) then
                            return player:sendExtendedJSONOpcode(190, { message = "You already own this outfit.", color = 'red' })
                        end
                        if addon > 0 and not player:hasOutfit(looktype, 0) then
                            return player:sendExtendedJSONOpcode(190, { message = "You must own the base outfit before buying addons.", color = 'red' })
                        end
                    end

                    -- Verificacao de XP Boost antes de cobrar (evita debito indevido)
                    if s.isXpBoost and player:getXpBoostTime() > 0 then
                        return player:sendExtendedJSONOpcode(190, {
                            message = "Voce ja possui um XP Boost ativo!",
                            color = 'red'
                        })
                    end

                    -- Debita os pontos e executa a compra
                    player:setStorageValue(taskPointStorage, pts - s.price)
                    if s.isMountId then
                        player:addMount(s.itemId)
                    elseif s.isOutfit then
                        local addon = s.addon or 0
                        player:addOutfitAddon(s.outfitMale,   addon)
                        player:addOutfitAddon(s.outfitFemale, addon)
                    elseif s.isXpBoost then
                        player:setXpBoostPercent(50)
                        player:setXpBoostTime(player:getXpBoostTime() + 3600 * (s.count or 1))
                    elseif s.isPreyCard then
                        player:addPreyCards(s.count or 1)
                    else
                        if s.charges then
                            local newItem
                            if s.storeInbox then
                                local inbox = player:getStoreInbox()
                                if not inbox then
                                    player:setStorageValue(taskPointStorage, pts)
                                    return player:sendExtendedJSONOpcode(190, { message = "Could not access your store inbox.", color = 'red' })
                                end
                                newItem = inbox:addItem(s.realItemId or s.itemId, 1)
                            else
                                newItem = player:addItem(s.realItemId or s.itemId, 1)
                            end
                            if newItem then
                                newItem:setAttribute(ITEM_ATTRIBUTE_CHARGES, s.charges)
                            end
                        else
                            player:addItem(s.realItemId or s.itemId, s.count)
                        end
                    end

                    -- Log da compra
                    local newPts = math.max(0, player:getStorageValue(taskPointStorage))
                    logShopPurchase(player:getName(), player:getLevel(), s.name, s.itemId, s.price, newPts)

                    return TaskSystem.sendData(player, { message = "Purchase successful!", color = 'green' })
                end
            end
            return player:sendExtendedJSONOpcode(190, {
                message = "Item not found in shop.",
                color = 'red'
            })
        elseif (data['action'] == 'start_exclusive') then
            local playerExIds = TaskSystem.getPlayerExclusiveTaskIds(player)
            for _, task in ipairs(TaskSystem.exclusiveList) do
                if (task.id == data['entry']) then
                    if task.locked then
                        return player:sendExtendedJSONOpcode(190, { message = "This task is locked.", color = 'red' })
                    end
                    if (table.contains(playerExIds, task.id)) then
                        return player:sendExtendedJSONOpcode(190, { message = 'You already have this task active.', color = 'red' })
                    end
                    if player:getStorageValue(exclusiveCompletedBaseStorage + task.id) == 1 and not task.repeatable then
                        return player:sendExtendedJSONOpcode(190, { message = "This task cannot be repeated.", color = 'red' })
                    end
                    player:setStorageValue(exclusiveBaseStorage + task.id, task.kills)
                    player:sendExtendedJSONOpcode(190, { message = 'Task started.', color = 'green' })
                    return TaskSystem.sendData(player)
                end
            end
            return player:sendExtendedJSONOpcode(190, { message = 'Unknown task.', color = 'red' })
        elseif (data['action'] == 'cancel_exclusive') then
            local playerExIds = TaskSystem.getPlayerExclusiveTaskIds(player)
            for _, task in ipairs(TaskSystem.exclusiveList) do
                if (task.id == data['entry']) then
                    if (not table.contains(playerExIds, task.id)) then
                        return player:sendExtendedJSONOpcode(190, { message = "You don't have this task active.", color = 'red' })
                    end
                    player:setStorageValue(exclusiveBaseStorage + task.id, -1)
                    player:sendExtendedJSONOpcode(190, { message = 'Task aborted.', color = 'green' })
                    return TaskSystem.sendData(player)
                end
            end
            return player:sendExtendedJSONOpcode(190, { message = 'Unknown task.', color = 'red' })
        elseif (data['action'] == 'finish_exclusive') then
            local playerExIds = TaskSystem.getPlayerExclusiveTaskIds(player)
            for _, task in ipairs(TaskSystem.exclusiveList) do
                if (task.id == data['entry']) then
                    if (not table.contains(playerExIds, task.id)) then
                        return player:sendExtendedJSONOpcode(190, { message = "You don't have this task active.", color = 'red' })
                    end
                    local left = player:getStorageValue(exclusiveBaseStorage + task.id)
                    if (left > 0) then
                        return player:sendExtendedJSONOpcode(190, { message = "Task isn't completed yet.", color = 'red' })
                    end
                    player:setStorageValue(exclusiveBaseStorage + task.id, -1)
                    player:setStorageValue(exclusiveCompletedBaseStorage + task.id, 1)
                    local expGained = calcTaskExp(task.exp, getStageMultiplier(player:getLevel()), 'exclusive')
                    player:addExperience(expGained)
                    logTaskCompleted(player:getName(), player:getLevel(), getStageMultiplier(player:getLevel()), task.name, task.creature, task.monsterExp or 0, 'exclusive', expGained, task.taskPoints or 0, task.moneyReward or 0, task.kills or 0)
                    if task.moneyReward and task.moneyReward > 0 then
                        player:setBankBalance(player:getBankBalance() + task.moneyReward)
                    end
                    if task.taskPoints then
                        player:setStorageValue(taskPointStorage, (player:getStorageValue(taskPointStorage) + task.taskPoints))
                    end
                    if task.itemRewards then
                        for _, item in ipairs(task.itemRewards) do
                            player:addItem(item.itemId, item.count)
                        end
                    end
                    return TaskSystem.sendData(player, { taskCompleted = true, completedTaskName = task.name, completedTaskId = task.id, completedTaskType = 'exclusive', taskRepeatable = task.repeatable })
                end
            end
            return player:sendExtendedJSONOpcode(190, { message = 'Unknown task.', color = 'red' })
        elseif (data['action'] == 'start_boss') then
            local playerBossIds = TaskSystem.getPlayerBossTaskIds(player)

            if (#playerBossIds >= TaskSystem.maximumTasksBoss) then
                return player:sendExtendedJSONOpcode(190, {
                    message = "Limite de tasks boss atingido (" .. TaskSystem.maximumTasksBoss .. "/" .. TaskSystem.maximumTasksBoss .. ").",
                    color = 'red'
                })
            end

            for _, task in ipairs(TaskSystem.bossList) do
                if (task.id == data['entry']) then
                    if (table.contains(playerBossIds, task.id)) then
                        return player:sendExtendedJSONOpcode(190, { message = 'You already have this task active.', color = 'red' })
                    end
                    if player:getStorageValue(bossCompletedBaseStorage + task.id) == 1 and not task.repeatable then
                        return player:sendExtendedJSONOpcode(190, { message = "This task cannot be repeated.", color = 'red' })
                    end
                    player:setStorageValue(bossBaseStorage + task.id, task.kills)
                    player:sendExtendedJSONOpcode(190, { message = 'Task started.', color = 'green' })
                    return TaskSystem.sendData(player)
                end
            end
            return player:sendExtendedJSONOpcode(190, { message = 'Unknown task.', color = 'red' })
        elseif (data['action'] == 'cancel_boss') then
            local playerBossIds = TaskSystem.getPlayerBossTaskIds(player)
            for _, task in ipairs(TaskSystem.bossList) do
                if (task.id == data['entry']) then
                    if (not table.contains(playerBossIds, task.id)) then
                        return player:sendExtendedJSONOpcode(190, { message = "You don't have this task active.", color = 'red' })
                    end
                    player:setStorageValue(bossBaseStorage + task.id, -1)
                    player:sendExtendedJSONOpcode(190, { message = 'Task aborted.', color = 'green' })
                    return TaskSystem.sendData(player)
                end
            end
            return player:sendExtendedJSONOpcode(190, { message = 'Unknown task.', color = 'red' })
        elseif (data['action'] == 'finish_boss') then
            local playerBossIds = TaskSystem.getPlayerBossTaskIds(player)
            for _, task in ipairs(TaskSystem.bossList) do
                if (task.id == data['entry']) then
                    if (not table.contains(playerBossIds, task.id)) then
                        return player:sendExtendedJSONOpcode(190, { message = "You don't have this task active.", color = 'red' })
                    end
                    local left = player:getStorageValue(bossBaseStorage + task.id)
                    if (left > 0) then
                        return player:sendExtendedJSONOpcode(190, { message = "Task isn't completed yet.", color = 'red' })
                    end
                    player:setStorageValue(bossBaseStorage + task.id, -1)
                    player:setStorageValue(bossCompletedBaseStorage + task.id, 1)
                    local expGained = calcTaskExp(task.exp, getStageMultiplier(player:getLevel()), 'boss')
                    player:addExperience(expGained)
                    logTaskCompleted(player:getName(), player:getLevel(), getStageMultiplier(player:getLevel()), task.name, task.creature, task.monsterExp or 0, 'boss', expGained, task.taskPoints or 0, task.moneyReward or 0, task.kills or 0)
                    if task.moneyReward and task.moneyReward > 0 then
                        player:setBankBalance(player:getBankBalance() + task.moneyReward)
                    end
                    if task.taskPoints then
                        player:setStorageValue(taskPointStorage, (player:getStorageValue(taskPointStorage) + task.taskPoints))
                    end
                    if task.itemRewards then
                        for _, item in ipairs(task.itemRewards) do
                            player:addItem(item.itemId, item.count)
                        end
                    end
                    return TaskSystem.sendData(player, { taskCompleted = true, completedTaskName = task.name, completedTaskId = task.id, completedTaskType = 'boss', taskRepeatable = task.repeatable })
                end
            end
            return player:sendExtendedJSONOpcode(190, { message = 'Unknown task.', color = 'red' })
        elseif (data['action'] == 'admin_reset') then
            -- Reseta todo o progresso de tasks (apenas para debug/admin)
            for _, task in ipairs(TaskSystem.list) do
                player:setStorageValue(TaskSystem.baseStorage + task.id, -1)
                player:setStorageValue(completedBaseStorage + task.id, -1)
            end
            for _, task in ipairs(TaskSystem.exclusiveList) do
                player:setStorageValue(exclusiveBaseStorage + task.id, -1)
                player:setStorageValue(exclusiveCompletedBaseStorage + task.id, -1)
            end
            for _, task in ipairs(TaskSystem.bossList) do
                player:setStorageValue(bossBaseStorage + task.id, -1)
                player:setStorageValue(bossCompletedBaseStorage + task.id, -1)
            end
            player:setStorageValue(taskPointStorage, 0)
            if TaskSystem.players[player.uid] then
                TaskSystem.players[player.uid] = { tab = 'tasks', taskPage = 1, exPage = 1, shopPage = 1, bossPage = 1, query = '' }
            end
            return TaskSystem.sendData(player, { message = "Progresso resetado com sucesso!", color = 'green' })
        end
    end,
    -- Envia snapshot compacto das tasks ativas para o Task Tracker do cliente
    sendTrackerUpdate = function(player)
        local allActive = {}
        for _, t in ipairs(TaskSystem.getCurrentTasks(player)) do
            table.insert(allActive, { name = t.name, creature = t.creature, done = t.done, kills = t.kills, type = 'normal' })
        end
        for _, t in ipairs(TaskSystem.getCurrentExclusiveTasks(player)) do
            table.insert(allActive, { name = t.name, creature = t.creature, done = t.done, kills = t.kills, type = 'exclusive' })
        end
        for _, t in ipairs(TaskSystem.getCurrentBossTasks(player)) do
            table.insert(allActive, { name = t.name, creature = t.creature, done = t.done, kills = t.kills, type = 'boss' })
        end
        player:sendExtendedJSONOpcode(194, { activeTasks = allActive })
    end,
    killForPlayerExclusive = function(player, task)
        local left = player:getStorageValue(exclusiveBaseStorage + task.id)
        if (left == 0) then
            return true  -- ja notificado, aguardando finish
        end
        if (left == 1) then
            player:setStorageValue(exclusiveBaseStorage + task.id, 0)  -- marca como pronto
            if (TaskSystem.players[player.uid]) then
                TaskSystem.sendData(player, { taskReadyToFinish = true, readyTaskName = task.name })
            else
                player:sendExtendedJSONOpcode(190, { taskReadyToFinish = true, readyTaskName = task.name })
                TaskSystem.sendTrackerUpdate(player)
            end
            return true
        end
        player:setStorageValue(exclusiveBaseStorage + task.id, left - 1)
        if (TaskSystem.players[player.uid]) then
            return TaskSystem.sendData(player)
        else
            TaskSystem.sendTrackerUpdate(player)
        end
    end,
    killForPlayerBoss = function(player, task)
        local left = player:getStorageValue(bossBaseStorage + task.id)
        if (left == 0) then
            return true  -- ja notificado, aguardando finish
        end
        if (left == 1) then
            player:setStorageValue(bossBaseStorage + task.id, 0)  -- marca como pronto
            if (TaskSystem.players[player.uid]) then
                TaskSystem.sendData(player, { taskReadyToFinish = true, readyTaskName = task.name })
            else
                player:sendExtendedJSONOpcode(190, { taskReadyToFinish = true, readyTaskName = task.name })
                TaskSystem.sendTrackerUpdate(player)
            end
            return true
        end
        player:setStorageValue(bossBaseStorage + task.id, left - 1)
        if (TaskSystem.players[player.uid]) then
            return TaskSystem.sendData(player)
        else
            TaskSystem.sendTrackerUpdate(player)
        end
    end,
    killForPlayer = function(player, task)
        local left = player:getStorageValue(TaskSystem.baseStorage + task.id)

        if (left == 0) then
            return true  -- ja notificado, aguardando finish
        end

        if (left == 1) then
            player:setStorageValue(TaskSystem.baseStorage + task.id, 0)  -- marca como pronto
            if (TaskSystem.players[player.uid]) then
                TaskSystem.sendData(player, { taskReadyToFinish = true, readyTaskName = task.name })
            else
                player:sendExtendedJSONOpcode(190, { taskReadyToFinish = true, readyTaskName = task.name })
                TaskSystem.sendTrackerUpdate(player)
            end
            return true
        end

        player:setStorageValue(TaskSystem.baseStorage + task.id, left - 1)

        if (TaskSystem.players[player.uid]) then
            return TaskSystem.sendData(player)
        else
            TaskSystem.sendTrackerUpdate(player)
        end
    end,
    onKill = function(player, target)
        local targetName = target:getName():lower()
        local party = player:getParty()
        local tpos = target:getPosition()

        -- Helper: aplica o kill para o jogador ou para o grupo
        local function applyKill(killFunc, task)
            if TaskSystem.countForParty and party and party:getMembers() then
                for _, creature in pairs(party:getMembers()) do
                    local pos = creature:getPosition()
                    if pos.z == tpos.z and pos:getDistance(tpos) <= TaskSystem.maxDist then
                        killFunc(creature, task)
                    end
                end
                local leaderPos = party:getLeader():getPosition()
                if leaderPos.z == tpos.z and leaderPos:getDistance(tpos) <= TaskSystem.maxDist then
                    killFunc(party:getLeader(), task)
                end
            else
                killFunc(player, task)
            end
        end

        -- Tasks normais: percorre TODAS as tasks com a mesma criatura
        local playerTaskIds = TaskSystem.getPlayerTaskIds(player)
        for _, task in ipairs(TaskSystem.list) do
            if task.creature:lower() == targetName and table.contains(playerTaskIds, task.id) then
                applyKill(TaskSystem.killForPlayer, task)
            end
        end

        -- Tasks exclusivas: percorre TODAS as tasks exclusivas com a mesma criatura
        local playerExIds = TaskSystem.getPlayerExclusiveTaskIds(player)
        for _, task in ipairs(TaskSystem.exclusiveList) do
            if task.creature:lower() == targetName and table.contains(playerExIds, task.id) then
                applyKill(TaskSystem.killForPlayerExclusive, task)
            end
        end

        -- Tasks boss: percorre TODAS as tasks boss com a mesma criatura
        local playerBossIds = TaskSystem.getPlayerBossTaskIds(player)
        for _, task in ipairs(TaskSystem.bossList) do
            if task.creature:lower() == targetName and table.contains(playerBossIds, task.id) then
                applyKill(TaskSystem.killForPlayerBoss, task)
            end
        end

        return true
    end,
    sendData = function(player, extra)
        local PAGE_SIZE = 8

        -- Lê o estado atual do jogador (aba/página/busca)
        local state = TaskSystem.players[player.uid]
        local tab      = state and state.tab      or 'tasks'
        local taskPage = state and state.taskPage or 1
        local exPage   = state and state.exPage   or 1
        local shopPage = state and state.shopPage or 1
        local bossPage = state and state.bossPage or 1
        local query    = state and state.query    or ''

        -- Auto-cancela tasks exclusivas bloqueadas que o jogador tinha ativas
        local lockedResets = {}
        for _, task in ipairs(TaskSystem.exclusiveList) do
            if task.locked and player:getStorageValue(exclusiveBaseStorage + task.id) >= 0 then
                player:setStorageValue(exclusiveBaseStorage + task.id, -1)
                table.insert(lockedResets, task.name)
            end
        end

        local points = math.max(0, player:getStorageValue(taskPointStorage))
        local response = { points = points }

        -- Stage multiplier do player: usado para calcular exp exibida no cliente
        local playerStage = getStageMultiplier(player:getLevel())

        -- Cria cópias de tarefas ativas com exp/monsterExp ajustados pelo stage do player
        -- (getCurrentTasks retorna referências diretas; sem isso o cliente exibiria o valor base)
        local function adjustPlayerTasks(rawList, taskType)
            local out = {}
            for _, t in ipairs(rawList) do
                table.insert(out, {
                    id = t.id, name = t.name, creature = t.creature, looktype = t.looktype,
                    kills = t.kills, exp = calcTaskExp(t.exp, playerStage, taskType),
                    moneyReward = t.moneyReward, taskPoints = t.taskPoints,
                    itemRewards = t.itemRewards, repeatable = t.repeatable,
                    suggestedlocation = t.suggestedlocation, maxHealth = t.maxHealth,
                    speed = t.speed, armor = t.armor,
                    monsterExp = t.monsterExp and math.floor(t.monsterExp * playerStage) or 0,
                    elements = t.elements, locked = t.locked,
                    left = t.left, done = t.done
                })
            end
            return out
        end

        -- Contadores totais de cada aba (enviado em toda resposta para atualizar todos os labels)
        local activeIdsForCount = TaskSystem.getPlayerTaskIds(player)
        local allowedTasksCount = 0
        local allowedMapForCount = {}
        for _, id in ipairs(TaskSystem.dailyTasksIds) do
            if not allowedMapForCount[id] then
                allowedMapForCount[id] = true
                allowedTasksCount = allowedTasksCount + 1
            end
        end
        for _, id in ipairs(activeIdsForCount) do
            if not allowedMapForCount[id] then
                allowedMapForCount[id] = true
                allowedTasksCount = allowedTasksCount + 1
            end
        end

        response.tabCounts = {
            tasks     = allowedTasksCount,
            exclusive = #TaskSystem.exclusiveList,
            boss      = #TaskSystem.bossList,
            shop      = #shopItems,
        }

        -- Mensagem de reset por lock
        if #lockedResets > 0 then
            response.message = "Task(s) bloqueada(s) e resetada(s): " .. table.concat(lockedResets, ", ")
            response.color = 'red'
        end

        -- Injeta campos extras (ex: taskCompleted, message de ação, etc.)
        if extra then
            for k, v in pairs(extra) do
                response[k] = v
            end
        end

        -- ── ABA: TASKS ────────────────────────────────────────────────────────
        if tab == 'tasks' then
            local lowerQuery = query:lower()
            local taskList = {}
            for _, task in ipairs(TaskSystem.list) do
                if allowedMapForCount[task.id] then
                    if lowerQuery == '' or task.name:lower():find(lowerQuery, 1, true) or task.creature:lower():find(lowerQuery, 1, true) then
                        table.insert(taskList, task)
                    end
                end
            end

            local total = #taskList
            local totalTaskPages = math.max(1, math.ceil(total / PAGE_SIZE))
            if taskPage > totalTaskPages then taskPage = totalTaskPages end
            if state then state.taskPage = taskPage end

            local startIdx = (taskPage - 1) * PAGE_SIZE + 1
            local endIdx   = math.min(taskPage * PAGE_SIZE, total)
            local pageSlice = {}
            for i = startIdx, endIdx do
                local t = taskList[i]
                -- Ajusta o XP do monstro pelo stage do player para exibir o valor correto no cliente
                local adjustedMonsterExp = 0
                if t.monsterExp and t.monsterExp > 0 then
                    adjustedMonsterExp = math.floor(t.monsterExp * playerStage)
                end
                table.insert(pageSlice, {
                    id = t.id, name = t.name, creature = t.creature, looktype = t.looktype,
                    kills = t.kills, exp = calcTaskExp(t.exp, playerStage, 'tasks'),
                    moneyReward = t.moneyReward, taskPoints = t.taskPoints,
                    itemRewards = t.itemRewards, repeatable = t.repeatable,
                    suggestedlocation = t.suggestedlocation, maxHealth = t.maxHealth,
                    speed = t.speed, armor = t.armor, monsterExp = adjustedMonsterExp, elements = t.elements
                })
            end

            response.tab            = 'tasks'
            response.page           = taskPage
            response.totalPages     = totalTaskPages
            response.totalItems     = total
            response.allTasks       = pageSlice
            response.playerTasks    = adjustPlayerTasks(TaskSystem.getCurrentTasks(player), 'tasks')
            response.completedIds   = TaskSystem.getCompletedIds(player)

        -- ── ABA: EXCLUSIVE ────────────────────────────────────────────────────
        elseif tab == 'exclusive' then
            local lowerQuery = query:lower()
            local exList = TaskSystem.exclusiveList
            if lowerQuery ~= '' then
                local filtered = {}
                for _, task in ipairs(TaskSystem.exclusiveList) do
                    if task.name:lower():find(lowerQuery, 1, true) or task.creature:lower():find(lowerQuery, 1, true) then
                        table.insert(filtered, task)
                    end
                end
                exList = filtered
            end

            local total = #exList
            local totalExPages = math.max(1, math.ceil(total / PAGE_SIZE))
            if exPage > totalExPages then exPage = totalExPages end
            if state then state.exPage = exPage end

            local startIdx = (exPage - 1) * PAGE_SIZE + 1
            local endIdx   = math.min(exPage * PAGE_SIZE, total)
            local pageSlice = {}
            for i = startIdx, endIdx do
                local t = exList[i]
                -- Ajusta o XP do monstro pelo stage do player para exibir o valor correto no cliente
                local adjustedMonsterExp = 0
                if t.monsterExp and t.monsterExp > 0 then
                    adjustedMonsterExp = math.floor(t.monsterExp * playerStage)
                end
                table.insert(pageSlice, {
                    id = t.id, name = t.name, creature = t.creature, looktype = t.looktype,
                    kills = t.kills, exp = calcTaskExp(t.exp, playerStage, 'exclusive'),
                    moneyReward = t.moneyReward, taskPoints = t.taskPoints,
                    itemRewards = t.itemRewards, repeatable = t.repeatable,
                    locked = t.locked,
                    suggestedlocation = t.suggestedlocation, maxHealth = t.maxHealth,
                    speed = t.speed, armor = t.armor, monsterExp = adjustedMonsterExp, elements = t.elements
                })
            end

            response.tab                   = 'exclusive'
            response.page                  = exPage
            response.totalPages            = totalExPages
            response.totalItems            = total
            response.exclusiveTasks        = pageSlice
            response.playerExclusiveTasks  = adjustPlayerTasks(TaskSystem.getCurrentExclusiveTasks(player), 'exclusive')
            response.completedExclusiveIds = TaskSystem.getCompletedExclusiveIds(player)

        -- ── ABA: SHOP ─────────────────────────────────────────────────────────
        elseif tab == 'shop' then
            local lowerQuery = query:lower()
            local shopList = {}
            for _, s in ipairs(shopItems) do
                local itemName = s.name
                if not itemName then
                    if not s.isMountId and not s.isOutfit and not s.isXpBoost and not s.isPreyCard then
                        local iType = ItemType(s.itemId)
                        itemName = iType and iType:getName() or tostring(s.itemId)
                    else
                        itemName = tostring(s.itemId)
                    end
                end
                if lowerQuery == '' or (itemName and itemName:lower():find(lowerQuery, 1, true)) then
                    -- Calcula owned de acordo com o tipo
                    local ownedFlag = false
                    if s.isMountId then
                        ownedFlag = player:hasMount(s.itemId)
                    elseif s.isOutfit then
                        local looktype = player:getSex() == PLAYERSEX_MALE and s.outfitMale or s.outfitFemale
                        if looktype then ownedFlag = player:hasOutfit(looktype, s.addon or 0) end
                    elseif s.isXpBoost then
                        ownedFlag = player:getXpBoostTime() > 0
                    end
                    table.insert(shopList, {
                        itemId       = s.itemId,
                        clientId     = s.clientId or s.itemId,
                        count        = s.count or 1,
                        charges      = s.charges,
                        price        = s.price,
                        name         = itemName,
                        isMountId    = s.isMountId   or false,
                        isOutfit     = s.isOutfit    or false,
                        outfitMale   = s.outfitMale,
                        outfitFemale = s.outfitFemale,
                        addon        = s.addon or 0,
                        isXpBoost    = s.isXpBoost   or false,
                        isPreyCard   = s.isPreyCard  or false,
                        storeInbox   = s.storeInbox  or false,
                        owned        = ownedFlag
                    })
                end
            end

            local total = #shopList
            local totalShopPages = math.max(1, math.ceil(total / PAGE_SIZE))
            if shopPage > totalShopPages then shopPage = totalShopPages end
            if state then state.shopPage = shopPage end

            local startIdx = (shopPage - 1) * PAGE_SIZE + 1
            local endIdx   = math.min(shopPage * PAGE_SIZE, total)
            local pageSlice = {}
            for i = startIdx, endIdx do
                table.insert(pageSlice, shopList[i])
            end

            response.tab        = 'shop'
            response.page       = shopPage
            response.totalPages = totalShopPages
            response.totalItems = total
            response.shopItems  = pageSlice

        -- ── ABA: BOSS ────────────────────────────────────────────────────────
        elseif tab == 'boss' then
            local lowerQuery = query:lower()
            local bossList = TaskSystem.bossList
            if lowerQuery ~= '' then
                local filtered = {}
                for _, task in ipairs(TaskSystem.bossList) do
                    if task.name:lower():find(lowerQuery, 1, true) or task.creature:lower():find(lowerQuery, 1, true) then
                        table.insert(filtered, task)
                    end
                end
                bossList = filtered
            end
            local total = #bossList
            local totalBossPages = math.max(1, math.ceil(total / PAGE_SIZE))
            if bossPage > totalBossPages then bossPage = totalBossPages end
            if state then state.bossPage = bossPage end

            local startIdx = (bossPage - 1) * PAGE_SIZE + 1
            local endIdx   = math.min(bossPage * PAGE_SIZE, total)
            local pageSlice = {}
            for i = startIdx, endIdx do
                local t = bossList[i]
                -- Ajusta o XP do monstro pelo stage do player para exibir o valor correto no cliente
                local adjustedMonsterExp = 0
                if t.monsterExp and t.monsterExp > 0 then
                    adjustedMonsterExp = math.floor(t.monsterExp * playerStage)
                end
                table.insert(pageSlice, {
                    id = t.id, name = t.name, creature = t.creature, looktype = t.looktype,
                    kills = t.kills, exp = calcTaskExp(t.exp, playerStage, 'boss'),
                    moneyReward = t.moneyReward, taskPoints = t.taskPoints,
                    itemRewards = t.itemRewards, repeatable = t.repeatable,
                    suggestedlocation = t.suggestedlocation, maxHealth = t.maxHealth,
                    speed = t.speed, armor = t.armor, monsterExp = adjustedMonsterExp, elements = t.elements
                })
            end
            response.tab              = 'boss'
            response.page             = bossPage
            response.totalPages       = totalBossPages
            response.totalItems       = total
            response.bossTasks        = pageSlice
            response.playerBossTasks  = adjustPlayerTasks(TaskSystem.getCurrentBossTasks(player), 'boss')
            response.completedBossIds = TaskSystem.getCompletedBossIds(player)
        end

        player:sendExtendedJSONOpcode(190, response)
        TaskSystem.sendTrackerUpdate(player)
    end
}

local events = {}

local globalevent = GlobalEvent('Tasks')


function globalevent.onStartup()
    return TaskSystem.loadDatabase()
end

table.insert(events, globalevent)

local DeathEvent = CreatureEvent("TaskSystemDeath")

function DeathEvent.onDeath(creature, corpse, killer, mostDamageKiller, lastHitUnjustified, mostDamageUnjustified)
	if not creature or creature:isPlayer() or creature:getMaster() then
		return true
	end

	local player = nil
	if killer then
		if killer:isPlayer() then
			player = killer
		elseif killer:getMaster() and killer:getMaster():isPlayer() then
			player = killer:getMaster()
		end
	end

	if not player and mostDamageKiller then
		if mostDamageKiller:isPlayer() then
			player = mostDamageKiller
		elseif mostDamageKiller:getMaster() and mostDamageKiller:getMaster():isPlayer() then
			player = mostDamageKiller:getMaster()
		end
	end

	if player then
		TaskSystem.onKill(player, creature)
	end
	return true
end

for _, event in ipairs(events) do
    event:register()
end

local ExtendedEvent = CreatureEvent("TaskExtended")

function ExtendedEvent.onExtendedOpcode(player, opcode, buffer)
    if opcode == 190 then
		TaskSystem.onAction(player, json.decode(buffer))
	elseif opcode == 194 then
		TaskSystem.sendTrackerUpdate(player)
	end
end

local LoginEvent = CreatureEvent("TaskLogin")

function LoginEvent.onLogin(player)
  player:registerEvent("TaskExtended")
  player:registerEvent("TaskSystemDeath")
  
  -- Clear OUTDATED tasks from previous daily
  TaskSystem.clearOutdatedTasks(player)
  
  return true
end


LoginEvent:type("login")
LoginEvent:register()
ExtendedEvent:type("extendedopcode")
ExtendedEvent:register()
DeathEvent:type("death")
DeathEvent:register()
