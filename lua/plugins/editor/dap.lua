return {
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"rcarriga/nvim-dap-ui",
			"nvim-neotest/nvim-nio",
			"jay-babu/mason-nvim-dap.nvim",
			"theHamsta/nvim-dap-virtual-text",
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			local mason_dap_ok, mason_dap = pcall(require, "mason-nvim-dap")
			if mason_dap_ok then
				mason_dap.setup({
					ensure_installed = { "js-debug-adapter", "delve", "debugpy" },
					automatic_installation = true,
					handlers = {},
				})
			end

			dapui.setup()

			local virtual_text_ok, virtual_text = pcall(require, "nvim-dap-virtual-text")
			if virtual_text_ok then
				virtual_text.setup()
			end

			-- Auto open/close DAP UI when debugging starts/stops
			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = function()
				dapui.close()
			end
			dap.listeners.before.event_exited["dapui_config"] = function()
				dapui.close()
			end

			-- Custom Breakpoint and Execution line signs
			vim.fn.sign_define("DapBreakpoint", { text = "🔴", texthl = "DapBreakpoint", linehl = "", numhl = "" })
			vim.fn.sign_define("DapStopped", { text = "🟡", texthl = "DapStopped", linehl = "DebugHighlight", numhl = "" })
		end,
	},
}
