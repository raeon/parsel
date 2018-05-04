
local utils = require('utils')

-- Parts
local Any = require('parts.any')
local Literal = require('parts.literal')
local Pattern = require('parts.pattern')

local Grammar = {}

function Grammar:new()
    self.terminals = {}
    self.nonterminals = {}
end

--[[
    Terminals
]]

function Grammar:terminal(term)
    if self.terminals[term.name] then
        error('Terminal already exists: ' .. term.name)
    end

    self.terminals[term.name] = term
    return term
end

function Grammar:literal(name, value)
    return self:terminal(Literal(name, value))
end

function Grammar:pattern(name, value)
    return self:terminal(Pattern(name, value))
end

--[[
    Nonterminals
]]

function Grammar:rule(name)
    
end


return utils.class(Grammar)
