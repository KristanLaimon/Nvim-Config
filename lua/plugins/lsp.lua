return {
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
		},
		opts = {
			servers = {
				lua_ls = {
					settings = {
						Lua = {
							runtime = {
								version = "LuaJIT",
							},

							diagnostics = {
								globals = { "vim" },
							},

							workspace = {
								checkThirdParty = false,
								library = vim.api.nvim_get_runtime_file("", true),
							},

							completion = {
								callSnippet = "Replace",
							},

							telemetry = {
								enable = false,
							},
						},
					},
				},
			},
		},
		config = function(_, opts)
			-- 1. Initialize Mason
			require("mason").setup()
			require("mason-lspconfig").setup({ ensure_installed = { "lua_ls" } })

			vim.diagnostic.config({
				virtual_text = true,
				underline = true,
			})

			for server, config in pairs(opts.servers) do
				vim.lsp.config(server, config)
				vim.lsp.enable(server)
			end
		end,
	},
	{
		"saghen/blink.cmp",
		dependencies = { "rafamadriz/friendly-snippets" },
		version = "1.*",
		opts = {
			keymap = {
				preset = "default",
				["<CR>"] = { "accept", "fallback" },
			},
			appearance = { nerd_font_variant = "mono" },
			completion = { documentation = { auto_show = false } },
			sources = { default = { "lsp", "path", "snippets", "buffer" } },
			fuzzy = { implementation = "prefer_rust_with_warning" },
		},
		opts_extend = { "sources.default" },
		config = function()
			local blink = require("blink.cmp")
			vim.keymap.set("i", "<C-j>", function()
				blink.show()
			end, { silent = true })
		end,
	},
}
