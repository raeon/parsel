
-- Defining a grammar
-- ..how?

local parsel = require('parsel')
local grammar, literal, pattern = parsel.Grammar, parsel.Literal, parsel.Pattern

local g = grammar()

g:ignore(pattern('%s+'))

-- Primitives
g:define('number', pattern('[0-9]+'))
g:define('identifier', pattern('[a-zA-Z]+'))
g:define('boolean', literal('true'))
g:define('boolean', literal('false'))
g:define('nil', literal('nil'))
g:define('closed', 'lparen', 'expression', 'rparen')
-- TODO: String

-- Keywords
g:define('let', literal('let', 500))
g:define('if', literal('if', 500))

-- Operators
g:define('lparen', literal('('))
g:define('rparen', literal(')'))
g:define('lbrace', literal('{'))
g:define('rbrace', literal('}'))
g:define('multiplication-op', literal('*'))
g:define('multiplication-op', literal('/'))
g:define('addition-op', literal('+'))
g:define('addition-op', literal('-'))
g:define('equality-op', literal('!='))
g:define('equality-op', literal('=='))
g:define('comparison-op', literal('<'))
g:define('comparison-op', literal('>'))
g:define('comparison-op', literal('<='))
g:define('comparison-op', literal('>='))
g:define('unary-op', literal('!'))
g:define('unary-op', literal('-'))
g:define('assign-op', literal('='))

--[[
    PROGRAM
]]
g:define('program', 'block-statement-body')

--[[
    STATEMENTS
]]
g:define('statement', 'let-statement')
g:define('statement', 'if-statement')
g:define('statement', 'block-statement')
g:define('statement', 'expression-statement')

-- Let statement
g:define('let-statement', 'let', 'identifier', 'assign-op', 'expression')

-- If statement
g:define('if-statement', 'if', 'expression', 'statement')

-- Block statement
g:define('block-statement-body', 'block-statement-body', 'statement')
g:define('block-statement-body', 'statement')
g:define('block-statement', 'lbrace', 'block-statement-body', 'rbrace')

-- Expression statement
g:define('expression-statement', 'expression')

--[[
    EXPRESSIONS
]]
g:define('closed', 'lparen', 'expression', 'rparen')
g:define('expression', 'equality')

-- Equality
g:define('equality', 'equality', 'equality-op', 'comparison')
g:define('equality', 'comparison')

-- Comparison
g:define('comparison', 'comparison', 'comparison-op', 'addition')
g:define('comparison', 'addition')

-- Addition
g:define('addition', 'addition', 'addition-op', 'multiplication')
g:define('addition', 'multiplication')

-- Multiplication
g:define('multiplication', 'multiplication', 'multiplication-op', 'unary')
g:define('multiplication', 'unary')

-- Unary
g:define('unary', 'unary-op', 'unary')
g:define('unary', 'primary')

-- Primary
g:define('primary', 'number')
g:define('primary', 'identifier')
g:define('primary', 'boolean')
g:define('primary', 'nil')
g:define('primary', 'closed')

-- node.text => concatenated string
-- node.strip(type) => find all subnodes with type
-- node.transform(type, func) => call func for each node of the given type
-- node.reduce(type) => removes all nodes of type 'type',
--                      putting children of 'type' in the parent of 'type'.

local p = g:parser('program')

local results, err = p('1 + 2')
if err then
    print(err)
    return
end

assert(#results == 1, 'expected one result')

local result = results[1]
--result:strip('number')
--result:flatten('number')
result:flatten('equality')
result:flatten('comparison')
result:flatten('addition')
result:flatten('multiplication')
result:flatten('primary')
result:flatten('block-statement-body')
result:flatten('expression-statement')
result:flatten('unary')
result:flatten('addition-op')

result:transform('number', function(node)
    return 'previously-a-number'
end)

print(result)
