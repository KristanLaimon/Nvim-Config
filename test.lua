local json = require("krsnvim.json")
local fs = require("krsnvim.fs")
local fetch = require("krsnvim.fetch")

local content = json.encode({ hola = "mundo" }) .. "\n"
local actualContent = fs.read("./testomg.json")

fs.write("./testomg.json", actualContent .. content)
