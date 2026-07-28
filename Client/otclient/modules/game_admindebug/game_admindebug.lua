local panel = nil
local adminButton = nil

local OPCODE = 192

-- Envia comando ao servidor via opcode 192
function sendCmd(cmd, extra)
    if not g_game.isOnline() then return end
    local protocol = g_game.getProtocolGame()
    if not protocol then return end
    local payload = { cmd = cmd }
    if extra then
        for k, v in pairs(extra) do payload[k] = v end
    end
    protocol:sendExtendedJSONOpcode(OPCODE, payload)
end

function init()
    panel = g_ui.displayUI('game_admindebug')
    panel:hide()

    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onGMActions = updateAdminButton
    })
    ProtocolGame.registerExtendedJSONOpcode(OPCODE, onReceive)

    if modules.game_mainpanel then
        adminButton = modules.game_mainpanel.addToggleButton(
            'adminDebugButton',
            tr('Admin Debug'),
            '/game_admindebug/images/menubutton_debugIcon',
            togglePanel,
            false,
            99
        )
        if adminButton then
            adminButton:setVisible(false)
        end
    end

    if g_game.isOnline() then onGameStart() end
end

function terminate()
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd,
        onGMActions = updateAdminButton
    })
    ProtocolGame.unregisterExtendedJSONOpcode(OPCODE, onReceive)
    if adminButton then adminButton:destroy(); adminButton = nil end
    if panel then panel:destroy(); panel = nil end
end

function updateAdminButton()
    if not adminButton then return end
    local actions = g_game.getGMActions()
    if actions and next(actions) ~= nil then
        adminButton:setVisible(true)
    end
end

function onGameStart()
    updateAdminButton()
    sendCmd('checkAccess')
end

function onGameEnd()
    if panel then panel:hide() end
    if adminButton then
        adminButton:setOn(false)
        adminButton:setVisible(false)
    end
end

function onReceive(protocol, opcode, data)
    if type(data) == "table" and data.cmd == "accessResult" then
        if adminButton then
            adminButton:setVisible(data.allowed == true)
        end
        if not data.allowed and panel and panel:isVisible() then
            hide()
        end
    end
end

function show()
    if panel then panel:show(); panel:raise(); panel:focus() end
    if adminButton then adminButton:setOn(true) end
end

function hide()
    if panel then panel:hide() end
    if adminButton then adminButton:setOn(false) end
end

function togglePanel()
    if panel and panel:isVisible() then
        hide()
    else
        show()
    end
end



local function getField(id)
    if not panel then return nil end
    return panel:getChildById(id)
end

local function readText(id, default)
    local w = getField(id)
    if w then
        local t = w:getText()
        if t and #t > 0 then return t end
    end
    return default or ''
end

local function readNumber(id, default)
    local w = getField(id)
    if w then
        local n = tonumber(w:getText())
        if n then return math.floor(n) end
    end
    return default or 0
end

local function targetName()
    return readText('fieldTargetPlayer', '')
end

function cmdAddXp()
    sendCmd('addXp', { value = readNumber('fieldXpAmount', 1000000) })
end

function cmdAddBoost()
    sendCmd('addBoost', { value = readNumber('fieldBoostMinutes', 30) })
end

function cmdAddBank()
    sendCmd('addBank', { value = readNumber('fieldBankAmount', 100000) })
end

function cmdGoTo()
    sendCmd('goTo', { value = readText('fieldCityName', 'Thais') })
end

function cmdTpToPlayer()
    sendCmd('tpToPlayer', { value = readText('fieldTpPlayerName', '') })
end

function cmdAddPreyCards()
    sendCmd('addPreyCards', { value = readNumber('fieldPreyAmount', 10) })
end

function cmdAddTaskPoints()
    sendCmd('addTaskPoints', { value = readNumber('fieldTaskAmount', 100) })
end

function cmdDarItemMe()
    sendCmd('darItemMe', {
        itemId  = readNumber('fieldItemIdMe', 2160),
        itemQty = readNumber('fieldItemQtyMe', 1)
    })
end

function cmdInvocarMonstro()
    sendCmd('invocarMonstro', {
        value = readText('fieldMonsterName', 'Rat'),
        qty   = readNumber('fieldMonsterQty', 1)
    })
end

function cmdAddMountMe()
    sendCmd('addMount', { value = readText('fieldMountMe', 'all') })
end

function cmdAddSkillMe()
    sendCmd('addSkill', {
        skill = readText('fieldSkillTypeMe', 'level'),
        qty   = readNumber('fieldSkillAmtMe', 1)
    })
end

function cmdAddCharmMe()
    sendCmd('addCharm', { value = readNumber('fieldCharmMe', 1000) })
end

function cmdGoToHouseMe()
    sendCmd('goToHouse', { value = readText('fieldGoToHouseMe', '') })
end

function cmdClearXpBoost()
    sendCmd('clearXpBoost')
end

function cmdRestoreHpMp()
    sendCmd('restoreHpMp')
end

function cmdClearConditions()
    sendCmd('clearConditions')
end

function cmdFullBless()
    sendCmd('fullBless')
end

function cmdRemoveBless()
    sendCmd('removeBless')
end

function cmdClearBank()
    sendCmd('clearBank')
end

function cmdSave()
    sendCmd('save')
end

function cmdReload()
    sendCmd('reload', { value = readText('fieldReloadType', 'scripts') })
end

function cmdCloseServer()
    sendCmd('closeServer')
end

function cmdOpenServer()
    sendCmd('openServer')
end

function cmdBroadcast()
    sendCmd('broadcast', { value = readText('fieldBroadcast', '') })
end

function cmdGhost()
    sendCmd('ghost')
end

function cmdIpBan()
    sendCmd('ipBan', { value = readText('fieldIpBan', '') })
end

function cmdUnban()
    sendCmd('unban', { value = readText('fieldUnban', '') })
end

function cmdKick()
    sendCmd('kick', { value = readText('fieldKick', '') })
end

function cmdSpy()
    sendCmd('spy', { value = readText('fieldSpy', '') })
end

function cmdDarItemPlayer()
    sendCmd('darItemPlayer', {
        target  = targetName(),
        itemId  = readNumber('fieldItemIdPlayer', 2160),
        itemQty = readNumber('fieldItemQtyPlayer', 1)
    })
end

function cmdDarXpPlayer()
    sendCmd('darXpPlayer', { target = targetName(), value = readNumber('fieldXpPlayer', 1000000) })
end

function cmdBoostPlayer()
    sendCmd('addBoostPlayer', { target = targetName(), value = readNumber('fieldBoostPlayer', 30) })
end

function cmdPreyPlayer()
    sendCmd('addPreyPlayer', { target = targetName(), value = readNumber('fieldPreyPlayer', 10) })
end

function cmdTaskPlayer()
    sendCmd('addTaskPlayer', { target = targetName(), value = readNumber('fieldTaskPlayer', 100) })
end

function cmdAddBankPlayer()
    sendCmd('addBankPlayer', { target = targetName(), value = readNumber('fieldBankPlayer', 100000) })
end

function cmdAddMountPlayer()
    sendCmd('addMountPlayer', { target = targetName(), value = readText('fieldMountPlayer', 'all') })
end

function cmdAddSkillPlayer()
    sendCmd('addSkillPlayer', {
        target = targetName(),
        skill  = readText('fieldSkillTypePlayer', 'level'),
        qty    = readNumber('fieldSkillAmtPlayer', 1)
    })
end

function cmdAddCharmPlayer()
    sendCmd('addCharmPlayer', { target = targetName(), value = readNumber('fieldCharmPlayer', 1000) })
end

function cmdGoToHousePlayer()
    sendCmd('goToHousePlayer', { target = targetName(), value = readText('fieldGoToHousePlayer', '') })
end

function cmdTpToMe()
    sendCmd('tpToMe', { target = targetName() })
end

function cmdClearXpBoostPlayer()
    sendCmd('clearXpBoostPlayer', { target = targetName() })
end

function cmdRestoreHpMpPlayer()
    sendCmd('restoreHpMpPlayer', { target = targetName() })
end

function cmdClearConditionsPlayer()
    sendCmd('clearConditionsPlayer', { target = targetName() })
end

function cmdFullBlessPlayer()
    sendCmd('fullBlessPlayer', { target = targetName() })
end

function cmdRemoveBlessPlayer()
    sendCmd('removeBlessPlayer', { target = targetName() })
end

function cmdClearBankPlayer()
    sendCmd('clearBankPlayer', { target = targetName() })
end
function cmdAddXp()
    sendCmd('addXp', { value = readNumber('fieldXpAmount', 1000000) })
end

function cmdAddBoost()
    sendCmd('addBoost', { value = readNumber('fieldBoostMinutes', 30) })
end

function cmdAddBank()
    sendCmd('addBank', { value = readNumber('fieldBankAmount', 100000) })
end

function cmdGoTo()
    sendCmd('goTo', { value = readText('fieldCityName', 'Thais') })
end
