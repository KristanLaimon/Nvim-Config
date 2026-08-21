-- ============================================================================
-- PLUGINS: LSP -- mason, nvim-lspconfig and blink.cmp.
-- ============================================================================
-- HOW A SERVER GETS ENABLED
--   1. `opts.servers` below holds one entry per server: its settings, filetypes
--      and root resolution. ADD A LANGUAGE SERVER THERE.
--   2. `mason-lspconfig.ensure_installed` lists what mason installs for you.
--   3. `config()` merges blink.cmp capabilities into each entry and enables it.
--
-- TYPESCRIPT
--   Only `tsgo` runs. vtsls/ts_ls/tsserver are skipped when mason offers them,
--   and stopped on attach if something else starts them anyway -- two TypeScript
--   servers means duplicated diagnostics and doubled memory.
--
-- LUA
--   `lua_ls` also serves `.krsnvim` scripts: the workspace library comes from the
--   type injector, and script globals (fetch, console, import, krsnvim) are added
--   on attach so they do not show up as undefined.
--
-- JSON / TOML SCHEMAS
--   Bundled schemas in `schemas/` are preferred over the online SchemaStore
--   copies, so validation works offline and cannot change under you.
--
-- COMPLETION
--   blink.cmp config lives at the bottom of this file. Extra sources are declared
--   in blink_sources.lua and editorconfig.lua.
-- ============================================================================

-- MSBuild project/props files are XML; registering them makes lemminx attach and
-- give IntelliSense inside .csproj and friends. `.blade.php` needs a pattern
-- rather than an extension, because the filetype depends on the double suffix.
vim.filetype.add({
	extension = {
		csproj = "xml",
		fsproj = "xml",
		vbproj = "xml",
		props = "xml",
		targets = "xml",
	},
	pattern = {
		[".*%.blade%.php"] = "blade",
	},
})

return {
	{
		-- Its own spec so `:Mason` exists on an empty nvim too. Without this, mason
		-- is only ever pulled in as an nvim-lspconfig dependency, and setup() (which
		-- registers the command) runs on BufReadPre — no file open, no :Mason.
		"williamboman/mason.nvim",
		cmd = "Mason",
		opts = {},
	},
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufReadPost", "BufNewFile", "FileType" },
		cmd = { "LspInfo", "LspInstall", "LspStart" },
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"b0o/schemastore.nvim",
		},
		opts = {
			servers = {
				buf_ls = { enabled = false },
				intelephense = {
					filetypes = { "php", "blade" },
					settings = {
						intelephense = {
							files = {
								maxSize = 1000000,
							},
							stubs = {
								"bcmath",
								"Core",
								"curl",
								"date",
								"hash",
								"json",
								"mbstring",
								"openssl",
								"pcre",
								"PDO",
								"Reflection",
								"SPL",
								"standard",
								"tokenizer",
								"zlib",
								"laravel",
								"phpunit",
							},
						},
					},
				},
				taplo = {},
				yamlls = {},
				jsonls = {},
				vtsls = {
					root_dir = function(bufnr, on_dir)
						local root = vim.fs.root(bufnr, {
							"tsconfig.json",
							"jsconfig.json",
							"package.json",
						})
						local home = vim.fs.normalize(vim.env.USERPROFILE or vim.env.HOME or ""):lower()
						if not root or vim.fs.normalize(root):lower() == home then
							on_dir(vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
						else
							on_dir(root)
						end
					end,
					settings = {
						vtsls = {
							autoUseWorkspaceTsdk = true,
							experimental = {
								completion = { enableServerSideFuzzyMatch = true },
							},
						},
						typescript = {
							tsserver = { maxTsServerMemory = 8192 },
							inlayHints = {
								parameterNames = { enabled = "all" },
								parameterTypes = { enabled = true },
								variableTypes = { enabled = true },
								propertyDeclarationTypes = { enabled = true },
								functionLikeReturnTypes = { enabled = true },
								enumMemberValues = { enabled = true },
							},
						},
						javascript = {
							inlayHints = {
								parameterNames = { enabled = "all" },
								parameterTypes = { enabled = true },
								variableTypes = { enabled = true },
								propertyDeclarationTypes = { enabled = true },
								functionLikeReturnTypes = { enabled = true },
								enumMemberValues = { enabled = true },
							},
						},
					},
				},
				biome = {
					root_dir = function(bufnr, on_dir)
						local root = vim.fs.root(bufnr, { "biome.json", "biome.jsonc" })
						if root then
							on_dir(root)
						end
					end,
				},
				eslint = {},
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
								local mason_path = vim.fs.normalize(vim.fn.stdpath("data") .. "/mason/packages")
								local candidate_vtsls = mason_path .. "/vtsls/node_modules/typescript/lib"
								local candidate_ts = mason_path .. "/typescript-language-server/node_modules/typescript/lib"
								if (vim.uv or vim.loop).fs_stat(candidate_vtsls) then
									return candidate_vtsls
								elseif (vim.uv or vim.loop).fs_stat(candidate_ts) then
									return candidate_ts
								end
								return nil
							end)(),
						},
					},
				},
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
				omnisharp = {
					cmd = { "omnisharp", "--languageserver", "--hostPID", tostring(vim.fn.getpid()) },
					enable_roslyn_analyzers = true,
					organize_imports_on_format = true,
					enable_import_completion = true,
					root_dir = function(bufnr, on_dir)
						local util = require("lspconfig.util")
						local fname = vim.api.nvim_buf_get_name(bufnr)
						local root = util.root_pattern("*.sln")(fname)
							or util.root_pattern("*.csproj", "omnisharp.json", "global.json", ".git")(fname)
						if root then
							on_dir(root)
						else
							on_dir(vim.fs.dirname(fname))
						end
					end,
					settings = {
						FormattingOptions = {
							EnableEditorConfigSupport = true,
							OrganizeImports = true,
						},
						MsBuild = {
							LoadProjectsOnDemand = false,
						},
						RoslynExtensionsOptions = {
							EnableAnalyzersSupport = true,
							EnableImportCompletion = true,
							AnalyzeOpenDocumentsOnly = false,
							DiagnosticWorkersThreadCount = 4,
						},
						Sdk = {
							IncludePrereleases = true,
						},
					},
				},
				csharp_ls = {
					enabled = false,
					root_dir = function(bufnr, on_dir)
						local util = require("lspconfig.util")
						local fname = vim.api.nvim_buf_get_name(bufnr)
						local root = util.root_pattern("*.sln")(fname) or util.root_pattern("*.csproj", ".git")(fname)
						if root then
							on_dir(root)
						else
							on_dir(vim.fs.dirname(fname))
						end
					end,
				},
				lemminx = {
					settings = {
						xml = {
							validation = {
								enabled = true,
								noGrammar = "hint",
							},
							completion = {
								autoCloseTags = true,
							},
							fileAssociations = {
								{
									systemId = vim.fn.stdpath("config") .. "/schemas/xml/msbuild.xsd",
									pattern = "*.csproj",
								},
								{
									systemId = vim.fn.stdpath("config") .. "/schemas/xml/msbuild.xsd",
									pattern = "*.props",
								},
								{
									systemId = vim.fn.stdpath("config") .. "/schemas/xml/msbuild.xsd",
									pattern = "*.targets",
								},
								{
									systemId = vim.fn.stdpath("config") .. "/schemas/xml/msbuild.xsd",
									pattern = "*.fsproj",
								},
								{
									systemId = vim.fn.stdpath("config") .. "/schemas/xml/msbuild.xsd",
									pattern = "*.vbproj",
								},
							},
						},
					},
				},
				dockerls = {},
				gopls = {
					settings = {
						gopls = {
							codelenses = {
								gc_details = false,
								generate = true,
								regenerate_cgo = true,
								run_govulncheck = true,
								test = true,
								tidy = true,
								upgrade_dependency = true,
								vendor = true,
							},
							hints = {
								assignVariableTypes = true,
								compositeLiteralFields = true,
								compositeLiteralTypes = true,
								constantValues = true,
								functionTypeParameters = true,
								parameterNames = true,
								rangeVariableTypes = true,
							},
							analyses = {
								unusedparams = true,
								shadow = true,
							},
							staticcheck = true,
							gofumpt = true,
						},
					},
				},
				bashls = {
					filetypes = { "sh", "bash", "zsh", "csh", "ksh" },
				},
				lua_ls = {
					filetypes = { "lua", "krsnvim" },
					settings = {
						Lua = {
							runtime = {
								version = "LuaJIT",
							},

							diagnostics = {
								globals = { "vim", "fetch", "console", "import", "krsnvim", "cli", "terminal", "fs" },
							},

							workspace = {
								checkThirdParty = false,
								library = require("plugins.krs.type_injector").get_active_lua_libraries(),
							},

							completion = {
								callSnippet = "Replace",
							},

							hint = {
								enable = true,
								setType = true,
							},

							telemetry = {
								enable = false,
							},

							format = {
								enable = true,
								defaultConfig = {
									indent_style = "tab",
									indent_size = "2",
								},
							},
						},
					},
				},
			},
		},
		config = function(_, opts)
			local has_blink, blink = pcall(require, "blink.cmp")

			-- 1. Initialize Mason
			require("mason").setup()
			require("mason-lspconfig").setup({
				automatic_installation = false,
				ensure_installed = {},
				handlers = {
					function(server_name)
						local config = opts.servers[server_name] or {}
						if config.enabled == false then
							return
						end
						if has_blink then
							config.capabilities = blink.get_lsp_capabilities(config.capabilities)
						end
						vim.lsp.config(server_name, config)
						vim.lsp.enable(server_name)
					end,
				},
			})

			-- 2. Setup configured servers in opts.servers
			for server_name, config in pairs(opts.servers) do
				if config.enabled ~= false then
					local cfg = vim.deepcopy(config)
					if has_blink then
						cfg.capabilities = blink.get_lsp_capabilities(cfg.capabilities)
					end
					vim.lsp.config(server_name, cfg)
					vim.lsp.enable(server_name)
				end
			end

			-- Re-trigger FileType autocmd for loaded buffers so newly enabled LSP servers attach
			-- immediately to the buffer whose opening triggered lazy-loading of nvim-lspconfig.
			vim.schedule(function()
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= "" then
						pcall(vim.api.nvim_exec_autocmds, "FileType", { buffer = buf })
					end
				end
			end)

			vim.diagnostic.config({
				virtual_text = {
					source = "if_many",
					prefix = "●",
				},
				underline = true,
				signs = true,
				severity_sort = true,
			})

			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					if client and client.name == "lua_ls" then
						local bufnr = args.buf
						local fname = vim.api.nvim_buf_get_name(bufnr)
						local ft = vim.bo[bufnr].filetype
						local is_krs = (ft == "krsnvim" or fname:match("%.krsnvim$") ~= nil)

						if is_krs then
							client.config.settings.Lua = client.config.settings.Lua or {}
							client.config.settings.Lua.diagnostics = client.config.settings.Lua.diagnostics or {}
							client.config.settings.Lua.diagnostics.globals =
								{ "vim", "fetch", "console", "import", "krsnvim", "cli", "terminal", "fs" }
							pcall(client.notify, "workspace/didChangeConfiguration", { settings = client.config.settings })
						end
					end

					if client and client.supports_method and client:supports_method("textDocument/inlayHint") then
						if vim.lsp.inlay_hint then
							pcall(vim.lsp.inlay_hint.enable, true, { bufnr = args.buf })
						end
					end
				end,
			})

			-- tsgo advertises `diagnosticProvider`, so nvim pulls and refreshes diagnostics
			-- natively. A hand-rolled fetch into a private namespace only froze whatever
			-- the server happened to know a few hundred ms after attach -- typically
			-- before node_modules was loaded -- and never refreshed it.

			local function get_schema_uri(category, filename)
				local path = vim.fs.normalize(vim.fn.stdpath("config") .. "/schemas/" .. category .. "/" .. filename)
				return vim.uri_from_fname(path)
			end

			local ok_schemastore, schemastore = pcall(require, "schemastore")
			if ok_schemastore then
				opts.servers.yamlls = opts.servers.yamlls or {}
				opts.servers.yamlls.settings = {
					yaml = {
						schemaStore = {
							enable = false,
							url = "",
						},
						schemas = schemastore.yaml.schemas(),
					},
				}

				opts.servers.jsonls = opts.servers.jsonls or {}
				opts.servers.jsonls.settings = {
					json = {
						schemas = schemastore.json.schemas({
							select = {
								"tsconfig.json",
								"package.json",
								"prettierrc.json",
								".eslintrc",
								"jsconfig.json",
								"babelrc.json",
								"Turborepo",
								"biome.json",
							},
							replace = {
								["tsconfig.json"] = get_schema_uri("json", "tsconfig.json"),
								["package.json"] = get_schema_uri("json", "package.json"),
								-- ["prettierrc.json"] = get_schema_uri("json", "prettierrc.json"),
								[".eslintrc"] = get_schema_uri("json", "eslintrc.json"),
								["jsconfig.json"] = get_schema_uri("json", "jsconfig.json"),
								["babelrc.json"] = get_schema_uri("json", "babelrc.json"),
								["Turborepo"] = get_schema_uri("json", "turbo.json"),
							},
							extra = {
								{
									name = "prettierrc.json",
									description = "Prettier configuration schema",
									fileMatch = { "prettierrc.json", "prettier.config.json", ".prettierrc.astro.json" },
									url = get_schema_uri("json", "prettierrc.json"),
								},
								{
									name = "biome.json",
									description = "Biome configuration schema",
									fileMatch = { "biome.json", "biome.jsonc" },
									url = get_schema_uri("json", "biome.json"),
								},
								{
									name = "KrsVim Snippets Schema",
									description = "VSCode-compatible snippet file schema",
									fileMatch = { "snippets/*.json", "snippets/**/*.json" },
									url = vim.uri_from_fname(vim.fn.stdpath("config") .. "/snippets/snippets.schema.json"),
								},
							},
						}),
						validate = { enable = true },
					},
				}
			end

			opts.servers.taplo.settings = {
				even_better_toml = {
					schema = {
						enabled = true,
						repository = false,
						associations = {
							["^bunfig\\.toml$"] = get_schema_uri("toml", "bunfig.json"),
						},
					},
				},
			}

			-- Stop all active LSP clients whenever the working directory/project changes.
			-- When you open a file in the new project, Neovim will automatically launch only the needed LSP.
			vim.api.nvim_create_autocmd("DirChanged", {
				group = vim.api.nvim_create_augroup("LspProjectAutoStop", { clear = true }),
				callback = function()
					for _, client in ipairs(vim.lsp.get_clients()) do
						client:stop()
					end
				end,
			})
		end,
	},
	{
		"saghen/blink.cmp",
		event = { "BufReadPre", "BufReadPost", "BufNewFile", "InsertEnter" },
		dependencies = { "rafamadriz/friendly-snippets" },
		version = "*",
		opts = function()
			local is_mobile = false
			local env_ok, env_mod = pcall(require, "krs.core.environment")
			if env_ok then
				local env = env_mod.detect()
				-- proot Ubuntu = full Linux container, treat like desktop.
				-- Only restrict to mobile mode on bare native Termux (Android, no proot).
				is_mobile = (env.is_termux and not env.is_proot) or (env.is_mobile and not env.is_proot)
			else
				is_mobile = vim.env.TERMUX_VERSION ~= nil and vim.fn.isdirectory("/data/data/com.termux") == 1
			end

			return {
				enabled = function()
					return vim.bo.filetype ~= "krsinputmodal" and vim.b.completion ~= false
				end,
				snippets = {
					preset = "default",
				},
				keymap = {
					preset = "default",
					["<CR>"] = { "accept", "fallback" },
					["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
					["<C-@>"] = { "show", "show_documentation", "hide_documentation" },
					["<C-l>"] = { "show", "show_documentation", "hide_documentation" },
					["<Up>"] = { "select_prev", "fallback" },
					["<Down>"] = { "select_next", "fallback" },
				},
				appearance = { nerd_font_variant = "mono" },
				completion = {
					list = {
						selection = {
							preselect = true,
							auto_insert = false,
						},
					},
					menu = {
						border = "rounded",
						max_height = is_mobile and 8 or 15,
						draw = {
							components = {
								kind_icon = {
									ellipsis = false,
									text = function(ctx)
										local colorify = require("krs.lsp.colorify")
										local hex = colorify.extract_color_from_ctx(ctx)
										if hex then
											return " ██ "
										end
										return colorify.get_kind_icon(ctx.kind)
									end,
									highlight = function(ctx)
										local colorify = require("krs.lsp.colorify")
										local hex = colorify.extract_color_from_ctx(ctx)
										if hex then
											return colorify.get_or_create_color_hl(hex)
										end
										return colorify.get_kind_hl(ctx.kind)
									end,
								},
								kind = {
									text = function(ctx)
										return require("krs.lsp.colorify").format_kind_label(ctx.kind)
									end,
								},
							},
							columns = {
								{ "kind_icon" },
								{ "label", "label_description", gap = 1 },
								{ "kind" },
							},
						},
						-- Don't auto-pop inside a freshly inserted empty pair ("{}" from autopairs).
						-- Only auto-show is suppressed: <C-space> still opens the menu there,
						-- which is what `import { | }` needs.
						auto_show = function()
							local line = vim.api.nvim_get_current_line()
							local col = vim.api.nvim_win_get_cursor(0)[2]
							local before, after = line:sub(col, col), line:sub(col + 1, col + 1)
							local pairs_map = { ["{"] = "}", ["["] = "]", ["("] = ")" }
							return pairs_map[before] ~= after
						end,
					},
					documentation = { auto_show = false },
					trigger = {
						-- "{" and "[" open bracket-pair snippets on every keystroke otherwise
						show_on_blocked_trigger_characters = { " ", "\n", "\t", "{", "[", "(" },
					},
				},
				signature = {
					enabled = true,
					window = { border = "rounded" },
				},
				sources = {
					default = { "lsp", "path", "snippets", "buffer" },
					-- Debug repl completes from the stopped frame only, never lsp/buffer words.
					per_filetype = { ["dap-repl"] = { "dap" } },
					providers = {
						dap = { name = "DAP", module = "krs.lsp.dap_repl_source", async = true },
						snippets = {
							opts = {
								search_paths = { vim.fn.stdpath("config") .. "/snippets" },
							},
						},
					},
				},
				fuzzy = {
					implementation = is_mobile and "lua" or "prefer_rust_with_warning",
					prebuilt_binaries = {
						download = not is_mobile,
					},
					sorts = {
						-- always rank snippets (LSP kind 15) below real completions, regardless of fuzzy score
						function(a, b)
							local a_snip, b_snip = a.kind == 15, b.kind == 15
							if a_snip == b_snip then
								return nil
							end
							return b_snip
						end,
						"score",
						"sort_text",
					},
				},
			}
		end,
		opts_extend = { "sources.default" },
	},
}
