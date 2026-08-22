-- ============================================================================
-- KRS WEB: Centralized Web Frontend Language Configuration
-- ============================================================================
-- WHAT IT DOES
--   Owns the HTML/CSS/Svelte/Astro/Tailwind/Emmet LSP servers, their settings,
--   Mason package names, and formatter assignment. Web frontend projects
--   (HTML, CSS, Vue, Svelte, Astro) often use formatters like Prettier or Biome --
--   the detection lists for those live in lua/krs/langs/typescript (their
--   canonical JS/TS/JSON-ecosystem home) and are reused here.
--   - If project formatter configs (.prettierrc*, biome.json*, .editorconfig) exist,
--     defer to those formatters and skip overriding buffer settings.
--   - If NO project formatter config exists, fallback 2-space defaults are applied.
-- ============================================================================

local M = {}

--- The lspconfig/mason server names this language owns.
M.lsp_server = { "html", "cssls", "tailwindcss", "emmet_ls", "svelte", "astro" }

--- Formatter and tool configuration files for Web Frontend projects.
M.formatter_configs = {}

local function build_formatter_configs()
	local ts = require("krs.langs.typescript")
	vim.list_extend(M.formatter_configs, ts.PRETTIER_CONFIG_FILES)
	vim.list_extend(M.formatter_configs, ts.BIOME_CONFIG_FILES)
end

--- lspconfig server settings, keyed by server name (see M.lsp_server).
---@type table<string, vim.lsp.Config>
M.lsp_config = {
	html = {
		filetypes = { "html", "templ", "hbs", "php", "blade" },
	},
	cssls = {
		settings = {
			css = { validate = true, lint = { unknownAtRules = "ignore" } },
			scss = { validate = true, lint = { unknownAtRules = "ignore" } },
			less = { validate = true },
		},
	},
	tailwindcss = {
		filetypes = {
			"html",
			"css",
			"scss",
			"javascript",
			"javascriptreact",
			"typescript",
			"typescriptreact",
			"svelte",
			"vue",
			"astro",
			"php",
			"blade",
		},
		root_dir = function(bufnr, on_dir)
			local root = vim.fs.root(bufnr, {
				"tailwind.config.js",
				"tailwind.config.cjs",
				"tailwind.config.mjs",
				"tailwind.config.ts",
				"postcss.config.js",
				"astro.config.mjs",
				"package.json",
			})
			if root then
				on_dir(root)
			end
		end,
		settings = {
			tailwindCSS = {
				validate = true,
				hovers = true,
				suggestions = true,
				codeActions = true,
				experimental = {
					classRegex = {
						{ "cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*)" },
						{ "cx\\(([^)]*)\\)", "[\"'`]([^\"'`]*)" },
						{ "cn\\(([^)]*)\\)", "[\"'`]([^\"'`]*)" },
					},
				},
			},
		},
	},
	emmet_ls = {
		filetypes = {
			"html",
			"typescriptreact",
			"javascriptreact",
			"css",
			"sass",
			"scss",
			"less",
			"svelte",
			"vue",
			"astro",
			"php",
			"blade",
		},
	},
	svelte = {
		on_attach = function(client, _)
			vim.api.nvim_create_autocmd("BufWritePost", {
				pattern = { "*.js", "*.ts" },
				callback = function(ctx)
					client.notify("$/onDidChangeTsOrJsFile", { uri = ctx.match })
				end,
			})
		end,
	},
	astro = {
		init_options = {
			typescript = {
				tsdk = (function()
					local ts_lsp_server = require("krs.langs.typescript").lsp_server[1]
					local mason_path = vim.fs.normalize(vim.fn.stdpath("data") .. "/mason/packages")
					local candidate_ts_lsp = mason_path .. "/" .. ts_lsp_server .. "/node_modules/typescript/lib"
					local candidate_ts = mason_path .. "/typescript-language-server/node_modules/typescript/lib"
					if (vim.uv or vim.loop).fs_stat(candidate_ts_lsp) then
						return candidate_ts_lsp
					elseif (vim.uv or vim.loop).fs_stat(candidate_ts) then
						return candidate_ts
					end
					return nil
				end)(),
			},
		},
	},
}

--- Mason package metadata, keyed by lspconfig name.
M.mason = {
	html = { mason = "html-lsp", lang = "HTML", type = "lsp", cmd = "vscode-html-language-server" },
	cssls = { mason = "css-lsp", lang = "CSS", type = "lsp", cmd = "vscode-css-language-server" },
	tailwindcss = {
		mason = "tailwindcss-language-server",
		lang = "Tailwind CSS",
		type = "lsp",
		cmd = "tailwindcss-language-server",
	},
	emmet_ls = { mason = "emmet-ls", lang = "Emmet", type = "lsp", cmd = "emmet-ls" },
	svelte = { mason = "svelte-language-server", lang = "Svelte", type = "lsp", cmd = "svelteserver" },
	astro = { mason = "astro-language-server", lang = "Astro", type = "lsp", cmd = "astro-ls" },
}

M.mason_order = { "svelte", "astro", "html", "cssls", "tailwindcss", "emmet_ls" }

--- Language Tooling Manager bundle metadata (see lua/krs/core/installer.lua).
M.bundle_name = "🌐 Web Frontend (HTML, CSS, Svelte, Astro)"
M.requires = {
	{ cmd = "node", name = "Node.js", hint = "https://nodejs.org" },
}
M.treesitter = { "html", "css", "svelte", "astro" }

--- conform.nvim formatter list per filetype. Astro always runs prettier (see
--- lua/krs/langs/typescript's conform_formatters.prettier for why); biome mangles
--- Astro and Svelte components so it is filtered out for those in formatting.lua.
M.formatters_by_ft = {
	css = { "prettierd", "prettier", "biome", stop_after_first = true },
	html = { "prettierd", "prettier", "biome", stop_after_first = true },
	svelte = { "prettierd", "prettier", "biome", stop_after_first = true },
	astro = { "prettier" },
}

--- Fallback defaults for Web Frontend (2 spaces).
M.defaults = {
	expandtab = true,
	shiftwidth = 2,
	tabstop = 2,
	softtabstop = 2,
	autoindent = true,
}

--- Apply Web Frontend fallback defaults if no formatter config or .editorconfig is present.
--- @param buf integer Buffer handle.
function M.apply_defaults(buf)
	local ok, langs = pcall(require, "krs.langs")
	if ok and not langs.has_project_config(buf, M.formatter_configs) then
		for option, val in pairs(M.defaults) do
			vim.bo[buf][option] = val
		end
	end
end

--- Initialize Web Frontend language configuration autocmds.
function M.setup()
	build_formatter_configs()

	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "html", "css", "scss", "less", "vue", "svelte", "astro" },
		callback = function(args)
			M.apply_defaults(args.buf)
		end,
	})
end

return M
