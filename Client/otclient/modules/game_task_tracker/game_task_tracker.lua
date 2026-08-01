local panel       = nil
local updateEvent = nil
local trackerBtn  = nil
local activeTasks = {}

local TRACKER_OPCODE = 194
local PANEL_CHROME  = 27   -- altura do cromo do MiniWindow (header + bordas)
local ROW_H         = 32   -- altura de cada linha (30px + 2px spacing)
local NO_TASK_H     = 55   -- altura quando nao ha tasks ativas

-- Cores por tipo de task
local TYPE_COLORS = {
    normal    = '#4488ff',
    exclusive = '#aa44cc',
    boss      = '#cc4444',
}
local TYPE_LABELS = {
    normal    = 'N',
    exclusive = 'E',
    boss      = 'B',
}

function init()
    panel = g_ui.displayUI('game_task_tracker')
    if not panel then
        g_logger.error('[game_task_tracker] displayUI retornou nil - verifique game_task_tracker.otui')
        return
    end

    local filterBtn = panel:getChildById('toggleFilterButton')
    if filterBtn then filterBtn:hide() end

    if panel.setup then panel:setup() end
    panel:hide()

    ProtocolGame.registerExtendedJSONOpcode(TRACKER_OPCODE, onTrackerReceive)

    connect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })

    if modules.game_mainpanel then
        trackerBtn = modules.game_mainpanel.addToggleButton(
            'taskTrackerButton',
            tr('Task Tracker'),
            '/game_task_tracker/images/taskTrackerIcon',
            togglePanel,
            false,
            3
        )
    end

    if g_game.isOnline() then onGameStart() end
end

function terminate()
    disconnect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })
    ProtocolGame.unregisterExtendedJSONOpcode(TRACKER_OPCODE, onTrackerReceive)
    if trackerBtn  then trackerBtn:destroy();     trackerBtn  = nil end
    if updateEvent then removeEvent(updateEvent); updateEvent = nil end
    if panel       then panel:destroy();          panel       = nil end
end

function onGameStart()
    panel:setupOnStart()
    requestTracker()
end

function onGameEnd()
    if updateEvent then removeEvent(updateEvent); updateEvent = nil end
    activeTasks = {}
    panel:hide()
    if trackerBtn then trackerBtn:setOn(false) end
end

function togglePanel()
    if not panel then return end
    if panel:isVisible() then
        panel:close()
        if trackerBtn then trackerBtn:setOn(false) end
    else
        panel:open()
        if trackerBtn then trackerBtn:setOn(true) end
    end
end

function onMiniWindowOpen()
    if trackerBtn then trackerBtn:setOn(true) end
end

function onMiniWindowClose()
    if trackerBtn then trackerBtn:setOn(false) end
end

function scheduleUpdate()
    if updateEvent then removeEvent(updateEvent); updateEvent = nil end
    updateEvent = scheduleEvent(function()
        if g_game.isOnline() and panel then
            requestTracker()
            scheduleUpdate()
        end
    end, 60000)  -- fallback de seguranca: server envia push em cada mudanca
end

function requestTracker()
    if not g_game.isOnline() then return end
    local protocol = g_game.getProtocolGame()
    if protocol then
        protocol:sendExtendedJSONOpcode(TRACKER_OPCODE, {})
    end
end

function onTrackerReceive(protocol, opcode, data)
    activeTasks = data.activeTasks or {}
    renderTasks()
end

function renderTasks()
    if not panel then return end
    local contents = panel:recursiveGetChildById('contentsPanel')
    if not contents then return end
    contents:destroyChildren()

    if #activeTasks == 0 then
        local lbl = g_ui.createWidget('UILabel', contents)
        lbl:setFont('verdana-11px-rounded')
        lbl:setColor('#888888')
        lbl:setText('No active tasks')
        lbl:setTextAlign(AlignCenter)
        lbl:setHeight(24)
        panel:setHeight(NO_TASK_H)
        return
    end

    for _, task in ipairs(activeTasks) do
        local row = g_ui.createWidget('TaskTrackerRow', contents)

        local taskType  = task.type or 'normal'
        local typeColor = TYPE_COLORS[taskType] or TYPE_COLORS.normal
        local typeLabel = TYPE_LABELS[taskType] or 'N'

        row.rowType:setText(typeLabel)
        row.rowType:setColor(typeColor)
        row.rowName:setText(task.creature or task.name or '?')
        row.rowKills:setText(task.done .. '/' .. task.kills)
        row.progressFill:setBackgroundColor(typeColor)

        -- Barra de progresso usa scheduleEvent para aguardar o layout ser computado
        local localTask = task
        local localRow  = row
        scheduleEvent(function()
            local ok = pcall(function()
                if not localRow:getParent() then return end
                local bg = localRow:getChildById('progressBg')
                if not bg then return end
                local maxW = bg:getWidth()
                if maxW <= 0 then maxW = 168 end
                local pct  = localTask.kills > 0 and (localTask.done / localTask.kills) or 0
                local fill = localRow:getChildById('progressFill')
                if fill then fill:setWidth(math.floor(pct * maxW)) end
            end)
        end, 0)
    end

    local newH = PANEL_CHROME + (#activeTasks * ROW_H)
    panel:setHeight(math.min(newH, 240))
end
