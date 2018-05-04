
local function map(tbl, fn)
    local t = {}
    for k,v in pairs(tbl) do
        t[k] = fn(k, v)
    end
    return t
end

local function keys(tbl)
    local t = {}
    for k in pairs(tbl) do
        table.insert(t, k)
    end
    return t
end

local function filter(tbl, fn)
    local t = {}
    for k,v in pairs(tbl) do
        if fn(k, v) then
            t[k] = v
        end
    end
    return t
end

local function count(tbl)
    local i = 0
    for k,v in pairs(tbl) do i = i + 1 end
    return i
end

local function contains(tbl, cv)
    for k,v in pairs(tbl) do
        if v == cv then
            return true
        end
    end
    return false
end

local function any(tbl, fn)
    for k,v in pairs(tbl) do
        if fn(k, v) then
            return true
        end
    end
    return false
end

local function reverse(tbl)
    local t = {}
    for i=1,#tbl,1 do
        t[#tbl - i + 1] = tbl[i]
    end
    return t
end

local function format(fmt, ...)
    local args = {...}
    return fmt:gsub('{([0-9]+)}', function(id)
        return tostring(args[tonumber(id) + 1])
    end)
end

local function push(tbl, v)
    local k = (#tbl or 0) + 1
    tbl[k] = v
    return k
end

local function pop(tbl)
    local k = #tbl
    local v = tbl[k]
    tbl[k] = nil
    return v
end

local function peek(tbl)
    return tbl[#tbl]
end

local function times(i, fn)
    local t = {}
    for j=1,i,1 do
        table.insert(t, fn(j))
    end
    return t
end

local function indexOf(tbl, i)
    for k,v in ipairs(tbl) do
        if v == i then
            return k
        end
    end
end

local function sub(tbl, i, j)
    local t = {}
    for k,v in ipairs(tbl) do
        if k >= j then
            if (not j) or (k <= j) then
                table.insert(t, v)
            end
        end
    end
    return t
end

local function copy(tbl)
    return map(tbl, function(k,v) return v end)
end

local function each(tbl, fn)
    local t = {}
    for k,v in pairs(tbl) do
        table.insert(t, fn(k, v))
    end
    return t
end

local function min(tbl, fn)
    local c = nil
    for k,v in pairs(tbl) do
        if c == nil then
            c = fn(k,v)
        else
            c = math.min(c, fn(k,v))
        end
    end
    return c
end

local function max(tbl, fn)
    local c = nil
    for k,v in pairs(tbl) do
        if c == nil then
            c = fn(k,v)
        else
            c = math.max(c, fn(k,v))
        end
    end
    return c
end

local function mergeValues(dest, src)
    for _,v in pairs(src) do
        if not contains(dest, nil, v) then
            table.insert(dest, v)
        end
    end
end

local function class(proto)
    -- load metafunctions
    local meta = { __index = proto }
    for k,v in pairs(filter(proto, function(k) return k:find('__') == 1 end)) do
        meta[k] = v;
    end

    -- return initializer
    return setmetatable(proto, {
        __call = function(cls, ...)
            local inst = setmetatable({}, meta)
            cls.new(inst, ...)
            return inst
        end
    })
end

local function indent()
    _G.__indent = (_G.__indent or 0) + 1
end

local function outdent()
    _G.__indent = math.max(0, _G.__indent - 1) or 0
end

local function logger()
    if _G.__logger then return end
    _G.__logger = true
    _G.__print = print

    local _print = print
    _G.print = function(...)
        local str = table.concat(map({...}, function(k,v) return tostring(v) end), '\t')
        local whitespace = string.rep('|  ', _G.__indent or 0)
        str = whitespace .. str:gsub('\n', '\n' .. whitespace)
        _print(str)
    end
end

return setmetatable({
    map = map,
    keys = keys,
    filter = filter,
    contains = contains,
    any = any,
    reverse = reverse,
    format = format,
    min = min,
    max = max,
    push = push,
    pop = pop,
    peek = peek,
    times = times,
    count = count,
    indexOf = indexOf,
    sub = sub,
    copy = copy,
    each = each,
    indent = indent,
    outdent = outdent,
    logger = logger,
    mergeValues = mergeValues,
    class = class
}, {
    __call = function(src, dest)
        src:import(dest)
    end
})
