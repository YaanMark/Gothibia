local panel         = nil
local updateEvent   = nil
local balanceButton = nil
local OPCODE        = 191

function init()
    panel = g_ui.displayUI('game_balance')
    if not panel then
        g_logger.error('[game_balance] displayUI retornou nil - verifique game_balance.otui')
        return
    end

    -- Esconde o toggleFilterButton (herdado do MiniWindow base, nao usado aqui)
    local filterBtn = panel:getChildById('toggleFilterButton')
    if filterBtn then filterBtn:hide() end

    if panel.setup then
        panel:setup()
    end
    panel:hide()

    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd   = onGameEnd,
    })
    ProtocolGame.registerExtendedJSONOpcode(OPCODE, onReceive)

    if modules.game_mainpanel then
        balanceButton = modules.game_mainpanel.addToggleButton(
            'balanceButton',
            tr('Balance'),
            '/game_balance/images/menubutton_balanceIcon',
            togglePanel,
            false,
            1
        )
    end

    if g_game.isOnline() then onGameStart() end
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd   = onGameEnd,
    })
    ProtocolGame.unregisterExtendedJSONOpcode(OPCODE, onReceive)
    if balanceButton then
        balanceButton:destroy()
        balanceButton = nil
    end
    if updateEvent then
        removeEvent(updateEvent)
        updateEvent = nil
    end
    if panel then
        panel:destroy()
        panel = nil
    end
end

function onGameStart()
    panel:setupOnStart()
    scheduleUpdate()
end

function onGameEnd()
    if updateEvent then
        removeEvent(updateEvent)
        updateEvent = nil
    end
    panel:hide()
    if balanceButton then balanceButton:setOn(false) end
end

function togglePanel()
    if not panel then return end
    if panel:isVisible() then
        panel:close()
        if balanceButton then balanceButton:setOn(false) end
    else
        panel:open()
        if balanceButton then balanceButton:setOn(true) end
    end
end

function onMiniWindowOpen()
    if balanceButton then balanceButton:setOn(true) end
end

function onMiniWindowClose()
    if balanceButton then balanceButton:setOn(false) end
end

function scheduleUpdate()
    requestBalance()
    updateEvent = scheduleEvent(function()
        if g_game.isOnline() and panel then
            scheduleUpdate()
        end
    end, 3000)
end

function requestBalance()
    if not g_game.isOnline() then return end
    local protocol = g_game.getProtocolGame()
    if protocol then
        protocol:sendExtendedJSONOpcode(OPCODE, {})
    end
end

function onReceive(protocol, opcode, data)
    if not panel then return end
    local goldBag  = panel:recursiveGetChildById('goldBag')
    local goldBank = panel:recursiveGetChildById('goldBank')
    if goldBag  then goldBag:setText(formatGold(data.gold or 0)) end
    if goldBank then goldBank:setText(formatGold(data.bank or 0)) end
end

function formatGold(n)
    n = math.floor(n)
    local s = tostring(n)
    local result = ''
    local len = #s
    for i = 1, len do
        if i > 1 and (len - i + 1) % 3 == 0 then
            result = result .. ','
        end
        result = result .. s:sub(i, i)
    end
    return result .. ' gp'
end
