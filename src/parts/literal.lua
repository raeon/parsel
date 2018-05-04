
local utils = require('utils')
local times = utils.times
local each = utils.each
local format = utils.format
local class = utils.class

local State = require('state')
local Token = require('ast.token')

local Literal = {}

function Literal:new(name, value, priority)
    assert(type(name) == 'string')
    assert(type(value) == 'string')
    assert(type(priority) == 'nil' or type(priority) == 'number')
    self.name = name
    self.value = value
    self.priority = priority or 0

    self.children = {}
    self.states = times(2, function(i)
        return State(self, self.children[i], i)
    end)
end

function Literal:__call(input, index)
    if input:sub(index, index + self.value:len() - 1) == self.value then
        return self.value
    end
end

function Literal:buildClosures(visited)
end

function Literal:buildTables(visited, followers)
end

function Literal:isTerminal()
    return true
end

function Literal:__tostring()
    return self.name
end

return class(Literal)
