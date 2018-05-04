
local utils = require('utils')
local times = utils.times
local class = utils.class

local State = require('state')

local Every = {}

function Every:new(name, ...)
    assert(type(name) == 'string')
    self.name = name
    self.children = {...}
    self:init()
end

function Every:add(child)
    table.insert(self.children, child)
    self:init()
end

function Every:init()
    self.states = times(#self.children + 1, function(i)
        return State(self, self.children[i], i)
    end)
end

function Every:buildClosures(visited)
    visited = visited or {}
    for _, state in pairs(self.states) do
        state:buildClosures(visited)
    end
end

function Every:buildTables(visited, followers)
    visited = visited or {}
    followers = followers or {}
    for _, state in pairs(self.states) do
        state:buildTables(visited, followers)
    end
end

function Every:mergeTables()
    if #self.states > 0 then
        self.states[1]:mergeTables()
    end
end

function Every:isTerminal()
    return false
end

function Every:__tostring()
    return self.name
end

return class(Every)
