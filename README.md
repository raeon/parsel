# parsel
A simple, powerful parser for Lua with zero dependencies.

## Table of contents
<!-- TOC depthFrom:2 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [Table of contents](#table-of-contents)
- [Usage](#usage)
	- [Example](#example)
	- [Defining a grammar](#defining-a-grammar)
		- [Terminals](#terminals)
			- [Priorities](#priorities)
		- [Nonterminals](#nonterminals)
		- [Ignored terminals](#ignored-terminals)
	- [Parsing](#parsing)
	- [Error handling](#error-handling)
	- [Result manipulation](#result-manipulation)
		- [Merging](#merging)
		- [Flattening](#flattening)
		- [Transforming](#transforming)
		- [Stripping](#stripping)
- [Quick reference](#quick-reference)
	- [Grammar](#grammar)
	- [Literal](#literal)
	- [Pattern](#pattern)
	- [Parser](#parser)
	- [Node](#node)
- [Credits](#credits)
- [License](#license)

<!-- /TOC -->

## Usage
In this section we'll start with a typical example, followed by an in-depth explanation for how to build your grammar from scratch.

### Example
The following is an implementation of a parser that parses simple mathematical expressions:

```lua
local parsel = require('parsel')
local literal, pattern = parsel.Literal, parsel.Pattern

--[[
    Building the grammar
]]
local g = parsel.Grammar()

-- Ignore all whitespace characters
g:ignore(pattern('%s+'))

-- Terminal symbols
g:define('sum-op', literal '+')
g:define('sum-op', literal '-')
g:define('product-op', literal '*')
g:define('product-op', literal '/')
g:define('lparen', literal '(')
g:define('rparen', literal ')')
g:define('number', pattern '[0-9]+')

-- Defining nonterminal productions
g:define('sum', 'sum', 'sum-op', 'product')
g:define('sum', 'product')

g:define('product', 'product', 'product-op', 'factor')
g:define('product', 'factor')

g:define('factor', 'lparen', 'sum', 'rparen')
g:define('factor', 'number')

--[[
    Parsing input
]]

-- Parsing the input using the 'sum' productions
local parse = g:parser('sum')
local results, err = parse('1 + 2 * (3 - (4 + 5))')

-- Handle errors
if err then
    print(err)
    return
end

-- Handle ambiguity
if #results > 1 then
    print('The input is ambiguous for the given grammar!')
    return
end

--[[
    Refining the parse tree
]]
local tree = results[1]

-- Strip unneeded symbols from parse tree
tree:strip('lparen')
tree:strip('rparen')

-- Simplifying the parse tree
tree:flatten('sum-op')
tree:flatten('sum') -- replaces "sum" matches with "product"
tree:flatten('product-op')
tree:flatten('product')
tree:flatten('factor') -- replaces factor with either the "sum" or the "number"

tree:merge('sum')
tree:merge('product')
tree:merge('factor')

-- Transforming the parse tree
tree:transform('number', function(node)
    -- the "number" nonterminal always has 1 child: a terminal node!
    return tonumber(node.children[1].value) -- convert the string to a number
end)

print(tree)
```

Running this example code yields the following output:
```
sum(1, "+", product(2, "*", sum(3, "-", 4, "+", 5)))
```

### Defining a grammar
Defining your own grammar is easy! Just create a new `Grammar` object like so:
```lua
local parsel = require('parsel')
local grammar, literal, pattern = parsel.Grammar, parsel.Literal, parsel.Pattern

local g = grammar()
```
From here on out we will define symbols.

#### Terminals
Using this grammar object you can start defining your terminal and nonterminal symbols. Currently, there are two types of terminal symbols available for use: the `Literal` and the `Pattern`. As the names suggest, the `Literal` is an exact match of the string you pass it. The `Pattern` only matches the Lua pattern you give it, which is particularly useful when you want to match numbers (`[0-9]+`) or identifiers (`[a-zA-Z]+`). This looks like so (continuing from the previous snippet):
```lua
g:define('number', pattern '[0-9]+')
g:define('identifier', pattern '[a-zA-Z]+')
```
**Note:** The `pattern '[0-9]+'` is a function call using an alternative syntax supported by Lua. It is syntactically equivalent to calling the function normally, like so: `pattern('[0-9]+')`.

##### Priorities
Sometimes, you have multiple tokens in your grammar that are ambiguous. For example, in many programming languages you have the `>`, the `>=` and the `=` operator. `parsel` works by first tokenizing the input using all defined terminals. However, as you might have deduced already, it is possible for the tokenizer to misinterpret a `>=` as both a `>` and a `=` token. This is clearly undesirable! For this reason, you can pass another argument to the `Literal` or `Parser` functions: the priority. By default, the priority is `0`. For this example we would want to assign a higher priority to the `>=` operator, which could be done like this:
```lua
g:define('greater', literal '>')
g:define('greater-or-equal', literal('>=', 500))
g:define('assignment', literal '=')
```

**Warning: Priorities below zero are ignored!** They are used internally by the `g:ignore(...)` function. Therefore, you should always use zero or greater as your priority.

#### Nonterminals
Now that we have our terminals ready, we can start composing our nonterminal symbols. For this example, let's say we want to parse any number of `number`s followed by a single `identifier` symbol. We can accomplish this by defining a recursive symbol.
```lua
g:define('sequence', 'number', 'sequence')
g:define('sequence', 'identifier')
```
What we've done here is define the nonterminal `sequence` with two possible ways to get there: If we encounter a `number` it will parse it and then try to parse another `sequence`. If it encounters an `identifier`, it will immediately finish parsing the current `sequence`. This allows you to parse multiple of the same token in a sequence.

#### Ignored terminals
Sometimes we want to flat-out ignore some `Literal` or `Pattern`. In our example, we wish to allow an arbitrary amount of whitespace between symbols. We accomplish this like so:
```lua
g:ignore(pattern '%s+')
```

### Parsing
Now that we're done defining our simple grammar, we can get to parsing it. Construct a parser using `sequence` as the root production:
```lua
local parser = g:parser('sequence')
```
Now we can pass our input string (and optionally a starting index in the input string) and get an abstract syntax tree (AST):
```lua
local results, err = parser('12 34 56 hello')
```
**Note:** If you pass an index as the second argument to the parser, keep in mind that Lua starts counting at 1. For example, if you use index 2, you will begin parsing at the '2' character.

### Error handling
If the parser encounters any unexpected tokens or unrecognized characters, it will give a fancy error. Let's handle this scenario:
```lua
if err then
    print(err)
    return
end
```
A typical error could look like this:
```
Error: unexpected end of file at line 1 char 15:

    1 + (2 * 3 - 4
                  ^
```

### Result manipulation
Since we're working with an Earley parser, we get back every possible interpretation of the given input. This means that if your grammar is ambigious, you will get all possible results back! Typically this is not what you want, so you can either ignore all results past the first one, or ensure that your grammar is not ambiguous.

So, what is this `results` object we got back? It's just a table of abstract syntax trees! Let's check for ambiguity and error if we have multiple results:
```lua
if #results > 1 then
    print('The given input is ambiguous with this grammar!')
    return
end
```

Now that we're sure there is only *one* parse tree, let's find out what it looks like:
```lua
local tree = results[1]
print(tree)
```

If you run this code, the output looks like this:
```
sequence(number("12"), sequence(number("34"), sequence(number("56"), sequence(identifier("hello")))))
```

This may appear somewhat nonsensical, so here it is in tree form:
```
       sequence
       /      \
   number     sequence
     |        /      \
   "12"   number     sequence
            |        /      \
          "34"    number   sequence
                    |         |
                  "56"    identifier
                              |
                           "hello"
```

**Note:** `parsel` does not come with functionality to let you print fancy trees like this one, but you could always write it yourself. :-)

#### Merging

For this section, we'll continue using our example from before. As expected, the resulting parse tree has the right-recursion we embedded in our grammar. However, in our case, we didn't actually *want* a right-recursive parse tree, we merely wanted to have a sequence of `number`s followed by a single `identifier`.

Luckily for us, `parsel` has just the tools we need! We can simply tell the parse tree to *merge* all `sequence` nonterminals like so:
```lua
tree:merge('sequence')
```

If we now print the parse tree again, we get the following:
```
sequence(number("12"), number("34"), number("56"), identifier("hello"))
```

Again, in tree form:
```
              sequence
        _________/\_________
       /       /    \       \
   number  number  number  identifier
     |       |       |         |
   "12"    "34"     "56"     "hello"
```

Neat! Now we no longer have to deal with recursion when we try to interpret `sequence` symbols.

#### Flattening
In a real-world scenario, it might occur that you have a grammar defined in such a way that it enforces operator precedence to be interpreted correctly. A parse tree produced by such a grammar may look like this:
```
            expression
                |
               sum
                |
             product
                |
              number
                |
               "52"
```
Note how in the above tree diagram there is merely one branch. This could happen if the input is simply a number that does not use any of the possible operators. In this scenario it may not be useful for us to see a `sum` or `product` during traversion when there is no addition/subtraction or multiplication/division happening. This is where `flatten()` comes to save the day.

If we have the above parse tree stored in a variable called `tree`, we could do the following to remove the useless nonterminals we don't care about:
```lua
tree:flatten('sum')
tree:flatten('product')
```

What this does is scan through the tree, and *replace* any node of the given type (in our case `sum` or `product`) with their only child. **This means that if the node has multiple children, it is kept intact.** It is only removed if it has only one child.

**Note:** If the root node (the object on which you call the function) needs to be flattened as well, be sure use the **return value** of the call, like so: `tree = tree:flatten(type)`. It is however not recommended to flatten the root node since it may return a terminal symbol as the new root node, which may interfere with any traversion happening hereafter.

#### Transforming
For some use-cases, the parse tree returned by `parsel` is sufficient. However, a lot of times it just happens that we want to store more data and functions in the nodes of the parse tree. We could always just store more data (since everything in Lua is a table), but that becomes messy quickly and does not allow us to cleanly add methods. In such scenarios it may be useful to transform the nodes of the parse tree to another type.

An excellent example of this is converting the `number` nodes to *actual numbers*, since they are just strings for now. We can do this by writing a *transformation function*: a function that that takes a `number` node and returns a real number. Let's write this function and apply it straight away:
```lua
tree:transform('number', function(node)
    return tonumber(node.children[1].value)
end)
```
**Whoa- hold on there.** This seems illogical. You might be wondering why we didn't do the following:
```lua
tree:transform('number', function(node)
    return tonumber(node.value)
end)
```

The reason for this is actually quite simple. If we look back at our definition of `number`, we see the following:
```lua
g:define('number', pattern '[0-9]+')
```

**We defined `number` as a nonterminal.** This means that `number` is merely a wrapper for the terminal symbol `Pattern('[0-9]+')`. This is why we grab the *first child* from the container, which is the `Pattern`, and convert it's `value` field to a number.

**Note:** If the root node (the object on which you call the function) needs to be transformed as well, be sure use the **return value** of the call, like so: `tree = tree:transform(...)`.

After the transformation, we get the following AST:
```
sequence(12, 34, 56, identifier("hello"))
```

Nice and simple!

#### Stripping
In grammars, it may occur that there are some terminal symbols that are used merely for disambiguation. An example of this is if we were to parse, for example, a function call `func(arg1, arg2, arg2, ..., argN)` we don't need to remember the left/right parenthesis or the commas. For cases like this, we can strip the symbols from the parse tree:
```lua
g:define('lparen', literal '(')
g:define('lparen', literal ')')
g:define('comma', literal ',')

...

tree:strip('lparen')
tree:strip('rparen')
tree:strip('comma')
```
Now we're certain all symbols we encounter are significant to our understanding of the parsed input.

## Quick reference

Internal methods are not shown here for the sake of being a *quick* reference.

### Grammar
- `Grammar()` constructs a new Grammar instance
- `grammar:define(name, symbols..)` defines production `name` -> `symbols`
- `grammar:ignore(symbol)` ignores the given symbol completely during tokenization
- `grammer:parser(name)` returns a Parser using the rule(s) as the root production

### Literal
- `Literal(value[, priority])` constructs a new literal terminal symbol that parses the literal string `value` with priority `priority` (default: 0).
- `tostring(literal)` the `value` string passed during construction

### Pattern
- `Pattern(value[, priority])` constructs a new pattern terminal symbol that parses the Lua pattern `value` with priority `priority` (default: 0)
- `tostring(pattern)` the `value` string passed during construction

### Parser
- `parser(input[, index])` parses `input`, optionally starting at index `index`. returns a list of root nodes and an error string.

### Node
- `node.type` the type of this node (name of nonterminal or a `Literal` or `Pattern` instance)
- `node.value` if this node is a terminal, the raw string represented by this terminal. nil otherwise.
- `node.position` the position where this symbol starts: an object with keys `index`, `line` and `column`, all numbers.
- `node.children` table of `Node` instances (empty table for terminals)
- `node:strip(type)` removes all nodes with type `type`
- `node:merge(type)` merges nodes of type `type` into their parent if their parent is also of type `type`.
- `node:flatten(type)` for all nodes of type `type`, if they have exactly one child, the node is replaced with their child.
- `node:transform(type, fn)` replaces all nodes of type `type` with the result of `fn(node)`.
- `node:isTerminal()` whether this is a terminal symbol or not
- `tostring(node)` converts this node to a string representation

## Credits
- [Loup Vaillant](http://loup-vaillant.fr) for his excellent guide to [Earley parsing](http://loup-vaillant.fr/tutorials/earley-parsing/);
- The [nearley](https://github.com/kach/nearley) npm package  for being an incredibly useful reference during development.

## License
```
MIT License

Copyright (c) 2018 Joris Klein Tijssink

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
