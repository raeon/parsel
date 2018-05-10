do

    --[[
        UTILITIES
    ]]

    local concat = table.concat

    local function push(tbl, v)
        table.insert(tbl, v)
    end

    local function pop(tbl)
        local v = tbl[#tbl]
        tbl[#tbl] = nil
        return v
    end

    local function peek(tbl)
        return tbl[#tbl]
    end

    local function map(tbl, fn)
        local t = {}
        for k,v in pairs(tbl) do
            k,v = fn(k,v)
            if v then
                t[k] = v
            else
                push(t, k)
            end
        end
        return t
    end

    local function each(tbl, fn)
        for k,v in pairs(tbl) do fn(k,v) end
    end

    local function filter(tbl, fn, usePush)
        local t = {}
        for k,v in pairs(tbl) do
            if fn(k,v) then
                if usePush then
                    push(t, v)
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
                push(t, k) -- only value
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

    local function min(tbl, fn)
        local minValue, minScore = nil, nil
        for k,v in pairs(tbl) do
            if not minScore then
                minValue = v
                minScore = fn(k, v)
            else
                local score = fn(k, v)
                if score < minScore then
                    minValue = v
                    minScore = score
                end
            end
        end
        return minValue
    end

    local function max(tbl, fn)
        local maxValue, maxScore = nil, nil
        for k,v in pairs(tbl) do
            if not maxScore then
                maxValue = v
                maxScore = fn(k, v)
            else
                local score = fn(k, v)
                if score < maxScore then
                    maxValue = v
                    maxScore = score
                end
            end
        end
        return maxValue
    end

    local uid = (function()
        local id = 1
        return function()
            id = id + 1
            return id - 1
        end
    end)()

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

    local function indent()
        _G.__indent = (_G.__indent or 0) + 1
    end

    local function outdent()
        _G.__indent = math.max(0, _G.__indent - 1) or 0
    end

    local function logger()
        if _G.__logger then return end
        _G.__logger = true
        _G.__print = print

        local _print = print
        _G.print = function(...)
            local str = table.concat(map({...}, function(k,v) return tostring(v) end), '\t')
            local whitespace = string.rep('|  ', _G.__indent or 0)
            str = whitespace .. str:gsub('\n', '\n' .. whitespace)
            _print(str)
        end
    end
    logger()

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

    function Pattern:new(pattern, priority)
        self.pattern = pattern
        self.priority = priority or 0
    end

    function Pattern:__call(input, index)
        input = input:sub(index)
        local first, last = input:find(self.pattern)
        if first == 1 then
            return input:sub(first, last)
        end
    end

    function Pattern:__tostring()
        return format('/{0}/', self.pattern)
    end

    class(Pattern)

    --[[
        RULES
    ]]

    local Rule = {}
    local Item = {}

    function Rule:new(name, symbols)
        self.id = uid()
        self.name = name
        self.symbols = symbols
    end

    function Rule:item()
        return Item(self, 1)
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

    function Item:new(rule, index, left)
        self.rule = rule
        self.index = index
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

    function Item:expected()
        return self.rule.symbols[self.index + 1]
    end

    function Item:next(token)
        assert(not self.right, 'attempt to move item to next but already has next')
        assert(not self:isLast(), 'attempt to call next on already final item')

        local next = Item(self.rule, self.index + 1, self)
        next.left = self
        next.data = token
        return next
    end

    function Item:finish()
        -- Collect the data in all previous items and return it.
        local data = {}
        local current = self
        repeat
            push(data, current.data)
            current = current.left
        until not (current and current.data)
        return reverse(data)
    end

    function Item:isLast()
        return self.index > #self.rule.symbols
    end

    function Item:__eq(other)
        -- print('Item:__eq')
        -- indent()
        -- print(self)
        -- print(other)
        -- outdent()
        if is(other, Item) then
            return self.rule == other.rule
                and self.index == other.index
                and self.set == other.set
        end
        return false
    end

    function Item:__tostring()
        return self.rule:__tostring(self.index) .. '\t\t(' .. self.set .. ')'
    end

    class(Item)

    --[[
        SET
    ]]

    local Set = {}

    function Set:new(index, items)
        self.index = index
        self.items = {}

        for _, item in pairs(items or {}) do
            push(self.items, item)
        end
    end

    function Set:add(item)
        push(self.items, item)
    end

    function Set:process(next)

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

        self.terminals = grammar:findTerminals()
        self.current = nil
    end

    function Lexer:next()
        local token
        repeat
            token = self:forward()
        until (not token) or token.type.priority >= 0
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
            return token
        end

        -- No tokens past the EOF
        if self.index > #self.input then
            return nil
        end

        -- Otherwise, find the best token
        local bestToken = nil
        local bestPrio = nil
        for _, terminal in pairs(self.terminals) do
            if (not bestPrio) or terminal.priority > bestPrio then
                local token = terminal(self.input, self.index)
                if token then
                    bestToken = {
                        value = token,
                        type = terminal,
                    }
                    bestPrio = terminal.priority
                end
            end
        end

        -- Move forward on success
        if bestToken then
            self.index = self.index + #bestToken.value
        end

        -- Return whatever the result is
        return bestToken
    end

    class(Lexer)

    --[[
        PARSER
    ]]

    local Parser = {}

    function Parser:new(grammar, start)
        self.grammar = grammar
        self.start = map(start, function(_, rule)
            return rule:item() -- starts in set 1, index 1
        end)
    end

    function Parser:__call(input, index, opts)
        index = index or 1

        -- The sets and our index therein
        local sets = { Set(1, self.start) }
        local lexer = Lexer(self.grammar, input, index, opts)

        -- Looping over the sets
        for setIndex, set in pairs(sets) do
            print('Current set: ' .. setIndex)
            indent()

            -- Looping over the items in this set
            for _, item in pairs(set.items) do

                print('Current item: ' .. tostring(item))
                indent()

                -- We look at the next symbol.
                local symbol = item:symbol()

                print('Current symbol: ' .. tostring(symbol))

                -- ..and start with prediction.
                if symbol and not (is(symbol, Literal) or is(symbol, Pattern)) then
                    -- NONTERMINAL: PREDICTION!
                    print('PREDICTION')

                    -- Add the first items of the rules to the current set.
                    local rules = self.grammar:findRules(symbol)
                    for _, rule in pairs(rules) do
                        -- Grab a new unparsed item for this rule
                        local newItem = rule:item()
                        newItem.set = set.index
                        print(tostring(item) .. ' wants ' .. tostring(newItem))

                        -- If this item isn't in this set yet, we add it
                        -- with a reference back to the current set.
                        local duplicate = contains(set.items, newItem)
                        if not duplicate then
                            push(set.items, newItem)
                            -- push(newItem.wantedBy, {
                            --     set = set,
                            --     item = item
                            -- })
                        else
                            print('.. which is a DUPLICATE!\n')
                            -- push(duplicate.wantedBy, {
                            --     set = set,
                            --     item = item,
                            -- })
                        end
                    end
                elseif symbol then
                    -- TERMINAL: SCAN!
                    print('SCAN')

                    -- We peek at the next token and check if it's equal
                    -- to the currently expected symbol.
                    local token = lexer:peek()
                    print('token: ' .. tostring(token))
                    if token and token.type == symbol then
                        -- If this was expected, we add the resulting item
                        -- to the next set with a reference to this set.
                        local nextSet = sets[setIndex + 1]
                        if not nextSet then
                            nextSet = Set(setIndex + 1)
                            sets[setIndex + 1] = nextSet
                        end

                        local nextItem = item:next(token)
                        push(nextSet.items, nextItem)
                    end
                else
                    -- NO SYMBOL: COMPLETION!
                    print('COMPLETION')

                    -- Now we iterate over all items in the previous set
                    -- that are waiting for this symbol to be resolved.
                    local prevSet = sets[item.set]
                    print('Going back to set: ' .. item.set)
                    indent()
                    local data = item:finish()
                    for _, prevItem in pairs(prevSet.items) do
                        -- If the previous item expected this symbol,
                        -- we move them ahead!
                        print('prevItem:', prevItem)
                        local expectedSymbol = prevItem:symbol()
                        print('Item expects: ' .. tostring(expectedSymbol))
                        print('We are: ' .. item.rule.name)
                        if expectedSymbol == item.rule.name then
                            -- We can move this item to next!
                            push(set.items, prevItem:next(data))
                        end
                    end
                    outdent()
                    -- Check all wantedBy's
                    -- for _, position in pairs(item.wantedBy) do
                    --     local fromItem = position.item
                    --     print('wanted by: ' .. tostring(fromItem) .. ' from set ' .. tostring(position.set.index))
                    --     local nextItem = fromItem:next()
                    --
                    --     if not contains(set.items, nextItem) then
                    --         push(set.items, nextItem)
                    --     end
                    -- end
                end

                outdent()
            end
            print('end of item loop')

            lexer:next()

            outdent()
        end
        print('end of set loop')

        for _, set in pairs(sets) do
            print(tostring(set) .. '\n')
        end
    end

    class(Parser)

    --[[
        GRAMMAR
    ]]

    local Grammar = {}

    function Grammar:new()
        self.rules = {}
        self.ignores = {}
    end

    function Grammar:define(result, ...)
        local symbols = {...}
        assert(#symbols > 0, 'rules must have at least 1 symbol')
        push(self.rules, Rule(result, symbols))
    end

    function Grammar:ignore(terminal)
        assert(is(terminal, Literal) or is(terminal, Pattern), 'can only ignore terminal symbols')
        terminal.priority = -1
        push(self.ignores, terminal)
    end

    function Grammar:parser(name)
        local matches = self:findRules(name)
        assert(#matches > 0, 'could not find rule: ' .. name)
        return Parser(self, matches)
    end

    function Grammar:findRules(name)
        return filter(self.rules, function(_, rule) return rule.name == name end, true)
    end

    function Grammar:findTerminals()
        local terminals = {}
        for _, rule in pairs(self.rules) do
            for _, symbol in pairs(rule.symbols) do
                if is(symbol, Literal) or is(symbol, Pattern) then
                    push(terminals, symbol)
                end
            end
        end
        for _, terminal in pairs(self.ignores) do
            push(terminals, terminal)
        end
        return terminals
    end

    class(Grammar)

    --[[
        EXPORTS
    ]]

    return {
        Grammar = Grammar,
        Parser = Parser,
        Rule = Rule,
        Literal = Literal,
        Pattern = Pattern,
    }

end
