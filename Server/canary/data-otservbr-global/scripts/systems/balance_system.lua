-- ===========================================================================
-- BALANCE SYSTEM
-- Opcode 191: cliente solicita gold na bag + saldo no banco a cada 3s
-- ===========================================================================

local OPCODE = 191

local BalanceExtended = CreatureEvent("BalanceExtended")
BalanceExtended:type("extendedopcode")

function BalanceExtended.onExtendedOpcode(player, opcode, buffer)
    if opcode ~= OPCODE then return end

    local gold = player:getMoney()
    local bank = player:getBankBalance()

    -- Canary não expõe sendExtendedJSONOpcode nem uma lib "json" nativa,
    -- então montamos o payload JSON manualmente (são só 2 números, é simples)
    local payload = string.format('{"gold":%d,"bank":%d}', gold, bank)

    local msg = NetworkMessage()
    msg:addByte(0x32) -- header do pacote de extended opcode (client<->server)
    msg:addByte(OPCODE)
    msg:addString(payload)
    msg:sendToPlayer(player)
    msg:delete()
end

BalanceExtended:register()

local BalanceLogin = CreatureEvent("BalanceLogin")
BalanceLogin:type("login")

function BalanceLogin.onLogin(player)
    player:registerEvent("BalanceExtended")
    return true
end

BalanceLogin:register()