require("lazy").load({ plugins = { "nvim-lspconfig" } })
vim.cmd("edit C:/Users/Kristan/Desktop/Coding Proyects/typescript_nvim/main.ts")
vim.cmd("set ft=typescript")

vim.defer_fn(function()
	local util = require("lspconfig.util")
	local config = require("lspconfig.configs").tsgo
	if config then
		config.launch()
	end

	vim.defer_fn(function()
		local client = vim.lsp.get_clients({ name = "tsgo" })[1]
		if not client then
			print("No tsgo client found!")
			vim.cmd("q!")
			return
		end

		-- Move cursor to line 3, column 11 (on readFileSync)
		vim.api.nvim_win_set_cursor(0, { 3, 11 })

		client:request("textDocument/hover", vim.lsp.util.make_position_params(0, client.offset_encoding), function(err, result)
			print("--- HOVER RESULT FOR readFileSync ---")
			print("ERR: " .. tostring(err))
			print("RES: " .. vim.inspect(result))
			vim.cmd("q!")
		end, 0)
	end, 1000)
end, 500)
