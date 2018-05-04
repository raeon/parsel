
local utils = require('utils')
local format = utils.format
local class = utils.class

local Token = {}

function Token:new(type, value, index)
    self.type = type
    self.value = value
    self.index = index
end

function Token:len()
    return #self.value
end

function Token:__tostring()
    return format('Token({0}, "{1}", {2})', tostring(self.type), self.value, self.index)
end

return class(Token)
