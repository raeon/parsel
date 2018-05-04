
local utils = require('utils')
local times = utils.times
local each = utils.each
local format = utils.format
local class = utils.class

local State = require('state')
local Node = require('ast.node')
local Token = require('ast.token')

local Pattern = {}

function Pattern:new(name, value, priority)
    assert(type(name) == 'string')
    assert(type(value) == 'string')
    assert(type(priority) == 'nil' or type(priority) == 'number')
    self.name = name
    self.value = value
    self.priority = priority or 0

    self.children = {}
    self.states = {}
    -- self.children = { self }
    -- self.states = times(2, function(i)
    --     return State(self, self.children[i], i)
    -- end)
end

function Pattern:__call(input, index)
    input = input:sub(index)
    local first, last = input:find(self.value)
    if first == 1 then
        return input:sub(first, last)
    end
end

function Pattern:buildClosures(visited)
end

function Pattern:buildTables(visited, followers)
end

function Pattern:isTerminal()
    return true
end

function Pattern:__tostring()
    return self.name
end

return class(Pattern)
