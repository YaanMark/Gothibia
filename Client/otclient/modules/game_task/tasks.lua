local window = nil
local selectedEntry = nil
local consoleEvent = nil
local taskButton
local tasksData = {}
local currentTab = 'tasks'
local shopData = {}
local completedIds = {}
local exclusiveData = {}
local selectedEntryType = 'normal'
local imagesPath = '/modules/game_task/images'
local currentPage   = { tasks = 1, exclusive = 1, shop = 1, boss = 1 }
local totalPages    = { tasks = 1, exclusive = 1, shop = 1, boss = 1 }
local searchDebounce = nil
local adminMode          = true   -- true = botão Reset visível (apenas debug)
local activeFilter       = false  -- true = mostra somente tasks ativas
local activeFilterPage   = { tasks = 1, exclusive = 1, shop = 1, boss = 1 }
local activeFilterTotalPages = { tasks = 1, exclusive = 1, shop = 1, boss = 1 }
local PAGE_SIZE = 8

local function formatNumber(amount)
    if not amount then return "0" end
    local formatted = tostring(amount)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
        if (k == 0) then break end
    end
    return formatted
end

function init()
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = destroy
    })

    window = g_ui.displayUI('tasks')
    window:setVisible(false)
    
    

    Keybind.new('Windows', 'show/hide Tasks Windows', 'Ctrl+A', '')
    Keybind.bind('Windows', 'show/hide Tasks Windows', {
      {
        type = KEY_DOWN,
        callback = toggleWindow,
       }
    })

    g_keyboard.bindKeyDown('Escape', hideWindowzz)
	taskButton = modules.game_mainpanel.addToggleButton('taskButton', tr('Tasks'), imagesPath .. '/taskIcon', toggleWindow, false, 2)
    ProtocolGame.registerExtendedJSONOpcode(190, parseOpcode)
end

function terminate()
    disconnect(g_game, {
        onGameEnd = destroy
    })
    ProtocolGame.unregisterExtendedJSONOpcode(190, parseOpcode)
    taskButton:destroy()
    destroy()
    Keybind.delete('Windows', 'show/hide Tasks Windows')
end

function onGameStart()
    if (window) then
        window:destroy()
        window = nil
    end

    window = g_ui.displayUI('tasks')
    window:setVisible(false)
    window.search.onTextChange = onFilterSearch
end

function destroy()
    if (window) then
        window:destroy()
        window = nil
    end
end

function parseOpcode(protocol, opcode, data)
    updateTasks(data)
end

-- Retorna todas as tasks ativas para outros modulos (ex: game_task_tracker)
function getActiveTasks()
    local result = {}
    for _, t in ipairs(tasksData.playerTasks or {}) do
        table.insert(result, { name = t.name, creature = t.creature, done = t.done, kills = t.kills, type = 'normal' })
    end
    for _, t in ipairs(tasksData.playerExclusiveTasks or {}) do
        table.insert(result, { name = t.name, creature = t.creature, done = t.done, kills = t.kills, type = 'exclusive' })
    end
    for _, t in ipairs(tasksData.playerBossTasks or {}) do
        table.insert(result, { name = t.name, creature = t.creature, done = t.done, kills = t.kills, type = 'boss' })
    end
    return result
end

function sendOpcode(data)
    local protocolGame = g_game.getProtocolGame()

    if protocolGame then
        protocolGame:sendExtendedJSONOpcode(190, data)
    end
end

function onItemSelect(list, focusedChild, unfocusedChild, reason)
    if focusedChild then
        selectedEntryType = 'normal'
        selectedEntry = tonumber(focusedChild:getId())

        if (not selectedEntry) then
            return true
        end

        window.wikiButton:show()
        window.finishButton:hide()
        window.startButton:hide()
        window.abortButton:hide()

        -- Mapa de tasks ativas: verifica se a task está em execução
        local activeMap = {}
        for _, task in ipairs(tasksData.playerTasks or {}) do
            activeMap[task.id] = task
        end

        -- Se a task está em execução, mostra botões de ação
        if activeMap[selectedEntry] then
            local activeTask = activeMap[selectedEntry]
            local kills = tostring(activeTask.done) .. " / " .. tostring(activeTask.kills)
            
            -- Se progresso == 100%, mostrar Finish; se tem progresso, mostrar Abort
            if activeTask.done >= activeTask.kills then
                window.finishButton:show()
            else
                window.abortButton:show()
            end
            return true
        end

        -- Already completed: only block if task is not repeatable
        if table.contains(completedIds, selectedEntry) then
            local isRepeatable = false
            if tasksData.allTasks then
                for _, t in ipairs(tasksData.allTasks) do
                    if t.id == selectedEntry then
                        isRepeatable = t.repeatable or false
                        break
                    end
                end
            end
            if not isRepeatable then
                setTaskConsoleText("Task already completed!", "#888888")
                return true
            end
        end

        local children = window.selectionList:getChildren()

        for _, child in ipairs(children) do
            local id = tonumber(child:getId())

            if (selectedEntry == id) then
                local kills = child.kills:getText()

                if (child.progress:getWidth() == 159) then
                    window.finishButton:show()
                elseif (kills:find('/')) then
                    window.abortButton:show()
                else
                    window.startButton:show()
                end
            end
        end
    end
end

function onExclusiveItemSelect(list, focusedChild, unfocusedChild, reason)
    if focusedChild then
        selectedEntryType = 'exclusive'
        local rawId = focusedChild:getId()
        selectedEntry = tonumber(rawId:match('^ex_(%d+)$'))

        if (not selectedEntry) then
            return true
        end

        window.wikiButton:show()
        window.finishButton:hide()
        window.startButton:hide()
        window.abortButton:hide()

        -- Mapa de tasks exclusivas ativas
        local activeExMap = {}
        for _, task in ipairs(tasksData.playerExclusiveTasks or {}) do
            activeExMap[task.id] = task
        end

        -- Se a task está em execução, mostra botões de ação
        if activeExMap[selectedEntry] then
            local activeTask = activeExMap[selectedEntry]
            
            -- Se progresso == 100%, mostrar Finish; se tem progresso, mostrar Abort
            if activeTask.done >= activeTask.kills then
                window.finishButton:show()
            else
                window.abortButton:show()
            end
            return true
        end

        local exCompletedIds = tasksData['completedExclusiveIds'] or {}
        local isLocked = false
        local isRepeatable = false

        if tasksData['exclusiveTasks'] then
            for _, t in ipairs(tasksData['exclusiveTasks']) do
                if t.id == selectedEntry then
                    isLocked = t.locked or false
                    isRepeatable = t.repeatable or false
                    break
                end
            end
        end

        if isLocked then
            setTaskConsoleText("This task is locked.", "red")
            return true
        end

        if table.contains(exCompletedIds, selectedEntry) and not isRepeatable then
            setTaskConsoleText("Task already completed!", "#888888")
            return true
        end

        local children = window.exclusivePanel:getChildren()
        for _, child in ipairs(children) do
            local childId = tonumber(child:getId():match('^ex_(%d+)$'))
            if (selectedEntry == childId) then
                local kills = child.kills:getText()
                if (child.progress:getWidth() == 159) then
                    window.finishButton:show()
                elseif (kills:find('/')) then
                    window.abortButton:show()
                else
                    window.startButton:show()
                end
            end
        end
    end
end

function onBossItemSelect(list, focusedChild, unfocusedChild, reason)
    if focusedChild then
        selectedEntryType = 'boss'
        local rawId = focusedChild:getId()
        selectedEntry = tonumber(rawId:match('^boss_(%d+)$'))

        if (not selectedEntry) then
            return true
        end

        window.wikiButton:show()
        window.finishButton:hide()
        window.startButton:hide()
        window.abortButton:hide()

        -- Mapa de tasks boss ativas
        local activeBossMap = {}
        for _, task in ipairs(tasksData.playerBossTasks or {}) do
            activeBossMap[task.id] = task
        end

        -- Se a task está em execução, mostra botões de ação
        if activeBossMap[selectedEntry] then
            local activeTask = activeBossMap[selectedEntry]
            
            -- Se progresso == 100%, mostrar Finish; se tem progresso, mostrar Abort
            if activeTask.done >= activeTask.kills then
                window.finishButton:show()
            else
                window.abortButton:show()
            end
            return true
        end

        local bossCompletedIds = tasksData['completedBossIds'] or {}
        local isRepeatable = false

        if tasksData['bossTasks'] then
            for _, t in ipairs(tasksData['bossTasks']) do
                if t.id == selectedEntry then
                    isRepeatable = t.repeatable or false
                    break
                end
            end
        end

        if table.contains(bossCompletedIds, selectedEntry) and not isRepeatable then
            setTaskConsoleText("Task already completed!", "#888888")
            return true
        end

        local children = window.bossPanel:getChildren()
        for _, child in ipairs(children) do
            local childId = tonumber(child:getId():match('^boss_(%d+)$'))
            if (selectedEntry == childId) then
                local kills = child.kills:getText()
                if (child.progress:getWidth() == 159) then
                    window.finishButton:show()
                elseif (kills:find('/')) then
                    window.abortButton:show()
                else
                    window.startButton:show()
                end
            end
        end
    end
end

function onFilterSearch(widget, text)
    -- Cancela debounce anterior
    if searchDebounce then
        removeEvent(searchDebounce)
        searchDebounce = nil
    end

    -- Limpa seleção e botões de ação
    selectedEntry = nil
    if window then
        window.finishButton:hide()
        window.startButton:hide()
        window.abortButton:hide()
        window.wikiButton:hide()
    end

    local searchText = (text or (window and window.search:getText()) or ''):trim()

    -- Debounce de 300ms: envia busca ao servidor
    searchDebounce = scheduleEvent(function()
        searchDebounce = nil
        if not g_game.isOnline() or not window then return end
        currentPage[currentTab] = 1
        sendOpcode({ action = 'search', tab = currentTab, query = searchText, page = 1 })
    end, 300)
end

function start()
    if (not selectedEntry) then
        return not setTaskConsoleText("Please select monster from monster list.", "red")
    end
    local actionMap = { exclusive = 'start_exclusive', boss = 'start_boss' }
    local actionName = actionMap[selectedEntryType] or 'start'
    sendOpcode({ action = actionName, entry = selectedEntry })
end

function finish()
    if (not selectedEntry) then
        return not setTaskConsoleText("Please select monster from monster list.", "red")
    end
    local actionMap = { exclusive = 'finish_exclusive', boss = 'finish_boss' }
    local actionName = actionMap[selectedEntryType] or 'finish'
    sendOpcode({ action = actionName, entry = selectedEntry })
end

function abort()
    local cancelConfirm = nil

    if (cancelConfirm) then
        cancelConfirm:destroy()
        cancelConfirm = nil
    end

    if (not selectedEntry) then
        return not setTaskConsoleText("Please select monster from monster list.", "red")
    end

    local yesFunc = function()
        cancelConfirm:destroy()
        cancelConfirm = nil
        local actionMap = { exclusive = 'cancel_exclusive', boss = 'cancel_boss' }
        local actionName = actionMap[selectedEntryType] or 'cancel'
        sendOpcode({ action = actionName, entry = selectedEntry })
    end

    local noFunc = function()
        cancelConfirm:destroy()
        cancelConfirm = nil
    end

    cancelConfirm = displayGeneralBox(tr('Tasks'), tr("Do you really want to abort this task?"), {
        {
            text = tr('No'),
            callback = noFunc
        },
        {
            text = tr('Yes'),
            callback = yesFunc
        },
        anchor = AnchorHorizontalCenter
    }, yesFunc, noFunc)
end

function openWiki()
    if not selectedEntry then return end

    -- Fontes de dados: lista paginada + lista de tasks ativas (fallback para filtro ativo)
    local primaryList, activeList
    if selectedEntryType == 'exclusive' then
        primaryList = tasksData.exclusiveTasks or {}
        activeList  = tasksData.playerExclusiveTasks or {}
    elseif selectedEntryType == 'boss' then
        primaryList = tasksData.bossTasks or {}
        activeList  = tasksData.playerBossTasks or {}
    else
        primaryList = tasksData.allTasks or {}
        activeList  = tasksData.playerTasks or {}
    end

    local creatureName = nil
    for _, t in ipairs(primaryList) do
        if t.id == selectedEntry then
            creatureName = t.creature or t.name
            break
        end
    end
    if not creatureName or creatureName == '' then
        for _, t in ipairs(activeList) do
            if t.id == selectedEntry then
                creatureName = t.creature or t.name
                break
            end
        end
    end

    if not creatureName or creatureName == '' then return end

    -- Formata o nome igual ao padrão usado no item wiki:
    -- palavras com > 2 letras: primeira maiúscula, resto minúsculo
    -- palavras com ≤ 2 letras: tudo minúsculo
    -- espaços viram underscore
    local wikiName = creatureName:gsub("(%w+)", function(word)
        if word:len() <= 2 then
            return word:lower()
        else
            return word:sub(1,1):upper() .. word:sub(2):lower()
        end
    end):gsub(' ', '_')

    g_platform.openUrl('https://www.tibiawiki.com.br/wiki/' .. wikiName)
end

function updateTasks(data)
    -- Notificações disparam sempre, independente da janela estar aberta
    if data['taskCompleted'] then
        if modules.game_notification then
            modules.game_notification.show({
                title = 'Task Complete!',
                message = 'You completed: ' .. (data['completedTaskName'] or ''),
                color = '#00ff00',
                icon = imagesPath .. '/taskIconNotify',
                duration = 5000
            })
        end

        -- Modal de reinício: aparece somente se a task for repetível
        if data['taskRepeatable'] and data['completedTaskId'] then
            local taskId   = data['completedTaskId']
            local taskType = data['completedTaskType'] or 'normal'
            local taskName = data['completedTaskName'] or ''
            local restartDialog = nil

            local yesFunc = function()
                if restartDialog then restartDialog:destroy(); restartDialog = nil end
                local actionMap = { exclusive = 'start_exclusive', boss = 'start_boss', normal = 'start' }
                local actionName = actionMap[taskType] or 'start'
                sendOpcode({ action = actionName, entry = taskId })
            end

            local noFunc = function()
                if restartDialog then restartDialog:destroy(); restartDialog = nil end
            end

            restartDialog = displayGeneralBox(tr('Tasks'), tr('Deseja reiniciar a task "%s"?', taskName), {
                { text = tr('Nao'), callback = noFunc },
                { text = tr('Sim'), callback = yesFunc }, 
                anchor = AnchorHorizontalCenter
            }, yesFunc, noFunc)
        end
    end

    if data['taskReadyToFinish'] then
        if modules.game_notification then
            modules.game_notification.show({
                title = 'Task Ready!',
                message = (data['readyTaskName'] or '') .. ' - go claim your reward!',
                color = '#ffaa00',
                icon = imagesPath .. '/taskIconNotify',
                duration = 4000
            })
        end
    end

    -- Pacote sem aba: apenas mensagem/notificação
    if not data['tab'] then
        if data['message'] then
            setTaskConsoleText(data['message'], data['color'])
        end
        return
    end

    -- Mensagem inline junto com atualização de dados
    if data['message'] then
        setTaskConsoleText(data['message'], data['color'])
    end

    -- Atualiza pontos
    if data['points'] then
        window.pointsPlayer:setText("Pontos: " .. data.points)
    end

    local tab = data['tab']

    -- ── ABA TASKS ─────────────────────────────────────────────────────────────
    if tab == 'tasks' then
        currentPage.tasks  = data['page']       or 1
        totalPages.tasks   = data['totalPages'] or 1

        -- Cacheia metadados
        if data['playerTasks']    then tasksData.playerTasks    = data['playerTasks']    end
        if data['completedIds']   then completedIds             = data['completedIds']    end
        if data['allTasks']       then tasksData.allTasks       = data['allTasks']        end

        renderTasksPage()
        updatePageControls()

    -- ── ABA EXCLUSIVE ─────────────────────────────────────────────────────────
    elseif tab == 'exclusive' then
        currentPage.exclusive = data['page']       or 1
        totalPages.exclusive  = data['totalPages'] or 1

        if data['playerExclusiveTasks']  then tasksData.playerExclusiveTasks  = data['playerExclusiveTasks']  end
        if data['completedExclusiveIds'] then tasksData.completedExclusiveIds = data['completedExclusiveIds'] end
        if data['exclusiveTasks']        then tasksData.exclusiveTasks        = data['exclusiveTasks']        end

        renderExclusivePage()
        updatePageControls()

    -- ── ABA SHOP ──────────────────────────────────────────────────────────────
    elseif tab == 'shop' then
        currentPage.shop = data['page']       or 1
        totalPages.shop  = data['totalPages'] or 1

        if data['shopItems'] then shopData = data['shopItems'] end

        renderShop()
        updatePageControls()

    -- ── ABA BOSS ──────────────────────────────────────────────────────────────
    elseif tab == 'boss' then
        currentPage.boss = data['page']       or 1
        totalPages.boss  = data['totalPages'] or 1

        if data['playerBossTasks']  then tasksData.playerBossTasks  = data['playerBossTasks']  end
        if data['completedBossIds'] then tasksData.completedBossIds = data['completedBossIds'] end
        if data['bossTasks']        then tasksData.bossTasks        = data['bossTasks']        end

        renderBossPage()
        updatePageControls()
    end

    -- Atualiza contador no botão da aba atual (baseado no filtro ativo)
    if data['totalItems'] and window and tab then
        local tabLabelMap = { tasks='Tasks', exclusive='Exclus.', boss='Boss', shop='Shop' }
        local tabIdMap    = { tasks='tabTasks', exclusive='tabExclusive', boss='tabBoss', shop='tabShop' }
        local tabId    = tabIdMap[tab]
        local tabLabel = tabLabelMap[tab]
        if tabId and tabLabel and window.tabPanel[tabId] then
            window.tabPanel[tabId]:setText(tabLabel .. ' (' .. data['totalItems'] .. ')')
        end
    end

    -- Atualiza contadores de TODAS as abas (totais sem filtro, enviado em toda resposta)
    if data['tabCounts'] and window then
        local tabLabelMap = { tasks='Tasks', exclusive='Exclus.', boss='Boss', shop='Shop' }
        local tabIdMap    = { tasks='tabTasks', exclusive='tabExclusive', boss='tabBoss', shop='tabShop' }
        for tabKey, count in pairs(data['tabCounts']) do
            local tabId    = tabIdMap[tabKey]
            local tabLabel = tabLabelMap[tabKey]
            if tabId and tabLabel and window.tabPanel[tabId] then
                window.tabPanel[tabId]:setText(tabLabel .. ' (' .. count .. ')')
            end
        end
    end
end

-- Reavalia e exibe o botão de ação correto para o card atualmente selecionado
function refreshActionButtons(panel)
    if not selectedEntry or not panel then return end
    local child = panel:getFocusedChild()
    if not child then return end

    window.finishButton:hide()
    window.startButton:hide()
    window.abortButton:hide()
    window.wikiButton:show()

    local kills = child.kills:getText()
    if child.progress:getWidth() == 159 then
        window.finishButton:show()
    elseif kills:find('/') then
        window.abortButton:show()
    else
        window.startButton:show()
    end
end

-- Renderiza a página atual da aba Tasks
function renderTasksPage()
    if not window then return end
    local selectionList = window.selectionList
    selectionList.onChildFocusChange = nil
    selectionList:destroyChildren()

    -- Mapa rápido de tasks ativas: id → task com dados de progresso
    local activeMap = {}
    for _, task in ipairs(tasksData.playerTasks or {}) do
        activeMap[task.id] = task
    end

    local iterList
    if activeFilter then
        local fullList = tasksData.playerTasks or {}
        local page  = activeFilterPage['tasks'] or 1
        local total = math.max(1, math.ceil(#fullList / PAGE_SIZE))
        activeFilterTotalPages['tasks'] = total
        if page > total then page = total; activeFilterPage['tasks'] = page end
        local s = (page - 1) * PAGE_SIZE + 1
        local e = math.min(page * PAGE_SIZE, #fullList)
        iterList = {}
        for i = s, e do iterList[#iterList + 1] = fullList[i] end
    else
        iterList = tasksData.allTasks or {}
    end
    for _, task in ipairs(iterList) do
        local button = g_ui.createWidget("TaskSelectionButton", selectionList)
        button:setId(task.id)
        button.creature:setOutfit(task.looktype)
        button.creature:getCreature():setStaticWalking(1000)
        button.name:setText(task.name)
        button.orderNum:setText('')
        button.orderNum:setVisible(false)
        button.reward:setText('Reward: ' .. formatNumber(task.exp) .. ' exp')
        button.rewardTaskPoints:setText('Task Points: ' .. (task.taskPoints or 0))
        
        -- Display creature health if available
        if task.maxHealth and task.maxHealth > 0 then
            button.health:setText("Life: " .. formatNumber(task.maxHealth))
            button.health:setVisible(true)
        else
            button.health:setVisible(false)
        end

        local activeTask = activeMap[task.id]
        if activeTask then
            -- Task ativa
            button.kills:setText('Kills: ' .. activeTask.done .. '/' .. task.kills)
            local progress = 159 * activeTask.done / task.kills
            button.progress:setWidth(progress)
            button:setBackgroundColor('#0a1a3a')
            button.lockedText:setText('')
        else
            button.kills:setText('Kills: ' .. task.kills)
            button.progress:setWidth(0)
            if table.contains(completedIds, task.id) then
                if task.repeatable then
                    button:setBackgroundColor('#0a2a0a')
                    button.lockedText:setText('')
                else
                    button:setBackgroundColor('#202020')
                    button.lockedText:setText('Done')
                    button.lockedText:setColor('#888888')
                end
            else
                button:setBackgroundColor('#0a2a0a')
                button.lockedText:setText('')
            end
        end

        selectionList:focusChild(button)
    end

    selectionList.onChildFocusChange = onItemSelect
    -- Restaura seleção se havia um card selecionado nesta aba
    if selectedEntry and selectedEntryType == 'normal' then
        local child = selectionList:getChildById(tostring(selectedEntry))
        if child then
            selectionList.onChildFocusChange = nil
            selectionList:focusChild(child)
            selectionList.onChildFocusChange = onItemSelect
            refreshActionButtons(selectionList)
        else
            selectedEntry = nil
            selectedEntryType = 'normal'
            window.finishButton:hide()
            window.startButton:hide()
            window.abortButton:hide()
            window.wikiButton:hide()
            selectionList:focusChild(nil)
        end
    else
        selectionList:focusChild(nil)
    end
end

-- Renderiza a página atual da aba Exclusive
function renderExclusivePage()
    if not window then return end
    local exPanel = window.exclusivePanel
    exPanel.onChildFocusChange = nil
    exPanel:destroyChildren()

    local exCompletedIds = tasksData.completedExclusiveIds or {}

    -- Mapa rápido de tasks exclusivas ativas: id → task com dados de progresso
    local activeExMap = {}
    for _, task in ipairs(tasksData.playerExclusiveTasks or {}) do
        activeExMap[task.id] = task
    end

    local iterList
    if activeFilter then
        local fullList = tasksData.playerExclusiveTasks or {}
        local page  = activeFilterPage['exclusive'] or 1
        local total = math.max(1, math.ceil(#fullList / PAGE_SIZE))
        activeFilterTotalPages['exclusive'] = total
        if page > total then page = total; activeFilterPage['exclusive'] = page end
        local s = (page - 1) * PAGE_SIZE + 1
        local e = math.min(page * PAGE_SIZE, #fullList)
        iterList = {}
        for i = s, e do iterList[#iterList + 1] = fullList[i] end
    else
        iterList = tasksData.exclusiveTasks or {}
    end
    for _, task in ipairs(iterList) do
        local button = g_ui.createWidget("TaskSelectionButton", exPanel)
        button:setId('ex_' .. task.id)
        button.creature:setOutfit(task.looktype)
        button.creature:getCreature():setStaticWalking(1000)
        button.name:setText(task.name)
        button.reward:setText('Reward: ' .. formatNumber(task.exp) .. ' exp')
        button.rewardTaskPoints:setText('Task Points: ' .. (task.taskPoints or 0))
        button.orderNum:setText('')
        button.orderNum:setVisible(false)
        
        -- Display creature health if available
        if task.maxHealth and task.maxHealth > 0 then
            button.health:setText("Life: " .. formatNumber(task.maxHealth))
            button.health:setVisible(true)
        else
            button.health:setVisible(false)
        end

        local activeTask = activeExMap[task.id]
        if activeTask then
            button.kills:setText('Kills: ' .. activeTask.done .. '/' .. task.kills)
            local progress = 159 * activeTask.done / task.kills
            button.progress:setWidth(progress)
            button:setBackgroundColor('#0a1a3a')
            button.lockedText:setText('')
        else
            button.kills:setText('Kills: ' .. task.kills)
            button.progress:setWidth(0)
            if task.locked then
                button:setBackgroundColor('#2a1a2a')
                button.lockedText:setText('Locked')
                button.lockedText:setColor('#cc44cc')
            elseif table.contains(exCompletedIds, task.id) then
                if task.repeatable then
                    button:setBackgroundColor('#0a2a0a')
                    button.lockedText:setText('')
                else
                    button:setBackgroundColor('#202020')
                    button.lockedText:setText('Done')
                    button.lockedText:setColor('#888888')
                end
            else
                button:setBackgroundColor('#0a2a0a')
                button.lockedText:setText('')
            end
        end

        exPanel:focusChild(button)
    end

    exPanel.onChildFocusChange = onExclusiveItemSelect
    -- Restaura seleção se havia um card selecionado nesta aba
    if selectedEntry and selectedEntryType == 'exclusive' then
        local child = exPanel:getChildById('ex_' .. selectedEntry)
        if child then
            exPanel.onChildFocusChange = nil
            exPanel:focusChild(child)
            exPanel.onChildFocusChange = onExclusiveItemSelect
            refreshActionButtons(exPanel)
        else
            selectedEntry = nil
            selectedEntryType = 'normal'
            window.finishButton:hide()
            window.startButton:hide()
            window.abortButton:hide()
            window.wikiButton:hide()
            exPanel:focusChild(nil)
        end
    else
        exPanel:focusChild(nil)
    end
end

-- Renderiza a página atual da aba Boss
function renderBossPage()
    if not window then return end
    local bossPanel = window.bossPanel
    bossPanel.onChildFocusChange = nil
    bossPanel:destroyChildren()

    local bossCompletedIds = tasksData.completedBossIds or {}

    -- Mapa rápido de tasks boss ativas: id → task com dados de progresso
    local activeBossMap = {}
    for _, task in ipairs(tasksData.playerBossTasks or {}) do
        activeBossMap[task.id] = task
    end

    local iterList
    if activeFilter then
        local fullList = tasksData.playerBossTasks or {}
        local page  = activeFilterPage['boss'] or 1
        local total = math.max(1, math.ceil(#fullList / PAGE_SIZE))
        activeFilterTotalPages['boss'] = total
        if page > total then page = total; activeFilterPage['boss'] = page end
        local s = (page - 1) * PAGE_SIZE + 1
        local e = math.min(page * PAGE_SIZE, #fullList)
        iterList = {}
        for i = s, e do iterList[#iterList + 1] = fullList[i] end
    else
        iterList = tasksData.bossTasks or {}
    end
    for _, task in ipairs(iterList) do
        local button = g_ui.createWidget("TaskSelectionButton", bossPanel)
        button:setId('boss_' .. task.id)
        button.creature:setOutfit(task.looktype)
        button.creature:getCreature():setStaticWalking(1000)
        button.name:setText(task.name)
        button.reward:setText('Reward: ' .. formatNumber(task.exp) .. ' exp')
        button.rewardTaskPoints:setText('Task Points: ' .. (task.taskPoints or 0))
        button.orderNum:setText('')
        button.orderNum:setVisible(false)
        
        -- Display creature health if available
        if task.maxHealth and task.maxHealth > 0 then
            button.health:setText("Life: " .. formatNumber(task.maxHealth))
            button.health:setVisible(true)
        else
            button.health:setVisible(false)
        end

        local activeTask = activeBossMap[task.id]
        if activeTask then
            button.kills:setText('Kills: ' .. activeTask.done .. '/' .. task.kills)
            local progress = 159 * activeTask.done / task.kills
            button.progress:setWidth(progress)
            button:setBackgroundColor('#0a1a3a')
            button.lockedText:setText('')
        else
            button.kills:setText('Kills: ' .. task.kills)
            button.progress:setWidth(0)
            if table.contains(bossCompletedIds, task.id) then
                if task.repeatable then
                    button:setBackgroundColor('#0a2a0a')
                    button.lockedText:setText('')
                else
                    button:setBackgroundColor('#202020')
                    button.lockedText:setText('Done')
                    button.lockedText:setColor('#888888')
                end
            else
                button:setBackgroundColor('#0a2a0a')
                button.lockedText:setText('')
            end
        end

        bossPanel:focusChild(button)
    end

    bossPanel.onChildFocusChange = onBossItemSelect
    -- Restaura seleção se havia um card selecionado nesta aba
    if selectedEntry and selectedEntryType == 'boss' then
        local child = bossPanel:getChildById('boss_' .. selectedEntry)
        if child then
            bossPanel.onChildFocusChange = nil
            bossPanel:focusChild(child)
            bossPanel.onChildFocusChange = onBossItemSelect
            refreshActionButtons(bossPanel)
        else
            selectedEntry = nil
            selectedEntryType = 'normal'
            window.finishButton:hide()
            window.startButton:hide()
            window.abortButton:hide()
            window.wikiButton:hide()
            bossPanel:focusChild(nil)
        end
    else
        bossPanel:focusChild(nil)
    end
end

function toggleActiveFilter()
    if currentTab == 'shop' then return end
    activeFilter = not activeFilter
    activeFilterPage[currentTab] = 1
    if activeFilter then
        if currentTab == 'tasks' then renderTasksPage()
        elseif currentTab == 'exclusive' then renderExclusivePage()
        elseif currentTab == 'boss' then renderBossPage()
        end
    else
        sendOpcode({ action = 'page', tab = currentTab, page = currentPage[currentTab] or 1 })
    end
    updatePageControls()
end

function switchTab(tab, page)
    activeFilter = false
    currentTab = tab
    currentPage[tab]      = page or 1
    activeFilterPage[tab] = 1

    -- Reseta seleção ao trocar de aba
    selectedEntry = nil
    selectedEntryType = 'normal'
    window.finishButton:hide()
    window.startButton:hide()
    window.abortButton:hide()
    window.wikiButton:hide()

    -- Garante que a tela de detalhe esteja fechada
    window.detailTab:setVisible(false)

    -- Visibilidade dos painéis
    window.selectionList:setVisible(tab == 'tasks')
    window.shopPanel:setVisible(tab == 'shop')
    window.exclusivePanel:setVisible(tab == 'exclusive')
    window.bossPanel:setVisible(tab == 'boss')
    window.search:setVisible(true)

    -- Abas habilitadas/desabilitadas
    window.tabPanel.tabTasks:setEnabled(tab ~= 'tasks')
    window.tabPanel.tabShop:setEnabled(tab ~= 'shop')
    window.tabPanel.tabExclusive:setEnabled(tab ~= 'exclusive')
    window.tabPanel.tabBoss:setEnabled(tab ~= 'boss')

    -- Botão Reset: visível se adminMode = true (em todas as abas)
    if window.tabPanel.tabReset then
        window.tabPanel.tabReset:setVisible(adminMode)
    end

    -- Reseta busca e debounce ao trocar de aba
    if searchDebounce then
        removeEvent(searchDebounce)
        searchDebounce = nil
    end
    window.search:setText('')

    -- Mostra controles de paginação
    if window.pagePanel then
        window.pagePanel:setVisible(true)
        updatePageControls()
    end

    -- Solicita página atual ao servidor
    sendOpcode({ action = 'page', tab = tab, page = currentPage[tab] or 1 })
end

function renderShop()
    if not window or not window.shopPanel then return end
    window.shopPanel:destroyChildren()
    for _, item in ipairs(shopData) do
        local btn = g_ui.createWidget('ShopButton', window.shopPanel)
        local owned = item.owned or false
        if item.isMountId or item.isOutfit then
            btn.shopItemId:hide()
            if btn.shopImage then btn.shopImage:hide() end
            btn.shopMountId:show()
            btn.shopMountId:setOutfit({ type = item.clientId })
            btn.shopMountId:getCreature():setStaticWalking(1000)
        elseif item.isXpBoost then
            btn.shopItemId:hide()
            if btn.shopMountId then btn.shopMountId:hide() end
            if btn.shopImage then
                btn.shopImage:setImageSource('/game_task/images/XP_Boost.png')
                btn.shopImage:show()
            end
        elseif item.isPreyCard then
            btn.shopItemId:hide()
            if btn.shopMountId then btn.shopMountId:hide() end
            if btn.shopImage then
                btn.shopImage:setImageSource('/game_task/images/Prey_Bonus_Reroll.png')
                btn.shopImage:show()
            end
        else
            btn.shopItemId:show()
            if btn.shopMountId then btn.shopMountId:hide() end
            if btn.shopImage then btn.shopImage:hide() end
            btn.shopItemId:setItemId(item.clientId or item.itemId)
            btn.shopItemId:setItemCount(item.count)
        end
        btn.shopName:setText(item.name or tostring(item.itemId))
        btn.shopCount:setText('x' .. item.count)
        btn.shopPrice:setText(item.price .. ' pts')
        local localItem = item
        if owned then
            btn.shopBuy:setEnabled(false)
            btn.shopBuy:setText(localItem.isXpBoost and 'Ativo' or 'Owned')
        else
            btn.shopBuy:setEnabled(true)
            btn.shopBuy:setText('Buy')
            btn.shopBuy.onClick = function()
                buyItem(localItem.itemId)
            end
        end
    end

end

function buyItem(itemId)
    sendOpcode({ action = 'shop_buy', itemId = itemId })
end

function updatePageControls()
    if not window or not window.pagePanel then return end
    local page  = currentPage[currentTab] or 1
    local total = totalPages[currentTab]  or 1
    window.pagePanel:setVisible(true)

    -- Botão Active: visível em tasks/boss/exclusive, cor reflete estado
    local btn = window.pagePanel.activeFilterButton
    if btn then
        btn:setVisible(currentTab ~= 'shop')
        btn:setColor(activeFilter and '#00dd00' or '#ff6666')
    end

    if activeFilter then
        local aPage  = activeFilterPage[currentTab]       or 1
        local aTotal = activeFilterTotalPages[currentTab] or 1
        window.pagePanel.pageLabel:setText('Page ' .. aPage .. ' / ' .. aTotal)
        window.pagePanel.firstButton:setEnabled(aPage > 1)
        window.pagePanel.prevButton:setEnabled(aPage > 1)
        window.pagePanel.nextButton:setEnabled(aPage < aTotal)
        window.pagePanel.lastButton:setEnabled(aPage < aTotal)
    else
        window.pagePanel.pageLabel:setText('Page ' .. page .. ' / ' .. total)
        window.pagePanel.firstButton:setEnabled(page > 1)
        window.pagePanel.prevButton:setEnabled(page > 1)
        window.pagePanel.nextButton:setEnabled(page < total)
        window.pagePanel.lastButton:setEnabled(page < total)
    end
end

function prevPage()
    if activeFilter then
        local tab = currentTab
        activeFilterPage[tab] = math.max(1, (activeFilterPage[tab] or 1) - 1)
        if tab == 'tasks' then renderTasksPage()
        elseif tab == 'exclusive' then renderExclusivePage()
        elseif tab == 'boss' then renderBossPage() end
        updatePageControls()
        return
    end
    local tab  = currentTab
    local page = math.max(1, (currentPage[tab] or 1) - 1)
    currentPage[tab] = page
    sendOpcode({ action = 'page', tab = tab, page = page })
end

function nextPage()
    if activeFilter then
        local tab   = currentTab
        local total = activeFilterTotalPages[tab] or 1
        activeFilterPage[tab] = math.min(total, (activeFilterPage[tab] or 1) + 1)
        if tab == 'tasks' then renderTasksPage()
        elseif tab == 'exclusive' then renderExclusivePage()
        elseif tab == 'boss' then renderBossPage() end
        updatePageControls()
        return
    end
    local tab   = currentTab
    local total = totalPages[tab] or 1
    local page  = math.min(total, (currentPage[tab] or 1) + 1)
    currentPage[tab] = page
    sendOpcode({ action = 'page', tab = tab, page = page })
end

function firstPage()
    if activeFilter then
        local tab = currentTab
        if (activeFilterPage[tab] or 1) <= 1 then return end
        activeFilterPage[tab] = 1
        if tab == 'tasks' then renderTasksPage()
        elseif tab == 'exclusive' then renderExclusivePage()
        elseif tab == 'boss' then renderBossPage() end
        updatePageControls()
        return
    end
    local tab = currentTab
    if (currentPage[tab] or 1) <= 1 then return end
    currentPage[tab] = 1
    sendOpcode({ action = 'page', tab = tab, page = 1 })
end

function lastPage()
    if activeFilter then
        local tab   = currentTab
        local total = activeFilterTotalPages[tab] or 1
        if (activeFilterPage[tab] or 1) >= total then return end
        activeFilterPage[tab] = total
        if tab == 'tasks' then renderTasksPage()
        elseif tab == 'exclusive' then renderExclusivePage()
        elseif tab == 'boss' then renderBossPage() end
        updatePageControls()
        return
    end
    local tab   = currentTab
    local total = totalPages[tab] or 1
    if (currentPage[tab] or 1) >= total then return end
    currentPage[tab] = total
    sendOpcode({ action = 'page', tab = tab, page = total })
end

function resetProgress()
    if not adminMode then return end
    local confirmDialog = nil
    local yesFunc = function()
        if confirmDialog then confirmDialog:destroy(); confirmDialog = nil end
        sendOpcode({ action = 'admin_reset' })
    end
    local noFunc = function()
        if confirmDialog then confirmDialog:destroy(); confirmDialog = nil end
    end
    confirmDialog = displayGeneralBox(tr('Tasks - Admin'), tr("Resetar TODO o progresso de tasks? Isso nao pode ser desfeito!"), {
        { text = tr('Nao'), callback = noFunc },
        { text = tr('Sim'), callback = yesFunc },
        anchor = AnchorHorizontalCenter
    }, yesFunc, noFunc)
end

function toggleWindow()
    if (not g_game.isOnline()) then
        return
    end

    if (window:isVisible()) then
        sendOpcode({
            action = 'hide'
        })
        window:setVisible(false)
        if taskButton then taskButton:setOn(false) end
    else
        local savedActiveFilter = activeFilter  -- preserva estado do filtro ativo
        local savedTab = currentTab             -- preserva a aba que estava aberta
        currentTab = 'tasks'
        activeFilter = false
        currentPage      = { tasks = 1, exclusive = 1, shop = 1, boss = 1 }
        activeFilterPage = { tasks = 1, exclusive = 1, shop = 1, boss = 1 }
        selectedEntry = nil
        selectedEntryType = 'normal'
        window.finishButton:hide()
        window.startButton:hide()
        window.abortButton:hide()
        window.wikiButton:hide()
        -- Limpa pesquisa ao abrir a janela
        if searchDebounce then
            removeEvent(searchDebounce)
            searchDebounce = nil
        end
        window.search:setText('')
        activeFilter = savedActiveFilter  -- restaura o filtro ativo
        currentTab   = savedTab           -- restaura a aba
        window:setVisible(true)
        if taskButton then taskButton:setOn(true) end
        openMainModule()
    end
end

function hideWindowzz()
    if (not g_game.isOnline()) then
        return
    end

    if (window:isVisible()) then
        sendOpcode({
            action = 'hide'
        })
        window:setVisible(false)
        if taskButton then taskButton:setOn(false) end
    end
end

function setTaskConsoleText(text, color)
    if (not color) then
        color = 'white'
    end

    window.info:setText(text)
    window.info:setColor(color)

    if consoleEvent then
        removeEvent(consoleEvent)
        consoleEvent = nil
    end

    consoleEvent = scheduleEvent(function()
        window.info:setText('')
    end, 5000)

    return true
end

function openMainModule()
   local savedPage = currentPage[currentTab]
   local savedSearch = window and window.search:getText() or ''
   local savedActiveFilter = activeFilter
   window.detailTab:setVisible(false)
   window.info:setVisible(true)
   window.toggleButton:setVisible(true)
   window.tabPanel:setVisible(true)
   switchTab(currentTab, savedPage)
   -- Restaura o filtro ativo que estava antes de abrir o detalhe
   activeFilter = savedActiveFilter
   -- Restaura a busca que estava ativa antes de abrir o detalhe
   if savedSearch ~= '' then
      window.search:setText(savedSearch)
      sendOpcode({ action = 'search', tab = currentTab, query = savedSearch, page = savedPage })
   elseif savedActiveFilter then
      -- Se estava em modo ativo, resolicita página com filtro ativo
      sendOpcode({ action = 'page', tab = currentTab, page = currentPage[currentTab] or 1 })
   end
   updatePageControls()
end

function onTaskClick(widget)
   showTaskDetails(widget:getId())
end

function showTaskDetails(rawId)
    local isBoss      = type(rawId) == 'string' and rawId:sub(1, 5) == 'boss_'
    local isExclusive = not isBoss and type(rawId) == 'string' and rawId:sub(1, 3) == 'ex_'
    local taskId
    if isBoss then
        taskId = tonumber(rawId:match('^boss_(%d+)$'))
    elseif isExclusive then
        taskId = tonumber(rawId:match('^ex_(%d+)$'))
    else
        taskId = tonumber(rawId)
    end
    local task = nil

    if isBoss then
        if tasksData.playerBossTasks then
            for _, t in ipairs(tasksData.playerBossTasks) do
                if t.id == taskId then task = t; break end
            end
        end
        if not task and tasksData.bossTasks then
            for _, t in ipairs(tasksData.bossTasks) do
                if t.id == taskId then task = t; break end
            end
        end
    elseif isExclusive then
        if tasksData.playerExclusiveTasks then
            for _, t in ipairs(tasksData.playerExclusiveTasks) do
                if t.id == taskId then task = t; break end
            end
        end
        if not task and tasksData.exclusiveTasks then
            for _, t in ipairs(tasksData.exclusiveTasks) do
                if t.id == taskId then task = t; break end
            end
        end
    else
        if tasksData.playerTasks then
            for _, t in ipairs(tasksData.playerTasks) do
                if t.id == taskId then task = t; break end
            end
        end
        if not task and tasksData.allTasks then
            for _, t in ipairs(tasksData.allTasks) do
                if t.id == taskId then task = t; break end
            end
        end
    end

    if not task then return end
    
    local detailTab = window.detailTab
    detailTab.creatureName:setText(task.name .. ' (' .. (task.creature or task.name) .. ')')
    detailTab.creatureImage:setOutfit(task.looktype)
    detailTab.creatureImage:getCreature():setStaticWalking(1000)
    
    -- Display creature health if available
    if task.maxHealth and task.maxHealth > 0 then
        detailTab.detailHealth:setText("Life: " .. formatNumber(task.maxHealth))
        detailTab.detailHealth:setVisible(true)
    else
        detailTab.detailHealth:setVisible(false)
    end

    if task.speed then
        local xpAmt = formatNumber(task.monsterExp or 0)
        detailTab.detailStats:setText("Xp: " .. xpAmt .. " | Speed: " .. task.speed .. " | Armor: " .. (task.armor or 0))
        detailTab.detailStats:setVisible(true)
    else
        detailTab.detailStats:setVisible(false)
    end

    if task.elements then
        local e = task.elements
        local function elemColor(v)
            if v == 0 then return '#222222'
            elseif v < 100 then return '#ff5555'
            elseif v == 100 then return '#888888'
            else return '#55dd55'
            end
        end
        local row1 = detailTab.detailElementsRow1
        local row2 = detailTab.detailElementsRow2
        local function setElem(panel, id, label, val)
            local w = panel:getChildById(id)
            if w then
                w:setText(label .. ': ' .. val .. '%')
                w:setColor(elemColor(val))
            end
        end
        setElem(row1, 'elemPhysical', 'Physical', e.physical)
        setElem(row1, 'elemEarth',    'Earth',    e.earth)
        setElem(row1, 'elemFire',     'Fire',     e.fire)
        setElem(row1, 'elemDeath',    'Death',    e.death)
        setElem(row2, 'elemEnergy',   'Energy',   e.energy)
        setElem(row2, 'elemHoly',     'Holy',     e.holy)
        setElem(row2, 'elemIce',      'Ice',      e.ice)
        setElem(row2, 'elemHeal',     'Heal',     e.healing)
        row1:setVisible(true)
        row2:setVisible(true)
    else
        detailTab.detailElementsRow1:setVisible(false)
        detailTab.detailElementsRow2:setVisible(false)
    end
    
    if task.done then
        detailTab.detailKills:setText("Kills: " .. task.done .. " / " .. task.kills)
    else
        detailTab.detailKills:setText("Kills: " .. task.kills)
    end
    
    detailTab.detailExp:setText("Experience: " .. formatNumber(task.exp))
    
    if task.moneyReward and task.moneyReward > 0 then
        detailTab.detailMoney:setText("Money: " .. formatNumber(task.moneyReward) .. " gp (bank)")
        detailTab.detailMoney:setVisible(true)
    else
        detailTab.detailMoney:setVisible(false)
    end

    if task.suggestedlocation and task.suggestedlocation ~= '' then
        detailTab.detailLocation:setText("Suggested Locations: " .. task.suggestedlocation)
        detailTab.detailLocation:setVisible(true)
    else
        detailTab.detailLocation:setVisible(false)
    end

    if task.taskPoints then
        detailTab.detailPoints:setText("Points: " .. task.taskPoints)
    else
        detailTab.detailPoints:setText("Points: None")
    end
    
    detailTab.rewardItems:destroyChildren()
    if task.itemRewards and #task.itemRewards > 0 then
        detailTab.rewardTitle:setVisible(true)
        for _, item in ipairs(task.itemRewards) do
            local itemWidget = g_ui.createWidget('Item', detailTab.rewardItems)
            itemWidget:setItemId(item.clientId)
            itemWidget:setItemCount(item.count)
            itemWidget:setVirtual(true) -- usually needed for non-inventory items
        
            -- Add tooltip
            if item.name then
                 itemWidget:setTooltip(item.name .. " (" .. item.count .. "x)")
            else
                 local thingType = g_things.getThingType(item.clientId, ThingCategoryItem)
                 if thingType then
                      itemWidget:setTooltip(thingType:getName() .. " (" .. item.count .. "x)")
                 end
            end
        end
        -- Calcula altura necessária baseada no número de linhas (10 itens por linha)
        local rows = math.ceil(#task.itemRewards / 10)
        local totalHeight = rows * 34 + math.max(0, rows - 1) * 2
        detailTab.rewardItems:setHeight(totalHeight)
    else
        detailTab.rewardTitle:setVisible(false)
    end
    
    window.search:setVisible(false)
    window.selectionList:setVisible(false)
    window.shopPanel:setVisible(false)
    window.exclusivePanel:setVisible(false)
    window.bossPanel:setVisible(false)
    window.tabPanel:setVisible(false)
    window.toggleButton:setVisible(false)
    window.finishButton:hide()
    window.startButton:hide()
    window.abortButton:hide()
    window.info:setVisible(false)
    if window.pagePanel then window.pagePanel:setVisible(false) end

    detailTab:setVisible(true)
end
