
-- Defining a grammar
-- ..how?

local parsel = require('parsel')
local grammar, literal, pattern = parsel.Grammar, parsel.Literal, parsel.Pattern

local g = grammar()

g:ignore(pattern('%s+'))

g:define('number', pattern('[0-9]+'))
g:define('identifier', pattern('[a-zA-Z]+'))
g:define('lparen', literal('('))
g:define('rparen', literal(')'))
g:define('product-op', literal('*'))
g:define('product-op', literal('/'))
g:define('sum-op', literal('+'))
g:define('sum-op', literal('-'))

g:define('factor', 'lparen', 'sum', 'rparen')
g:define('factor', 'number')

g:define('product', 'product', 'product-op', 'product')
g:define('product', 'factor')

g:define('sum', 'sum', 'sum-op', 'product')
g:define('sum', 'product')

g:define('expr', 'sum')
g:define('expr', 'identifier')

local p = g:parser('expr')

local results = p('1 + (2 * 3 + 4)')
local serpent = require('serpent')
print('#results', #results)
print(serpent.block(results, { comment = false }))
