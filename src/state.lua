
local utils = require('utils')
local indent = utils.indent
local outdent = utils.outdent
local copy = utils.copy
local map = utils.map
local keys = utils.keys
local count = utils.count
local format = utils.format
local class = utils.class

local Closure = require('closure')
--
-- local PENDING = 1
-- local WAITING = 2
-- local DONE = 3

local State = {}

function State:new(part, child, index)
    self.part = part
    self.child = child
    self.index = index
    self.closure = Closure(self)

    self.lookaheads = nil
    self.gotos = nil

    -- self.waitingFor = {}
    -- self.dependants = {}
end

function State:buildClosures(visited)
    visited = visited or {}
    if visited[self] then
        print('ALREADY VISITED:', self)
        return
    end
    visited[self] = true

    print('Building closure for state', self)
    indent()
    if self.child and not self.child:isTerminal() then
        self.closure:add(self.child)
        self.child:buildClosures(visited)
    end
    outdent()
end

function State:buildTables(visited, followers)

    -- We are at the root of the buildTables call if no table was given.
    print('Building tables for ' .. tostring(self))

    -- Prevent recursion
    visited = visited or {}
    if visited[self] then return end
    visited[self] = true

    -- The followers table is used to merge state tables
    -- where the last parsed symbol in the states are the same.
    -- E.g.: (A -> B .) and (C -> B . * B ) can and should be merged.
    followers = followers or {}

    -- Get all states in our closure
    local states = self.closure:getStates()

    -- We just build our tables
    print(tostring(self))

    -- Now that we've done that, we can build our lookahead and goto tables.
    local lookaheads = {}
    local gotos = {}

    for state in pairs(states) do
        -- Grab the states surrounding this state
        local prev = state:prev()
        local next = state:next()
        indent()

        -- If there is a previous symbol, then we should put the
        -- previous state in the followers table.
        if prev then
            followers[prev.child] = followers[prev.child] or {}
            table.insert(followers[prev.child], state)
        end

        -- If there is no following state, we should reduce by this production.
        if next == nil then
            -- Add the 'any' lookahead to reduce by this production.
            -- This will only happen if the looked-up token is not defined
            -- by another state in our list in the followers table.
            print('any => reduce ' .. tostring(state.part))
            lookaheads['any'] = { reduce = state.part }
        else
            -- It is implied here that state.child is not nil, because
            -- if it was, 'next' would have been nil.
            state.child:buildTables(visited, followers)

            -- If there IS a following state, then we determine what to do
            -- based on the type of symbol: terminal or nonterminal.
            if state.child:isTerminal() then
                -- We are about to parse a terminal symbol.
                -- This shifts us into the state where we just
                -- parsed this terminal symbol.
                print(tostring(state.child) .. ' => shift ' .. tostring(next))
                lookaheads[state.child] = { shift = next }
            else
                -- It's a nonterminal symbol. This goes in our goto table.
                print(tostring(state.child) .. ' => goto ' .. tostring(next))

                -- If there are multiple versions of the state.child,
                -- then state.child itself will never be encountered,
                -- only it's children. Here we put the versions in the
                -- goto table instead of the production itself.
                if state.child.versions then
                    for _, version in pairs(state.child.versions) do
                        gotos[version] = next
                    end
                else
                    -- Or just do it normally.
                    gotos[state.child] = next
                end
            end
        end
        outdent()
    end
    self.lookaheads = lookaheads
    self.gotos = gotos
    self.followers = followers
end

function State:mergeTables()
    -- Wwe want to merge the lookahead (and goto?) tables from the followers table.
    print('Merging tables')
    for symbol, followingStates in pairs(self.followers) do
        local lookaheads = {}
        -- local gotos = {}

        print('symbol', symbol, ' followers:')
        indent()

        -- Create a single combined lookahead and goto table
        for _, state in pairs(followingStates) do
            print(state)
            indent()
            for k,v in pairs(state.lookaheads) do
                if v.shift then
                    print(tostring(k) .. ' => shift ' .. tostring(v.shift))
                else
                    print(tostring(k) .. ' => reduce ' .. tostring(v.reduce))
                end
                lookaheads[k] = v
            end
            -- for k,v in pairs(state.gotos) do
            --     gotos[k] = v
            -- end
            outdent()
        end
        outdent()

        -- Update all their lookahead and goto tables
        for _, state in pairs(followingStates) do
            state.lookaheads = lookaheads
            -- state.gotos = gotos
        end
    end
end

function State:prev()
    return self.part.states[self.index - 1]
end

function State:next()
    return self.part.states[self.index + 1]
end

function State:__tostring()
    return format('State("{0}", "{2}")', self.part, self.index,
        table.concat(map(self.part.states, function(i, state)
            if i == self.index then
                return '. ' .. tostring(state.child and state.child.name or 'nil')
            end
            return tostring(state.child and state.child.name or 'nil')
        end), ' '))
end

return class(State)
