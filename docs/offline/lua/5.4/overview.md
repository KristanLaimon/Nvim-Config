# 📚 Lua 5.4 — Core Offline Reference

## 🌐 Quick Summary
Lua 5.4 is a lightweight, embeddable scripting language featuring garbage collection, first-class functions, lexical scoping, and metatables.

## 🔑 Key Features
- **Metatables & Metamethods**: Used for OOP inheritance and operator overloading (`__index`, `__newindex`, `__tostring`, `__add`).
- **Garbage Collector**: Generational GC mode (`collectgarbage("generational")`).
- **To-be-closed Variables**: Declared with `<close>` attribute (`local f <close> = io.open("file.txt")`).
- **Const Variables**: Declared with `<const>` attribute (`local MAX <const> = 100`).

## 🔄 Module Importing vs Execution
- `require("modulename")`: Searches `package.path`, caches result in `package.loaded`.
- `dofile("path/file.lua")`: Executes file from physical path on every call.

## 🛠️ Common Built-in Modules
```lua
-- Table manipulation
table.insert(tbl, pos, value)
table.remove(tbl, pos)
table.concat(tbl, sep)

-- String manipulation
string.format("%s = %d", name, count)
string.gmatch(str, pattern)
string.gsub(str, pattern, repl)
```
