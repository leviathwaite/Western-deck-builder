-- Minimal JSON decoder adapted for simple project data files.
-- Supports objects, arrays, strings, numbers, booleans, and null.

local json = {}

local function decodeError(str, idx, msg)
    error("JSON decode error at position " .. tostring(idx) .. ": " .. msg .. " near '" .. str:sub(idx, idx + 20) .. "'")
end

local function skipWhitespace(str, idx)
    while true do
        local c = str:sub(idx, idx)
        if c == " " or c == "\n" or c == "\r" or c == "\t" then
            idx = idx + 1
        else
            return idx
        end
    end
end

local parseValue

local function parseString(str, idx)
    idx = idx + 1
    local result = ""
    while idx <= #str do
        local c = str:sub(idx, idx)
        if c == '"' then
            return result, idx + 1
        elseif c == "\\" then
            local nextc = str:sub(idx + 1, idx + 1)
            local map = {
                ['"'] = '"', ['\\'] = '\\', ['/'] = '/',
                ['b'] = '\b', ['f'] = '\f', ['n'] = '\n', ['r'] = '\r', ['t'] = '\t'
            }
            if not map[nextc] then
                decodeError(str, idx, "invalid escape")
            end
            result = result .. map[nextc]
            idx = idx + 2
        else
            result = result .. c
            idx = idx + 1
        end
    end
    decodeError(str, idx, "unterminated string")
end

local function parseNumber(str, idx)
    local startIdx = idx
    while str:sub(idx, idx):match("[%d%+%-%eE%.]") do
        idx = idx + 1
    end
    local num = tonumber(str:sub(startIdx, idx - 1))
    if num == nil then
        decodeError(str, startIdx, "invalid number")
    end
    return num, idx
end

local function parseArray(str, idx)
    idx = idx + 1
    local result = {}
    idx = skipWhitespace(str, idx)
    if str:sub(idx, idx) == "]" then
        return result, idx + 1
    end
    while true do
        local value
        value, idx = parseValue(str, idx)
        table.insert(result, value)
        idx = skipWhitespace(str, idx)
        local c = str:sub(idx, idx)
        if c == "]" then
            return result, idx + 1
        elseif c ~= "," then
            decodeError(str, idx, "expected ',' or ']' in array")
        end
        idx = skipWhitespace(str, idx + 1)
    end
end

local function parseObject(str, idx)
    idx = idx + 1
    local result = {}
    idx = skipWhitespace(str, idx)
    if str:sub(idx, idx) == "}" then
        return result, idx + 1
    end
    while true do
        if str:sub(idx, idx) ~= '"' then
            decodeError(str, idx, "expected string key")
        end
        local key
        key, idx = parseString(str, idx)
        idx = skipWhitespace(str, idx)
        if str:sub(idx, idx) ~= ":" then
            decodeError(str, idx, "expected ':' after key")
        end
        idx = skipWhitespace(str, idx + 1)
        local value
        value, idx = parseValue(str, idx)
        result[key] = value
        idx = skipWhitespace(str, idx)
        local c = str:sub(idx, idx)
        if c == "}" then
            return result, idx + 1
        elseif c ~= "," then
            decodeError(str, idx, "expected ',' or '}' in object")
        end
        idx = skipWhitespace(str, idx + 1)
    end
end

parseValue = function(str, idx)
    idx = skipWhitespace(str, idx)
    local c = str:sub(idx, idx)
    if c == '"' then
        return parseString(str, idx)
    elseif c == "{" then
        return parseObject(str, idx)
    elseif c == "[" then
        return parseArray(str, idx)
    elseif c == "-" or c:match("%d") then
        return parseNumber(str, idx)
    elseif str:sub(idx, idx + 3) == "true" then
        return true, idx + 4
    elseif str:sub(idx, idx + 4) == "false" then
        return false, idx + 5
    elseif str:sub(idx, idx + 3) == "null" then
        return nil, idx + 4
    end
    decodeError(str, idx, "unexpected character")
end

function json.decode(str)
    local result, idx = parseValue(str, 1)
    idx = skipWhitespace(str, idx)
    if idx <= #str then
        decodeError(str, idx, "trailing garbage")
    end
    return result
end

return json
