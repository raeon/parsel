
local utils = require('utils')
local class = utils.class

local Token = require('ast.token')

local Tokenizer = {}

function Tokenizer:new(input, index)
    self.input = input
    self.index = index or 1

    self.prototypes = {} -- name => { fn, priority }
    self.current = nil
end

function Tokenizer:define(type, fn, prio)
    self.prototypes[type] = {
        fn = fn,
        prio = prio,
    }
end

function Tokenizer:next()
    self:forward()
    return self.current
end

function Tokenizer:peek()
    return self.following
end

function Tokenizer:forward()
    local bestToken, bestPrio, value

    -- Parse tokens until we find one that is not ignored (prio >= 0)
    while not self:isDone() do

        bestToken = nil
        bestPrio = nil

        -- Try every token type
        for type, proto in pairs(self.prototypes) do
            -- Only try it if it could have a higher priority than the current best
            if (not bestPrio) or proto.prio > bestPrio then
                value = proto.fn(self.input, self.index)
                if value then
                    bestToken = Token(type, value, self.index)
                    bestPrio = proto.prio
                end
            end
        end

        -- No match? EOF
        if not bestToken then
            break
        end

        -- Move the index forward on a match, but ignore the result
        -- if the priority is below zero.
        self.index = self.index + bestToken:len()
        if bestPrio >= 0 then
            break
        end
    end

    self.current = bestToken
end

function Tokenizer:isDone()
    return self.index > self.input:len()
end

return class(Tokenizer)
