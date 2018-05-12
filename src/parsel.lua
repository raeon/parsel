do

    --[[
        UTILITIES
    ]]

    local concat = table.concat

    local function map(tbl, fn)
        local t = {}
        for k,v in pairs(tbl) do
            k,v = fn(k,v)
            if v then
                t[k] = v
            else
                table.insert(t, k)
            end
        end
        return t
    end

    local function filter(tbl, fn, useInsert)
        local t = {}
        for k,v in pairs(tbl) do
            if fn(k,v) then
                if useInsert then
                    table.insert(t, v)
                else
                    t[k] = v
                end
            end
        end
        return t
    end

    local function times(i, fn)
        local t = {}
        for j=1,i,1 do
            local k,v = fn(j)
            if not v then
                table.insert(t, k) -- only value
            else
                t[k] = v -- both key and value
            end
        end
        return t
    end

    local function reverse(tbl)
        local t = {}
        for i=1,#tbl,1 do
            t[#tbl - i + 1] = tbl[i]
        end
        return t
    end

    local function contains(tbl, cv)
        for _,v in pairs(tbl) do
            if v == cv then
                return v
            end
        end
    end

    local function format(fmt, ...)
        local args = {...}
        return fmt:gsub('{([0-9]+)}', function(id)
            return tostring(args[tonumber(id) + 1])
        end)
    end

    local function class(proto)
        -- load metafunctions
        local meta = { __index = proto }
        for k,v in pairs(filter(proto, function(k) return k:find('__') == 1 end)) do
            meta[k] = v;
        end

        -- return initializer
        return setmetatable(proto, {
            __call = function(cls, ...)
                local inst = setmetatable({
                    __class = cls,
                }, meta)
                cls.new(inst, ...)
                return inst
            end
        })
    end

    local function is(inst, cls)
        return inst.__class and inst.__class == cls
    end

    --[[
        LITERAL
    ]]

    local Literal = {}

    function Literal:new(value, priority)
        self.value = value
        self.priority = priority or 0
    end

    function Literal:__call(input, index)
        if input:sub(index, index + #self.value - 1) == self.value then
            return self.value
        end
    end

    function Literal:__tostring()
        return format('\'{0}\'', self.value)
    end

    class(Literal)

    --[[
        PATTERN
    ]]

    local Pattern = {}

    function Pattern:new(value, priority)
        self.value = value
        self.priority = priority or 0
    end

    function Pattern:__call(input, index)
        input = input:sub(index)
        local first, last = input:find(self.value)
        if first == 1 then
            return input:sub(first, last)
        end
    end

    function Pattern:__tostring()
        return format('/{0}/', self.value)
    end

    class(Pattern)

    --[[
        NODE
    ]]

    local Node = {}

    function Node:new(type, value, position, children)
        self.type = type
        self.value = value -- only set for terminals
        self.position = position
        self.children = children or {}
    end

    function Node:strip(type)
        -- Remove all nodes with type 'type' from this tree.
        -- Note: This includes tokens.
        for i, child in pairs(self.children) do
            if child.type == type then
                self.children[i] = nil
            end
            if is(child, Node) then
                child:strip(type)
            end
        end

        return self
    end

    function Node:flatten(type, into)
        -- By default, if we are the root node, the flattened items
        -- are to be inserted into our children.
        local isRoot = not into
        into = into or {}

        -- We go over all our children.
        for i, child in ipairs(self.children) do
            if is(child, Node) then
                if child.type == type then
                    -- If the child needs to be flattened,
                    -- instruct it to store all data in this node.
                    child:flatten(type, into)
                else
                    -- If the child ITSELF does not need to be flattened,
                    -- it is not certain that none of its children need
                    -- to be flattened.

                    -- We store this item in the result set since we're
                    -- certain that it itself does not need to be flattened.
                    table.insert(into, child)

                    -- However, next, we instruct the child to flatten
                    -- without passing the 'into' parameter.
                    child:flatten(type)
                end
            elseif type(child) == 'table' and child.type ~= type then
                -- If it is a terminal symbol that does not need to be
                -- flattened, insert it into the result set.
                table.insert(into, child)
            end
        end

        if isRoot then
            self.children = into
        end

        return self
    end

    function Node:transform(type, func)
        -- Transform all nodes in this tree with type 'type' using
        -- the given transformation function.
        self.children = map(self.children, function(_, child)
            if is(child, Node) then
                local result = child:transform(type, func)
                if is(result, Node) and result.type == type then
                    return func(result)
                end
                return result
            end
            return child
        end)

        -- Also substitute ourselves if necessary.
        return self.type == type and func(self) or self
    end

    function Node:isTerminal()
        return self.value ~= nil
    end

    function Node:__tostring()
        return self.value or 'node(' .. self.type .. ', ' .. table.concat(map(self.children, function(_, child)
            return tostring(child)
        end), ', ') .. ')'
    end

    class(Node)

    --[[
        RULES
    ]]

    local Rule = {}
    local Item = {}

    function Rule:new(name, symbols)
        self.name = name
        self.symbols = symbols
    end

    function Rule:item(position)
        return Item(self, 1, position)
    end

    function Rule:__tostring(index)
        return self.name .. ' → ' .. concat(times(#self.symbols + 1, function(i)
            if i == index then
                return i, '● ' .. tostring(self.symbols[i] or '')
            end
            return i, tostring(self.symbols[i] or '')
        end), ' ')
    end

    class(Rule)

    --[[
        STATE
    ]]

    function Item:new(rule, index, position, left)
        self.rule = rule
        self.index = index
        self.position = position
        self.set = left and left.set or 1

        -- Left = previous item
        -- Right = next item
        self.left = left

        -- Data = the result object.
        -- For index=1 this is nil! Not for index=#rule.symbols+1.
        self.data = nil

        -- Store what set/item combos want this item to be completed.
        -- These are copied from our 'left'!
        self.wantedBy = left and left.wantedBy or {}
    end

    function Item:symbol()
        return self.rule.symbols[self.index]
    end

    function Item:next(data)
        assert(not self.right, 'attempt to move item to next but already has next')
        assert(not self:isLast(), 'attempt to call next on already final item')

        local next = Item(self.rule, self.index + 1, data.position, self)
        next.left = self
        next.data = data
        return next
    end

    function Item:finish(set)
        -- Collect the data of this item
        local data = self:collect()

        -- Resolve all wantedBy's into the curent (given) set
        for _, position in pairs(self.wantedBy) do
            local fromItem = position.item
            --print('wanted by: ' .. tostring(fromItem) .. ' from set ' .. tostring(position.set.index))
            local nextItem = fromItem:next(data)

            if not contains(set.items, nextItem) then
                table.insert(set.items, nextItem)
            end
        end
    end

    function Item:collect()
        -- Collect the data in all previous items and return it.
        local data = {}
        local current = self
        local position
        repeat
            position = current.position
            table.insert(data, current.data)
            current = current.left
        until not (current and current.data)
        return Node(self.rule.name, nil, position,  reverse(data))
    end

    function Item:isLast()
        return self.index > #self.rule.symbols
    end

    function Item:__eq(other)
        if is(other, Item) then
            return self.rule == other.rule
                and self.index == other.index
                and self.set == other.set
        end
        return false
    end

    function Item:__tostring()
        return self.rule:__tostring(self.index) .. ' (' .. self.set .. ')'
    end

    class(Item)

    --[[
        SET
    ]]

    local Set = {}

    function Set:new(index, items, left)
        self.index = index
        self.items = {}
        self.left = left
        self.right = nil

        for _, item in pairs(items or {}) do
            table.insert(self.items, item)
        end
    end

    function Set:process(grammar, token, position)
        -- Here we handle all items in this set.
        for _, item in pairs(self.items) do

            -- Determine what the next symbol is that this item expects
            local symbol = item:symbol()

            if not symbol then
                -- COMPLETION
                -- If no symbol is expected, we instruct the item to resolve
                -- all wantedBy's and put those resolved items in this set.
                item:finish(self)
            elseif type(symbol) == 'string' then
                -- PREDICTION
                -- If the symbol is a string, then it is a *rule*.
                -- We expand these rules into this given set.
                self:predict(grammar, item, symbol, position)
            else
                -- SCAN
                -- The only remaining scenario is that this is a literal or pattern.
                -- We match this against the current token.
                if token and token.type == symbol then
                    -- If this was expected, we add the resulting item
                    -- to the next set with a reference to this set.
                    table.insert(self:next().items, item:next(token))
                end
            end
        end

        -- Return the next set. Only created if we did a successful scan.
        return self.right
    end

    function Set:predict(grammar, item, symbol, position)
        local rules = grammar.rules[symbol]
        assert(#rules > 0, 'encountered undefined nonterminal: ' .. symbol)
        for _, rule in pairs(grammar.rules[symbol]) do
            -- Create the first item for this rule, or grab an already
            -- existing item of the same type if it exists within this set.
            local newItem = rule:item(position)
            newItem.set = self.index
            local duplicate = contains(self.items, newItem)

            -- Add the item if it wasn't a duplicate
            if not duplicate then
                table.insert(self.items, newItem)
            end

            -- Add the wantedBy to whichever item we're using
            table.insert(duplicate and duplicate.wantedBy or newItem.wantedBy, {
                set = self,
                item = item,
            })
        end
    end

    function Set:next()
        local next = self.right
        if not next then
            next = Set(self.index + 1, {}, self)
            self.right = next
        end
        return next
    end

    function Set:__tostring()
        return format('== {0} ==\n{1}',
            self.index,
            table.concat(map(self.items, function(_, item)
                return tostring(item)
            end), '\n'))
    end

    class(Set)

    --[[
        LEXER
    ]]

    local Lexer = {}

    function Lexer:new(grammar, input, index, opts)
        self.grammar = grammar
        self.input = input
        self.index = index
        self.opts = opts or {}

        self.terminals = grammar.terminals
        self.current = nil
    end

    function Lexer:next()
        local token, prio
        repeat
            token, prio = self:forward()
        until (not token) or prio >= 0
        return token
    end

    function Lexer:peek()
        -- If we've already peeked a token, return it
        if self.current then
            return self.current
        end

        -- Store next token in self.current and return it
        self.current = self:next()
        return self.current
    end

    function Lexer:forward()
        -- Return peeked token if any
        if self.current then
            local token = self.current
            self.current = nil
            return token, 0
        end

        -- No tokens past the EOF
        if self.index > #self.input then
            return nil, nil
        end

        -- Otherwise, find the best token
        local position = self:position()
        local bestToken = nil
        local bestPrio = nil
        for _, terminal in pairs(self.terminals) do
            if (not bestPrio) or terminal.priority > bestPrio then
                local token = terminal(self.input, self.index)
                if token then
                    bestToken = Node(terminal, token, position, nil)
                    bestPrio = terminal.priority
                end
            end
        end

        -- Move forward on success
        if bestToken then
            self.index = self.index + #bestToken.value
        end

        -- Return whatever the result is
        return bestToken, bestPrio
    end

    function Lexer:line()
        local row = self:stats()
        local input = self.input .. '\n'

        local count = 1
        local result = ''
        input:gsub('(.-)\n', function(match)
            if count == row then
                result = match
            end
            count = count + 1
        end)

        return result
    end

    function Lexer:stats()
        local index = self.index
        if self.current then index = index - #self.current.value end

        -- Everything we have visited
        local seen = self.input:gsub(1, index - 1)

        -- From the begin of the input to the current index,
        -- how many newlines are encountered?
        local row = 1
        seen:gsub('\n', function() row = row + 1 end)

        -- What character are we at?
        local last = seen:find('\n[^\n]*$') or 0
        local col = index - last

        return row, col
    end

    function Lexer:position()
        local index = self.index
        local row, col = self:stats()
        return { index = index, line = row, column = col }
    end

    function Lexer:isDone()
        return self.index > #self.input and not self.current
    end

    class(Lexer)

    --[[
        PARSER
    ]]

    local Parser = {}

    function Parser:new(grammar, root, start)
        self.grammar = grammar
        self.root = root
        self.start = map(start, function(_, rule)
            return rule:item() -- starts in set 1, index 1
        end)
    end

    function Parser:__call(input, index, opts)
        index = index or 1

        local lexer = Lexer(self.grammar, input, index, opts)
        local set = Set(1, self.start)
        local next, token

        -- next set, but no next token? unexpected eof
        -- no next set, but next token? syntax error
        -- no results and not eof? unexpected symbol

        -- Loop until we run out of tokens
        repeat
            token = lexer:peek()

            -- Process the current set
            next = set:process(self.grammar, token, lexer:position())
            if not next then break end

            -- Move to the next set and token.
            set = next
            lexer:next()
        until not (token and set)

        -- Do some error checking
        if token then
            -- If there is a token remaining, it was unexpected.
            return nil, self:error('unexpected token ' .. token.value, lexer)
        elseif not lexer:isDone() then
            -- If there is NOT a token remaining but the lexer is also not done,
            -- then we must've encountered an unrecognized character.
            return nil, self:error('unexpected character', lexer)
        end

        -- Find all items in the last set that begin at 1
        local results = {}
        for _, item in pairs(set.items) do
            if item.set == 1
            and item.rule.name == self.root
            and item:isLast() then
                table.insert(results, item:collect())
            end
        end

        -- If there are no results, then we must have either
        -- reached EOF or an unexpected token. Throw an error.
        if #results == 0 then
            return nil, self:error('unexpected end of file', lexer)
        end

        return results
    end

    function Parser:error(message, lexer)
        local row, col = lexer:stats()
        local err = 'Error: ' .. message .. ' at line ' .. row .. ' col ' .. col .. ':\n\n'
        err = err .. '    ' .. lexer:line() .. '\n'
        err = err .. '    ' .. string.rep(' ', col - 1) .. '^\n'
        return err
    end

    class(Parser)

    --[[
        GRAMMAR
    ]]

    local Grammar = {}

    function Grammar:new()
        self.rules = setmetatable({}, {
            __index = function(tbl, k)
                local v = {}
                rawset(tbl, k, v)
                return v
            end
        })
        self.terminals = {}
    end

    function Grammar:define(result, ...)
        local symbols = {...}
        assert(#symbols > 0, 'rules must have at least 1 symbol')

        -- Add the rule to self.rules[result]
        table.insert(self.rules[result], Rule(result, symbols))

        -- Store any new terminals
        for _, symbol in pairs(symbols) do
            if is(symbol, Literal) or is(symbol, Pattern) then
                if not contains(self.terminals, symbol) then
                    table.insert(self.terminals, symbol)
                end
            end
        end
    end

    function Grammar:ignore(terminal)
        assert(is(terminal, Literal) or is(terminal, Pattern), 'can only ignore terminal symbols')
        terminal.priority = -1
        table.insert(self.terminals, terminal)
    end

    function Grammar:parser(name)
        local matches = self.rules[name] or {}
        assert(#matches > 0, 'could not find rule: ' .. name)
        return Parser(self, name, matches)
    end

    class(Grammar)

    --[[
        EXPORTS
    ]]

    return {
        Grammar = Grammar,
        Literal = Literal,
        Pattern = Pattern,
    }

end
