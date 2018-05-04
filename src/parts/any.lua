
local utils = require('utils')
local indent = utils.indent
local outdent = utils.outdent
local map = utils.map
local times = utils.times

local State = require('state')
local Every = require('parts.every')

local Any = {}

function Any:new(name, ...)
    assert(type(name) == 'string')
    self.name = name
    self.children = {...}
    self:init()
end

function Any:add(child)
    table.insert(self.children, child)
    self:init()
end

function Any:init()
    self.states = {}
    self.versions = map(self.children, function(_, child)
        local sub = Every(self.name .. '-' .. tostring(child), child)
        --sub.parent = self
        --sub:init()
        return sub
    end)
end

function Any:buildClosures(visited)
    visited = visited or {}
    for _, version in pairs(self.versions) do
        version:buildClosures(visited)
    end
end

function Any:buildTables(visited, followers)
    visited = visited or {}
    followers = followers or {}
    for _, version in pairs(self.versions) do
        version:buildTables(visited, followers)
    end
end

function Any:mergeTables()
    if #self.versions > 0 then
        self.versions[1]:mergeTables()
    end
end

function Any:isTerminal()
    return false
end

function Any:__tostring()
    return self.name
end

return utils.class(Any)
