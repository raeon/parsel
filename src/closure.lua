
local utils = require('utils')
local indent = utils.indent
local outdent = utils.outdent
local contains = utils.contains
local each = utils.each
local format = utils.format
local count = utils.count
local copy = utils.copy
local pop = utils.pop
local peek = utils.peek
local indexOf = utils.indexOf
local sub = utils.sub
local class = utils.class

local PENDING = 1
local WAITING = 2
local DONE = 3

local Closure = {}

function Closure:new(state)
    self.state = state
    self.children = {}
    self.finalized = nil

    self.waitingFor = {}
    self.dependants = {}
end

function Closure:add(part)
    if part.versions then
        print('Closure: Adding versions')
        for _, version in pairs(part.versions) do
            self:add(version)
        end
    else
        local state = part.states[1]
        indent()

        if state and not contains(self.children, state.closure) then
            print('Adding child:', state)
            table.insert(self.children, state.closure)
        end
        outdent()
    end
end

function Closure:addChild(child)
    if contains(self.children, child) then
        return false
    end
    table.insert(self.children, child)
    return true
end

function Closure:getStates(states)
    states = states or {}

    -- Prevent recursion
    if states[self.state] then return end

    -- Add our own state
    states[self.state] = true

    -- Add our child states
    for _, child in pairs(self.children) do
        child:getStates(states)
    end

    return states
end

function Closure:import(child)
    -- Import all finalized states from the child into ourselves.
    for state in pairs(child.finalized) do
        self.finalized[state] = true
    end
end

function Closure:export(child)
    child:import(self)
end

function Closure:merge(states)
    -- We merge this closure with the given states table.
    for state in pairs(self.finalized) do
        states[state] = true
    end
    for state in pairs(states) do
        self.finalized[state] = true
    end
end

function Closure:depend(other)
    self.waitingFor[other] = true
    other.dependants[self] = true
end

function Closure:resolve(depend)
    -- Do nothing if "depend" is not one of our dependencies
    if not self.waitingFor[depend] then
        return
    end

    -- Remove this dependency
    self.waitingFor[depend] = nil
    self:import(depend)

    -- Resolve our depentants if possible
    if #self.waitingFor == 0 then
        for i, dependant in pairs(self.dependants) do
            dependant:resolve(self)
        end
    end
end

function Closure:__tostring()
    local states = self:getStates()
    return format('Closure({1}, {0})', table.concat(each(states, function(state)
        return '\n\t' .. tostring(state)
    end), ''), count(states))
end

return class(Closure)
