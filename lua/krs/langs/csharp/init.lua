-- ============================================================================
-- KRS CSHARP: Centralized C# / .NET Language Configuration
-- ============================================================================
-- WHAT IT DOES
--   Sets standard Microsoft C# 4-space indentation defaults for C# buffers when no
--   .editorconfig file specifies buffer settings. Also owns the omnisharp (primary)
--   and csharp_ls (disabled alternative) LSP servers, netcoredbg (DAP), and the
--   csharpier formatter.
-- ============================================================================

local M = {}

--- The lspconfig/mason server name(s) this language owns.
M.lsp_server = { "omnisharp", "csharp_ls" }

--- lspconfig server settings, keyed by server name (see M.lsp_server). `csharp_ls`
--- is disabled: omnisharp is the one that runs, kept here only so a future switch
--- is a one-line `enabled` flip.
---@type table<string, vim.lsp.Config>
M.lsp_config = {
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
			InlayHintsOptions = {
				EnableForParameters = true,
				ForLiteralParameters = true,
				ForIndexerParameters = true,
				ForObjectCreationParameters = true,
				ForOtherParameters = true,
				SuppressForParametersThatDifferOnlyBySuffix = false,
				SuppressForParametersThatMatchMethodIntent = false,
				SuppressForParametersThatMatchArgumentName = false,
				EnableForTypes = true,
				ForImplicitVariableTypes = true,
				ForLambdaParameterTypes = true,
				ForImplicitObjectCreation = true,
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
}

--- Mason package metadata, keyed by lspconfig/formatter name. `csharp_ls` has none:
--- it is disabled and never auto-installed.
M.mason = {
	omnisharp = { mason = "omnisharp", lang = "C#", type = "lsp", cmd = "OmniSharp" },
	netcoredbg = { mason = "netcoredbg", lang = "C# Debugger", type = "dap", cmd = "netcoredbg" },
	csharpier = { mason = "csharpier", name = "csharpier", type = "formatter", cmd = "csharpier" },
}

M.mason_order = { "omnisharp", "netcoredbg", "csharpier" }

--- Language Tooling Manager bundle metadata (see lua/krs/core/installer.lua).
M.bundle_name = "🎯 C# / .NET"
M.requires = {
	{ cmd = "dotnet", name = ".NET SDK", hint = "https://dot.net" },
}
M.treesitter = { "c_sharp" }
M.dotnet_tools = { "csharp-ls" }

--- conform.nvim formatter list per filetype.
M.formatters_by_ft = {
	cs = { "csharpier" },
}

--- Finds the newest built assembly for a `.csproj` (or project directory) entry.
--- netcoredbg launches the DLL, not the project, so this has to resolve it.
--- @param root string Project root.
--- @param entry string Entry point: a `.dll`, a `.csproj`, or a directory.
--- @return string|nil dll Absolute path to the newest matching DLL.
local function find_dotnet_dll(root, entry)
	local path = require("krs.core.path")
	local full = path.join(root, entry)
	if entry:match("%.dll$") then
		return full
	end

	local proj_dir = entry:match("%.csproj$") and vim.fn.fnamemodify(full, ":h") or full
	local name = entry:match("([^/\\]+)%.csproj$") or vim.fn.fnamemodify(proj_dir, ":t")

	local newest, newest_time = nil, -1
	for _, dll in ipairs(vim.fn.glob(proj_dir .. "/bin/**/" .. name .. ".dll", false, true)) do
		local mtime = vim.fn.getftime(dll)
		if mtime > newest_time then
			newest, newest_time = path.normalize(dll), mtime
		end
	end
	return newest
end

--- Filetypes the DAP configurations below attach to.
M.dap_filetypes = { "cs" }

--- Static nvim-dap configurations, appended by lua/plugins/editor/dap.lua.
M.dap_configs = {
	{
		type = "coreclr",
		request = "launch",
		name = "🎯 Launch .NET Assembly DLL (C#)",
		program = function()
			local root = vim.fn.getcwd()
			local dlls = vim.fn.glob(root .. "/bin/Debug/**/*.dll", false, true)
			if #dlls == 1 then
				return dlls[1]
			elseif #dlls > 1 then
				return vim.fn.input("Path to assembly DLL: ", dlls[1], "file")
			end
			return vim.fn.input("Path to assembly DLL: ", root .. "/bin/Debug/", "file")
		end,
		cwd = "${workspaceFolder}",
		stopAtEntry = false,
	},
	{
		type = "coreclr",
		request = "launch",
		name = "🌐 Launch & Debug Blazor Server App",
		program = function()
			local root = vim.fn.getcwd()
			local dlls = vim.fn.glob(root .. "/bin/Debug/**/*.dll", false, true)
			for _, dll in ipairs(dlls) do
				if not dll:match("%.Views%.dll$") and not dll:match("%.resources%.dll$") then
					return dll
				end
			end
			return vim.fn.input("Path to Blazor app DLL: ", root .. "/bin/Debug/", "file")
		end,
		cwd = "${workspaceFolder}",
		env = {
			ASPNETCORE_ENVIRONMENT = "Development",
		},
		stopAtEntry = false,
	},
	{
		type = "coreclr",
		request = "attach",
		name = "🔌 Attach to Running .NET / Blazor Process",
		processId = function()
			return require("dap.utils").pick_process()
		end,
	},
}

--- Launch-profile runtimes this language owns (see lua/krs/launch/runtimes.lua).
--- With auto_build enabled, `dotnet build` already ran as a pre-launch task, so
--- the DLL is on disk by the time this runs.
M.launch_runtimes = {
	dotnet = {
		command = "dotnet run --project",
		dap = function(profile, root, ctx)
			local dll = find_dotnet_dll(root, ctx.entry)
			if not dll then
				vim.notify(
					"❌ No built DLL found for "
						.. ctx.entry
						.. ".\n  Enable Auto Build on the profile, or point the entry point at bin/Debug/<tfm>/App.dll.",
					vim.log.levels.ERROR,
					{ title = "Launch Profiles Debugger" }
				)
				return nil
			end
			return {
				type = "coreclr",
				request = "launch",
				name = profile.name,
				program = dll,
				cwd = root,
			}
		end,
	},
}

--- Standard C# / .NET defaults (4 spaces).
M.defaults = {
	expandtab = true,
	shiftwidth = 4,
	tabstop = 4,
	softtabstop = 4,
	autoindent = true,
}

--- Apply C# language defaults if no .editorconfig is present.
--- @param buf integer Buffer handle.
function M.apply_defaults(buf)
	local ok, langs = pcall(require, "krs.langs")
	if ok and not langs.has_editorconfig(buf) then
		for option, val in pairs(M.defaults) do
			vim.bo[buf][option] = val
		end
	end
end

--- Forces workstation GC under proot Termux: Server GC reserves 256GB of virtual
--- address space per core, which fails under proot's ulimit -v cap even though
--- nothing is actually used ("GC: reserving (256 gb) for the regions range failed").
local function apply_proot_gc_workaround()
	local ok, env_mod = pcall(require, "krs.core.environment")
	if ok and env_mod.detect().is_proot then
		vim.env.DOTNET_gcServer = "0"
	end
end

--- Initialize C# language configuration autocmds.
function M.setup()
	apply_proot_gc_workaround()

	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "cs" },
		callback = function(args)
			M.apply_defaults(args.buf)
		end,
	})
end

return M
