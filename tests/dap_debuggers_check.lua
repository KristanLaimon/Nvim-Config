-- Run: nvim --headless -n -S tests/dap_debuggers_check.lua
-- Fails loudly if lua/plugins/krs/debuggers/ stops wiring adapters and
-- configurations into nvim-dap the way lua/plugins/editor/dap.lua expects.

require("lazy").load({ plugins = { "nvim-dap" } })
local dap = require("dap")

local function names(ft)
	local out = {}
	for _, c in ipairs(dap.configurations[ft] or {}) do
		table.insert(out, c.name)
	end
	return out
end

local ts = names("typescript")
assert(#ts == 9, "typescript expected 9 configs, got " .. #ts .. ": " .. vim.inspect(ts))
assert(ts[1]:find("Bun"), "first typescript config should be Bun, got " .. tostring(ts[1]))
assert(ts[3]:find("Node"), "third should be Node, got " .. tostring(ts[3]))
assert(ts[9]:find("Firefox"), "last should be Firefox, got " .. tostring(ts[9]))
assert(#names("astro") == 9, "astro missing web configs")
-- Exactly one each: mason-nvim-dap's generic defaults must have been cleared.
assert(#names("python") == 1, "python configs missing or duplicated by mason")
assert(#names("cs") == 1, "cs configs missing or duplicated by mason")
assert(#names("php") == 1, "php configs missing or duplicated by mason")
assert(dap.configurations.go and #dap.configurations.go > 0, "dap-go configs missing")
assert(dap.adapters["pwa-node"], "pwa-node adapter not registered")
assert(dap.adapters["pwa-msedge"], "pwa-msedge adapter not registered")

print("OK typescript=" .. #ts .. " " .. table.concat(ts, " | "))
print("OK go=" .. #dap.configurations.go)
vim.cmd("qa!")
