-- game_notification: modulo reutilizavel de notificacoes no centro da tela

local notifWidget = nil
local hideEvent = nil
local fadeEvent = nil
local queue = {}
local isShowing = false
local mapPanel = nil

-- Timers para checks periodicos
local checkEvent = nil
local lastHungryNotif = 0
local lastCapacityNotif = 0
local lastDailyRewardNotif = 0
local lastLowHpNotif = 0
local lastLowManaNotif = 0
local lastEquipNotif = 0

-- State tracking
local wasInPz = nil
local previousGold = nil
local wasInCombat = false

-- Export to global environment
_G.g_notification = g_notification or {}

-- ============================================================
-- CONFIGURACAO: IDs de itens que devem alertar quando equipados
-- fora de combate (ring / necklace)
-- Adicione aqui os IDs dos itens que voce quer monitorar
-- ============================================================
local ALERT_RING_IDS = {
    -- Rings
    3094,
    3049,
}

local ALERT_NECKLACE_IDS = {
    -- Necklaces
    22134,
    3014,
}

local FADE_STEPS = 10
local FADE_IN_MS = 300
local FADE_OUT_MS = 500
local DEFAULT_DURATION = 3000

function init()
    mapPanel = modules.game_interface.getMapPanel()
    g_ui.importStyle('notification')

    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onTextMessage = onTextMessage,
    })

    if g_game.isOnline() then
        onGameStart()
    end
end

function terminate()
    clearTimers()
    stopChecks()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onTextMessage = onTextMessage,
    })

    if notifWidget then
        notifWidget:destroy()
        notifWidget = nil
    end
    queue = {}
    isShowing = false
    mapPanel = nil
end

function onGameStart()
    wasInPz = nil
    previousGold = nil
    wasInCombat = false
    lastEquipNotif = 0

    -- Inicia checks periodicos apos 6s
    scheduleEvent(function()
        stopChecks()
        checkEvent = cycleEvent(periodicChecks, 1000)
    end, 6000)
end

function onGameEnd()
    stopChecks()
    lastHungryNotif = 0
    lastCapacityNotif = 0
    lastDailyRewardNotif = 0
    lastLowHpNotif = 0
    lastLowManaNotif = 0
    lastEquipNotif = 0
    wasInPz = nil
    previousGold = nil
    wasInCombat = false
    if notifWidget then notifWidget:hide() end
end

function stopChecks()
    if checkEvent then
        removeEvent(checkEvent)
        checkEvent = nil
    end
end

function clearTimers()
    if hideEvent then removeEvent(hideEvent); hideEvent = nil end
    if fadeEvent then removeEvent(fadeEvent); fadeEvent = nil end
end

-- ======== Helper: check if value is in table ========
local function tableContains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

-- ======== TEXT MESSAGE: Raids, Server Save, Double XP ========
function onTextMessage(mode, text)
    if not text or text == "" then return end
    local lowerText = text:lower()

    -- Raids
    if lowerText:find("raid") then
        show({
            title   = "Raid!",
            message = text,
            color   = "#FF4500",
            duration = 5000,
        })
        return
    end

    -- Server Save
    if lowerText:find("server save") or lowerText:find("server will save") or lowerText:find("shutdown") then
        show({
            title   = "Server Save!",
            message = text,
            color   = "#FF6347",
            duration = 5000,
        })
        return
    end

    -- Double XP / Exp Event
    if lowerText:find("double") and (lowerText:find("exp") or lowerText:find("xp") or lowerText:find("experience")) then
        show({
            title   = "Double XP!",
            message = text,
            color   = "#00FF7F",
            duration = 5000,
        })
        return
    end
end

-- ======== CHECKS PERIODICOS ========
function periodicChecks()
    local player = g_game.getLocalPlayer()
    if not player or not g_game.isOnline() then return end

    local now = os.time()

    -- 1) Low HP (abaixo de 20%) - a cada 5s
    local hp = player:getHealth()
    local maxHp = player:getMaxHealth()
    if maxHp > 0 and (hp / maxHp) <= 0.05 then
        if now - lastLowHpNotif >= 5 then
            lastLowHpNotif = now
            show({
                title   = "Vida Baixa!",
                message = "HP: " .. hp .. "/" .. maxHp,
                color   = "#FF0000",
                duration = 2000,
            })
        end
    else
        lastLowHpNotif = 0
    end

    -- 3) Fome (regenerationTime <= 0) - a cada 60s
    local regenTime = player:getRegenerationTime()
    if regenTime ~= nil and regenTime <= 0 then
        if now - lastHungryNotif >= 60 then
            lastHungryNotif = now
            show({
                title   = "Fome!",
                message = "Voce esta com fome, coma algo!",
                color   = "#FF6B6B",
                duration = 3000,
            })
        end
    else
        lastHungryNotif = 0
    end

    -- 4) Peso (freeCapacity <= 50) - a cada 60s
    local freeCap = player:getFreeCapacity()
    if freeCap <= 50 then
        if now - lastCapacityNotif >= 60 then
            lastCapacityNotif = now
            show({
                title   = "Peso!",
                message = "Voce esta pesado! Cap: " .. math.floor(freeCap),
                color   = "#FFA500",
                duration = 3000,
            })
        end
    else
        lastCapacityNotif = 0
    end

    -- 5) Safe Zone (PZ) - notifica entrada/saida
    local inPz = player:hasState(PlayerStates.Pz)
    if wasInPz ~= nil and inPz ~= wasInPz then
        if inPz then
            show({
                title   = "Area Segura",
                message = "Voce entrou em uma zona de protecao.",
                color   = "#32CD32",
                duration = 2500,
            })
        else
            show({
                title   = "Zona de Perigo!",
                message = "Voce saiu da zona de protecao!",
                color   = "#DC143C",
                duration = 2500,
            })
        end
    end
    wasInPz = inPz

    -- 7) Ring/Necklace alert: equipado fora de combate, a cada 12s
    local inCombat = player:hasState(PlayerStates.RedSwords) or player:hasState(PlayerStates.Swords)
    if inCombat then
        wasInCombat = true
        lastEquipNotif = 0  -- reset timer when entering combat
    else
        -- Acabou de sair do combate ou ja estava fora
        if wasInCombat or lastEquipNotif == 0 then
            wasInCombat = false
        end

        if now - lastEquipNotif >= 12 then
            local alerts = {}

            -- Check necklace first (InventorySlotNeck = 2)
            local neck = player:getInventoryItem(InventorySlotNeck)
            if neck then
                local neckId = neck:getId()
                if tableContains(ALERT_NECKLACE_IDS, neckId) then
                    table.insert(alerts, "Colar equipado! (ID: " .. neckId .. ")")
                end
            end

            -- Check ring (InventorySlotFinger = 9)
            local ring = player:getInventoryItem(InventorySlotFinger)
            if ring then
                local ringId = ring:getId()
                if tableContains(ALERT_RING_IDS, ringId) then
                    table.insert(alerts, "Anel equipado! (ID: " .. ringId .. ")")
                end
            end

            if #alerts > 0 then
                lastEquipNotif = now
                show({
                    title   = "Equipamento!",
                    message = table.concat(alerts, "\n"),
                    color   = "#FF69B4",
                    duration = 3500,
                })
            end
        end
    end
end

-- Helper: formata numeros com virgula
function comma_value(n)
    if not n then return "0" end
    local left, num, right = string.match(tostring(n), '^([^%d]*%d)((%d+).-)$')
    return left and (left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse())) or tostring(n)
end

-- ======== SHOW API ========
function show(opts)
    if not opts then return end
    print("[Notification] " .. (opts.title or "?") .. ": " .. (opts.message or ""))
    table.insert(queue, opts)
    if not isShowing then
        processQueue()
    end
end

function processQueue()
    if #queue == 0 then
        isShowing = false
        return
    end

    isShowing = true
    local opts = table.remove(queue, 1)
    displayNotification(opts)
end

function displayNotification(opts)
    clearTimers()

    if not mapPanel then
        mapPanel = modules.game_interface.getMapPanel()
    end
    if not mapPanel then return end

    -- Cria ou reutiliza o widget
    if not notifWidget then
        notifWidget = g_ui.createWidget('NotificationWidget', mapPanel)
    end

    if not notifWidget then return end

    local title   = opts.title or "Notificacao"
    local message = opts.message or ""
    local icon    = opts.icon or nil
    local color   = opts.color or "#FFD700"
    local duration = opts.duration or DEFAULT_DURATION

    -- Atualiza conteudo
    local titleLabel = notifWidget:getChildById('notifTitle')
    local msgLabel   = notifWidget:getChildById('notifMessage')
    local iconWidget = notifWidget:getChildById('notifIcon')
    local bgWidget   = notifWidget:getChildById('notifBg')

    if titleLabel then
        titleLabel:setText(title)
        titleLabel:setColor(color)
    end

    if msgLabel then
        msgLabel:setText(message)
    end

    -- Icone (opcional)
    if iconWidget then
        if icon then
            iconWidget:setImageSource(icon)
            iconWidget:setVisible(true)
            if titleLabel then titleLabel:setMarginLeft(52) end
            if msgLabel then msgLabel:setMarginLeft(52) end
        else
            iconWidget:setVisible(false)
            if titleLabel then titleLabel:setMarginLeft(16) end
            if msgLabel then msgLabel:setMarginLeft(16) end
        end
    end

    -- Cor da borda baseada na cor do titulo
    if bgWidget then
        bgWidget:setBorderColor(color .. "88")
    end

    -- Ajusta altura: conta linhas do texto para suportar ate 3 linhas
    local lineCount = 1
    for _ in message:gmatch("\n") do
        lineCount = lineCount + 1
    end
    -- Estima se o texto e longo o suficiente para wrap (mais de ~35 chars por linha)
    local estimatedWrapLines = math.ceil(#message / 35)
    if estimatedWrapLines > lineCount then
        lineCount = estimatedWrapLines
    end
    if lineCount > 3 then lineCount = 3 end
    local baseHeight = 70
    local extraPerLine = 16
    notifWidget:setHeight(baseHeight + (lineCount - 1) * extraPerLine)

    -- Fade in
    notifWidget:setOpacity(0.0)
    notifWidget:show()
    notifWidget:raise()
    fadeIn(function()
        hideEvent = scheduleEvent(function()
            fadeOut(function()
                notifWidget:hide()
                processQueue()
            end)
        end, duration)
    end)
end

function fadeIn(callback)
    local step = 0
    local interval = math.floor(FADE_IN_MS / FADE_STEPS)
    local function doStep()
        step = step + 1
        if not notifWidget then return end
        local alpha = step / FADE_STEPS
        if alpha > 1.0 then alpha = 1.0 end
        notifWidget:setOpacity(alpha)
        if step < FADE_STEPS then
            fadeEvent = scheduleEvent(doStep, interval)
        else
            fadeEvent = nil
            if callback then callback() end
        end
    end
    doStep()
end

function fadeOut(callback)
    local step = 0
    local interval = math.floor(FADE_OUT_MS / FADE_STEPS)
    local function doStep()
        step = step + 1
        if not notifWidget then return end
        local alpha = 1.0 - (step / FADE_STEPS)
        if alpha < 0 then alpha = 0 end
        notifWidget:setOpacity(alpha)
        if step < FADE_STEPS then
            fadeEvent = scheduleEvent(doStep, interval)
        else
            fadeEvent = nil
            if callback then callback() end
        end
    end
    doStep()
end
