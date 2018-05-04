
local utils = require('utils')
local format = utils.format
local map = utils.map
local class = utils.class

local Node = {}

function Node:new(name, ...)
    self.name = name
    self.children = {...}
end

function Node:len()
    local i = 0
    for _, child in pairs(self.children) do
        i = i + child:len()
    end
    return i
end

function Node:__tostring()
    return format('Node({0}, {1})', self.name, table.concat(map(self.children, function(_, child)
        return tostring(child)
    end), ', '))
end

return class(Node)
