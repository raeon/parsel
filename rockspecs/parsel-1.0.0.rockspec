package = "parsel"
version = "1.0.0"
source = {
    url = "git+https://github.com/raeon/parsel.git"
}
description = {
    summary = "A simple Earley parser implementation for Lua.",
    detailed = [[
        A simple Earley parser implementation for Lua
        written in pure Lua, without any extra dependencies.
    ]],
    homepage = "https://github.com/raeon/parsel",
    license = "MIT"
}
dependencies = {
    "lua >= 5.1, < 5.4"
}
build = {
    type = "builtin",
    modules = {}
}
