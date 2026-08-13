return function(dap)
	dap.adapters.krsnvimscript = function(callback, config)
		callback({
			type = "executable",
			command = "nvim",
			args = { "--headless", "-c", "lua dofile('" .. (config.program or "") .. "')" },
		})
	end

	dap.configurations.lua = dap.configurations.lua or {}
	table.insert(dap.configurations.lua, {
		type = "krsnvimscript",
		request = "launch",
		name = "🚀 Run with krsnvimscript",
		program = "${file}",
		cwd = "${workspaceFolder}",
	})
end
