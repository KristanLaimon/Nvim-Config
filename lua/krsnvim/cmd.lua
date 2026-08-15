--- @module "krsnvim.cmd"
--- Alias for `krsnvim.terminal` - Cross-platform Terminal and Shell Command Execution Suite for `krsnvimscript`.
--- Invokable as `cmd("command")` or `cmd.exec("command")` or `cmd.run("command")`.
---
--- @class CommandResult
--- @field code number Exit status code of the process (0 for success).
--- @field ok boolean `true` if exit code is 0, `false` otherwise.
--- @field stdout string Standard output captured from command.
--- @field stderr string Standard error captured from command.
--- @field output string Combined output of stdout and stderr.
---
--- @example
--- local cmd = require("krsnvim.cmd")
--- local res = cmd("git status")
--- if res.ok then
---     print(res.stdout)
--- else
---     print("Error code:", res.code)
--- end

local terminal = require("krsnvim.terminal")

return terminal
