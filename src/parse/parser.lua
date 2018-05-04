
local utils = require('utils')
local each = utils.each
local push = utils.push
local pop = utils.pop
local peek = utils.peek
local times = utils.times
local indent = utils.indent
local outdent = utils.outdent
local format = utils.format
local class = utils.class

local every = require('parts.every')
local Tokenizer = require('parse.tokenizer')
local Node = require('ast.node')

local Parser = {}

local function printStates(obj, visited)
    visited = visited or {}
    if visited[obj] then return end
    visited[obj] = true

    print('object: ' .. tostring(obj))
    indent()

    if obj.versions then
        for _, version in pairs(obj.versions) do
            print('version: ' .. tostring(version))
            indent()
            printStates(version)
            outdent()
        end
        outdent()
        return
    end

    for _, state in pairs(obj.states) do
        print('state: ' .. tostring(state))
        indent()
        print('closure: ' .. tostring(state.closure))
        for symbol, to in pairs(state.lookaheads) do
            if to.shift then
                print(symbol, ' => shift ', tostring(to.shift))
                indent()
                printStates(to.shift.part, visited)
                outdent()
            else
                print(symbol, ' => reduce ', tostring(to.reduce))
                indent()
                printStates(to.reduce, visited)
                outdent()
            end
        end
        for symbol, to in pairs(state.gotos) do
            print(symbol, ' => goto ', tostring(to))
            indent()
            printStates(to.part, visited)
            outdent()
        end
        outdent()
    end
    outdent()
end

function Parser:new(part)
    self.part = every('root', assert(part))
    print()
    self.part:buildClosures({})
    print()
    self.part:buildTables()
    print()
    self.part:mergeTables()
    print()
    printStates(self.part)
    print()
end

function Parser:__call(input, index)
    -- Begin parsing!
    return self:parse(self:getTokenizer(input, index))
end

function Parser:getTokenizer(input, index)
    local tokenizer = Tokenizer(input, index)

    -- Register all terminal symbols as tokens
    local remaining = { self.part }
    local visited = {}
    while #remaining > 0 do
        local cur = pop(remaining)
        visited[cur] = true

        if cur:isTerminal() then
            tokenizer:define(cur, cur, cur.priority)
        elseif cur.versions then
            for _, version in pairs(cur.versions) do
                if not visited[version] then
                    push(remaining, version)
                end
            end
        else
            for _, state in pairs(cur.states) do
                if not visited[state.child] then
                    push(remaining, state.child)
                end
            end
        end
    end

    return tokenizer
end

function Parser:parse(tokenizer)
    print()

    local state = self.part.states[1]
    local states = {}
    local products = {}

    -- Fetch the first token and our action
    local token = tokenizer:next()
    local action = state.lookaheads[token.type]

    print()

    -- Loop until we run out of things to do
    while true do

        -- Handle nil token
        if not state then
            break
        end

        -- Handle unexpected tokens
        if not action then
            return nil, format('Unexpected token "{0}" in state {1}.', tostring(token), tostring(state))
        end

        print()
        print()
        print('Current state:', state)
        print('Current token:', token)
        print('Current closure:', state.closure)
        print('\tLookaheads: ' .. table.concat(each(state.lookaheads, function(k, v)
            return '\n\t\t' .. tostring(k) .. ' => ' ..
                (v.shift and 'shift' or 'reduce') .. ' ' .. tostring(v.shift or v.reduce)
        end), ''))
        print('\tGotos: ' .. table.concat(each(state.gotos, function(k, v)
            return '\n\t\t' .. tostring(k) .. ' => ' .. tostring(v)
        end), ''))

        -- Perform the action
        if action.shift then
            -- Shift

            print('Shifting token:', token)
            push(products, token)

            token = tokenizer:next()
            print('Next token:', token)

            push(states, state)
            state = action.shift
            print('New state:', state)
            print('\tLookaheads: ' .. table.concat(each(state.lookaheads, function(k, v)
                return '\n\t\t' .. tostring(k) .. ' => ' ..
                    (v.shift and 'shift' or 'reduce') .. ' ' .. tostring(v.shift or v.reduce)
            end), ''))
            print('\tGotos: ' .. table.concat(each(state.gotos, function(k, v)
                return '\n\t\t' .. tostring(k) .. ' => ' .. tostring(v)
            end), ''))

            action = state.lookaheads[token and token.type] or state.lookaheads['any']
            print('Next shift:', action.shift)
            print('Next reduce:', action.reduce)
        elseif action.reduce then
            -- Reduce
            print('Reducing by:', action.reduce)

            -- First, remove the symbols for this production.
            local amount = #action.reduce.children
            local symbols = times(amount, function() return pop(products) end)
            print('Consuming', amount, 'symbol(s)')

            -- Next, apply the current production.
            local key = state.part
            local result = Node(state.part.name, unpack(symbols))
            print('Reduced:', result)

            -- Return to the state that was expecting this production.
            state = peek(states)
            print('Lookup state:', state)

            -- Push this production onto the result stack
            push(products, result)

            -- The previous state tells us what the next state is
            -- after producing the given production.
            print('\tGotos: \n' .. table.concat(each(state.gotos, function(k, v)
                return '\t\t' .. tostring(k) .. ' => ' .. tostring(v)
            end), '\n'))
            print('Actual key:', key)
            state = state.gotos[key]
        end

    end

    -- Validate success
    assert(#products == 1, 'Multiple products remain on the parse stack')
    if true then
        return products[1], nil
    end

    --[[
        END OF NEW CODE
    ]]

    self.token = nil
    self.table = nil
    self.state = assert(self.part.states[1])
    self.states = {}
    self.products = {}

    -- The last state in the main production is the 'done' state.
    --local done = assert(peek(self.part.states))
    --done.lookaheads['eof'] = { done = true }
    --print('Adding EOF lookahead to:', done)

    print()

    -- Parse first terminal
    self:next()

    -- Loop until we exit
    while self.state do
        if not self.state.lookaheads then
            error('no lookaheads in state ' .. tostring(self.state))
        end

        -- If there is no table, error?
        if not self.table then
            return nil, format('Unrecognized token {0} on line {1}.\nExpected one of the following: {2}',
                tostring(self.token):upper(),
                self:line(),
                table.concat(each(self.state.lookaheads, function(k)
                    return tostring(k):upper()
                end), ', '))
        end

        print()
        print('Current state:', self.state)
        print('\tLookaheads: \n' .. table.concat(each(self.state.lookaheads, function(k, v)
            return '\t\t' .. tostring(k) .. ' => ' ..
                (v.shift and 'shift' or 'reduce') .. ' ' .. tostring(v.shift or v.reduce)
        end), '\n'))
        print('\tGotos: \n' .. table.concat(each(self.state.gotos, function(k, v)
            return '\t\t' .. tostring(k) .. ' => ' .. tostring(v)
        end), '\n'))
        print('Current token:', self.token)
        print('Current shift:', self.table.shift)
        print('Current reduce:', self.table.reduce)
        print('Current done:', self.table.done)
        print()

        if self.table.done then
            print('done')
            break
        elseif self.table.shift then
            local err = self:shift()
            if err then return nil, err end
        elseif self.table.reduce then
            self:reduce()
        end
    end

    -- for _, product in pairs(self.products) do
    --     print('product', product)
    -- end
    -- for _, product in pairs(self.states) do
    --     print('state', product)
    -- end
    assert(#self.products == 1)
    assert(#self.states == 0)
    assert(self.products[1].name == self.part.name)

    return pop(self.products), nil
end

function Parser:shift()
    -- Push our state and the symbol onto the stacks
    push(self.states, self.state)
    push(self.products, self.token)

    -- Grab the new state
    self.state = self.table.shift
    self.index = self.index + self.token:len()
    print('Shifting terminal:', self.token)
    print('Shifted to state:', self.state)

    -- And read the next token
    return self:next()
end

function Parser:reduce()
    print('Reducing:', self.table.reduce)
    -- Grab the inputs for the resulting symbol
    local amount = #self.table.reduce.children
    local args = times(amount, function() return pop(self.products) end)

    -- Perform the reduction
    local symbol = Node(self.table.reduce.name, unpack(args))
    push(self.products, symbol)
    print('Symbol:\t', symbol)

    -- Go back to our previous state
    self.state = self.table.next
    print('Now at state:', self.state)
    print('\tLookaheads: \n' .. table.concat(each(self.state.lookaheads, function(k, v)
        return '\t\t' .. tostring(k) .. ' => ' ..
            (v.shift and 'shift' or 'reduce') .. ' ' .. tostring(v.shift or v.reduce)
    end), '\n'))
    print('\tGotos: \n' .. table.concat(each(self.state.gotos, function(k, v)
        return '\t\t' .. tostring(k) .. ' => ' .. tostring(v)
    end), '\n'))

    if not self.state then
        print('No previous state')
    else
        -- Lookup the result in the new current state's goto table
        local next = self.state.gotos[self.table.reduce]
        push(self.states, self.state)
        self.state = next
        print('Goto:', next)
    end

end

function Parser:next()
    -- Handle EOF
    if self.index > self.input:len() then
        print('Eof')
        self.token = 'eof'
    end

    -- Handle EOF
    if self.token == 'eof' then
        self.table = self.state.lookaheads['eof']
        return
    end

    -- Parse terminal
    print('Looking for terminal in state:', self.state)
    for symbol, table in pairs(self.state.lookaheads) do
        if symbol.isTerminal and symbol:isTerminal() then
            print('found potential terminal symbol:', symbol)
            local token = symbol(self.input, self.index)
            if token then
                self.token = token
                self.table = table
                print('Encountered terminal:', token)
                return
            end
        end
    end

    -- Handle 'any'
    if self.state.lookaheads['any'] then
        print('Any lookahead')
        self.table = self.state.lookaheads['any']
        return
    end

    -- If we didn't find a terminal symbol we throw an error.
    return format('Unexpected token near "{0}" on line {1}.\nExpected one of the following: {2}',
        self.input:sub(self.index):sub(1, 20),
        self:line(),
        table.concat(each(self.state.lookaheads, function(k)
            return tostring(k):upper()
        end), ', '))
end

function Parser:line()
    local line = 1
    local remaining = self.input
    while true do
        local index = remaining:find('\n')
        if not index then
            break
        end
        line = line + 1
        remaining = remaining:sub(index + 1)
    end
    return line
end

return class(Parser)
