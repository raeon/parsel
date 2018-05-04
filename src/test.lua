
local utils = require('utils')
local indent = utils.indent
local outdent = utils.outdent
local logger = utils.logger
logger()

local any = require('parts.any')
local every = require('parts.every')
local literal = require('parts.literal')
local pattern = require('parts.pattern')
local Parser = require('parse.parser')

-- -- Expression constructs
-- local expression = any('expression')
--
-- -- General tokens
-- local lparen = literal('lparen', '(')
-- local rparen = literal('rparen', ')')
--
-- -- Literals
-- local number = pattern('number', '[0-9]+')
-- local identifier = pattern('identifier', '[a-zA-Z]+')
-- local btrue = literal('true', 'true')
-- local bfalse = literal('false', 'false')
-- local boolean = any('boolean', btrue, bfalse)
-- local null = literal('null', 'nil')
-- local value = any('value', number, identifier, boolean, null)
--
-- -- Binary operators
-- local plus = literal('plus', '+')
-- local minus = literal('minus', '-')
-- local divide = literal('divide', '/')
-- local multiply = literal('multiply', '*')
-- local lessequal = literal('lessequal', '<=')
-- local greaterequal = literal('greaterequal', '>=')
-- local less = literal('less', '<')
-- local greater = literal('greater', '>')
-- local notequals = literal('notequals', '!=')
-- local equals = literal('equals', '==')
-- local binaryop = any('binary-operator', plus, minus, divide, multiply,
--     lessequal, greaterequal, less, greater, notequals, equals)
-- local binary = every('binary', expression, binaryop, expression)
--
-- -- Unary operators
-- local bang = literal('negate', '!')
-- local unaryop = any('unary-operator', bang, minus)
-- local unary = every('unary', unaryop, expression)
--
-- -- Groupings
-- local closed = every('closed-expression', lparen, expression, rparen)
--
-- -- Expression
-- expression:add(binary)
-- expression:add(unary)
-- expression:add(closed)
-- expression:add(value)

--local value = any('value', number, identifier)
--local expr = any('expr', value)
--expr:add(expr)

-- for _, state in pairs(value.states) do
--     print(state)
-- end

local function printStates(obj, visited)
    visited = visited or {}
    if visited[obj] then
        print('object: ' .. tostring(obj) .. ' (already visited)')
        return
    end
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
                printStates(to.shift.part, visited)
            else
                print(symbol, ' => reduce ', tostring(to.reduce))
                printStates(to.reduce, visited)
            end
        end
        for symbol, to in pairs(state.gotos) do
            print(symbol, ' => goto ', tostring(to))
        end
        outdent()
    end
    outdent()
end

local plus = literal('plus', '+')
local minus = literal('minus', '-')
local bang = literal('bang', '!')

local value = pattern('value', '[a-zA-Z]')
local binaryOp = any('binary-op', plus, minus)
local unaryOp = any('unary-op', bang, minus)

local expr = any('expr')
local unary = every('unary', unaryOp, expr)
local binary = every('binary', expr, binaryOp, expr)

expr:add(unary)
expr:add(binary)
expr:add(value)

-- root -> A
-- A -> B | x
-- B -> A | y

-- root -> . A
-- root -> A .
-- A -> . B
-- A -> B .
-- A -> . x
-- A -> x .
-- B -> . A
-- B -> A .
-- B -> . y
-- B -> y .

-- In state "A -> x ." we want to detect symbol 'y'.

-- We expect that the state
--  root -> A .

-- a:add(b)
-- b:add(literal('x', 'x'))
-- b:add(literal('y', 'y'))

-- a:buildClosures()
-- a:buildTables()
-- dumpPart(a)
-- if true then return end
-- local plus = literal('plus', '+')
-- local number = pattern('number', '[0-9]+')
-- local identifier = pattern('identifier', '[a-zA-Z]+')
--
-- local value = any('value', number, identifier)
--
-- local expr = any('expr')
--
-- expr:add(every('binary', expr, plus, expr))
-- expr:add(value)

-- print() print()
-- a:buildClosures()
-- print() print()
-- a:buildTables()
-- print() print()

--printStates(a)
--if true then return end

local parser = Parser(expr)
local result, err = parser('!x')
if err then
    print('Parsing failed:', err)
    return
end

print('Result:', result)


if true then return end




-- local a = any('expr')
-- local b = every('binary')
--
-- b:add(a)
-- b:add(plus)
-- b:add(a)
--
-- a:add(b)
-- a:add(number)
--
-- a:finalize()
-- dumpPart(a)
-- if true then return end
--
-- local parser = Parser(a, '5+3+4', 1)
-- local expr, err = parser:parse()
-- if err then
--     print('Parser failed:', err)
--     return
-- end
-- print(expr)
