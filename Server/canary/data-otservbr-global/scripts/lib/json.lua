-- ===========================================================================
-- JSON LIB (pura Lua, sem dependencias externas)
-- Expoe a global `json` com json.encode(value) e json.decode(str)
-- Canary nao inclui uma lib json nativa para scripts, entao isso preenche
-- essa lacuna para todo o datapack (extended opcodes, etc).
--
-- Coloque este arquivo em: data-otservbr-global/scripts/lib/json.lua
-- (a pasta "lib" carrega antes de "systems" alfabeticamente, garantindo
-- que a global `json` ja exista quando outros scripts rodarem)
-- ===========================================================================

json = {}

-- ---------------------------------------------------------------------------
-- ENCODE
-- ---------------------------------------------------------------------------

local encodeValue -- forward declaration

local function encodeString(s)
    local escapes = {
        ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b',
        ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
    }
    local out = s:gsub('[%c"\\]', function(c)
        return escapes[c] or string.format('\\u%04x', c:byte())
    end)
    return '"' .. out .. '"'
end

local function isArray(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    for i = 1, n do
        if t[i] == nil then return false end
    end
    return n > 0
end

encodeValue = function(v)
    local vType = type(v)
    if vType == "string" then
        return encodeString(v)
    elseif vType == "number" then
        if v ~= v or v == math.huge or v == -math.huge then
            return "null" -- NaN/Inf nao existem em JSON
        end
        return tostring(v)
    elseif vType == "boolean" then
        return tostring(v)
    elseif vType == "nil" then
        return "null"
    elseif vType == "table" then
        if isArray(v) then
            local parts = {}
            for i = 1, #v do
                parts[i] = encodeValue(v[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, val in pairs(v) do
                parts[#parts + 1] = encodeString(tostring(k)) .. ":" .. encodeValue(val)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    error("json.encode: tipo nao suportado: " .. vType)
end

function json.encode(value)
    return encodeValue(value)
end

-- ---------------------------------------------------------------------------
-- DECODE
-- ---------------------------------------------------------------------------

local function skipWhitespace(str, pos)
    local _, newPos = str:find("^%s*", pos)
    return newPos + 1
end

local decodeValue -- forward declaration

local function decodeError(str, pos, msg)
    error(string.format("json.decode: %s na posicao %d (%s)", msg, pos, str:sub(math.max(1, pos - 10), pos + 10)))
end

local function decodeString(str, pos)
    local startPos = pos + 1
    local out = {}
    local i = startPos
    while true do
        local c = str:sub(i, i)
        if c == "" then
            decodeError(str, i, "string nao terminada")
        elseif c == '"' then
            return table.concat(out), i + 1
        elseif c == "\\" then
            local nextC = str:sub(i + 1, i + 1)
            local escapes = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
            if nextC == "u" then
                local hex = str:sub(i + 2, i + 5)
                out[#out + 1] = utf8 and utf8.char(tonumber(hex, 16)) or ("\\u" .. hex)
                i = i + 6
            elseif escapes[nextC] then
                out[#out + 1] = escapes[nextC]
                i = i + 2
            else
                decodeError(str, i, "escape invalido")
            end
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
end

local function decodeNumber(str, pos)
    local numStr = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
    if not numStr or numStr == "" then
        decodeError(str, pos, "numero invalido")
    end
    return tonumber(numStr), pos + #numStr
end

local function decodeObject(str, pos)
    local obj = {}
    pos = skipWhitespace(str, pos + 1)
    if str:sub(pos, pos) == "}" then return obj, pos + 1 end
    while true do
        pos = skipWhitespace(str, pos)
        if str:sub(pos, pos) ~= '"' then
            decodeError(str, pos, "esperava chave string")
        end
        local key
        key, pos = decodeString(str, pos)
        pos = skipWhitespace(str, pos)
        if str:sub(pos, pos) ~= ":" then
            decodeError(str, pos, "esperava ':'")
        end
        pos = skipWhitespace(str, pos + 1)
        local value
        value, pos = decodeValue(str, pos)
        obj[key] = value
        pos = skipWhitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == "," then
            pos = skipWhitespace(str, pos + 1)
        elseif c == "}" then
            return obj, pos + 1
        else
            decodeError(str, pos, "esperava ',' ou '}'")
        end
    end
end

local function decodeArray(str, pos)
    local arr = {}
    pos = skipWhitespace(str, pos + 1)
    if str:sub(pos, pos) == "]" then return arr, pos + 1 end
    while true do
        pos = skipWhitespace(str, pos)
        local value
        value, pos = decodeValue(str, pos)
        arr[#arr + 1] = value
        pos = skipWhitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == "," then
            pos = skipWhitespace(str, pos + 1)
        elseif c == "]" then
            return arr, pos + 1
        else
            decodeError(str, pos, "esperava ',' ou ']'")
        end
    end
end

decodeValue = function(str, pos)
    pos = skipWhitespace(str, pos)
    local c = str:sub(pos, pos)
    if c == '"' then
        return decodeString(str, pos)
    elseif c == "{" then
        return decodeObject(str, pos)
    elseif c == "[" then
        return decodeArray(str, pos)
    elseif c == "t" and str:sub(pos, pos + 3) == "true" then
        return true, pos + 4
    elseif c == "f" and str:sub(pos, pos + 4) == "false" then
        return false, pos + 5
    elseif c == "n" and str:sub(pos, pos + 3) == "null" then
        return nil, pos + 4
    elseif c == "-" or c:match("%d") then
        return decodeNumber(str, pos)
    else
        decodeError(str, pos, "valor inesperado")
    end
end

function json.decode(str)
    if type(str) ~= "string" then
        error("json.decode: esperava string, recebeu " .. type(str))
    end
    local value = decodeValue(str, 1)
    return value
end