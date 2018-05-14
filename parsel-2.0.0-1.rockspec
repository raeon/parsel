package = "parsel"
version = "2.0.0-1"
source = {
    url = "git+https://github.com/raeon/parsel.git",
    tag = "v2.0.0-1"
}
description = {
    summary = "A simple, powerful parser for Lua with zero dependencies.",
    detailed = [[
        Parsel is a simple, but unrelentingly powerful parsing library
        written in pure Lua with zero dependencies. With it, you can
        define and parse your context-free grammars with ease. All forms
        of recursion are supported, along with ambiguous grammars.
    ]],
    homepage = "https://github.com/raeon/parsel",
    license = "MIT"
}
dependencies = {
    "lua >= 5.1, < 5.4"
}
build = {
    type = "builtin",
    modules = {
        parsel = "src/parsel.lua"
    }
}
