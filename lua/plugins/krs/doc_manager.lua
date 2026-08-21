-- ============================================================================
-- KRS PLUGIN: Offline Documentation Manager -- Plug in & search language docs offline.
-- ============================================================================
-- WHAT IT DOES
--   Stores offline documentation files inside `stdpath("config")/docs/offline/<language>/<version>/`
--   and provides full CRUD (Create, Read/View, Update, Delete) and Telescope
--   fuzzy searching so you never need internet to check language docs.
--
-- COMMANDS
--   :DocManager / :KrsDocManager          Open the Offline Doc Manager UI.
--   :KrsDocSearch [query]                 Fuzzy search offline documentation.
--   :KrsDocView [lang] [version]          Browse docs for language and version.
--   :KrsDocAdd [lang] [version] [topic]   Create a new offline doc file.
-- ============================================================================

local lazy_req = require("krs.core.lazy_require")
local store = lazy_req("krs.core.store")

local M = {}

M.settings = {
	docs_dir = vim.fn.stdpath("config") .. "/docs/offline",
	lang_docs_dir = vim.fn.stdpath("config") .. "/docs/languages",
	notify_title = "KRS Offline Doc Manager",
}

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = M.settings.notify_title })
end

--- Ensures the offline docs directory exists.
--- @return string dir_path
function M.ensure_dir()
	local dir = M.settings.docs_dir
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end
	return dir
end

--- Gets current filetype or defaults to "lua".
--- @param lang string|nil
--- @return string
local function resolve_lang(lang)
	if lang and lang ~= "" then
		return lang:lower()
	end
	local ft = vim.bo.filetype
	if ft and ft ~= "" then
		return ft:lower()
	end
	return "lua"
end

--- Lists available languages in the offline docs store.
--- @return string[]
function M.list_languages()
	M.ensure_dir()
	local langs = {}
	local handle = vim.loop.fs_scandir(M.settings.docs_dir)
	if handle then
		while true do
			local name, type_str = vim.loop.fs_scandir_next(handle)
			if not name then
				break
			end
			if type_str == "directory" then
				table.insert(langs, name)
			end
		end
	end
	return langs
end

--- Lists available versions for a given language.
--- @param lang string
--- @return string[]
function M.list_versions(lang)
	local lang_dir = M.settings.docs_dir .. "/" .. lang
	local versions = {}
	if vim.fn.isdirectory(lang_dir) == 1 then
		local handle = vim.loop.fs_scandir(lang_dir)
		if handle then
			while true do
				local name, type_str = vim.loop.fs_scandir_next(handle)
				if not name then
					break
				end
				if type_str == "directory" then
					table.insert(versions, name)
				end
			end
		end
	end
	return versions
end

--- Fuzzy searches across all offline docs using Telescope.
--- @param query string|nil
function M.search_docs(query)
	M.ensure_dir()
	local has_telescope, builtin = pcall(require, "telescope.builtin")
	if not has_telescope then
		notify("Telescope is required for doc search", vim.log.levels.WARN)
		return
	end

	local search_dirs = {}
	if vim.fn.isdirectory(M.settings.docs_dir) == 1 then
		table.insert(search_dirs, M.settings.docs_dir)
	end
	if vim.fn.isdirectory(M.settings.lang_docs_dir) == 1 then
		table.insert(search_dirs, M.settings.lang_docs_dir)
	end

	if #search_dirs == 0 then
		notify("No offline docs directories found!", vim.log.levels.WARN)
		return
	end

	if query and query ~= "" then
		builtin.live_grep({
			prompt_title = "📚 Search Offline Docs (" .. query .. ")",
			search_dirs = search_dirs,
			default_text = query,
		})
	else
		builtin.live_grep({
			prompt_title = "📚 Search Offline Docs",
			search_dirs = search_dirs,
		})
	end
end

--- Interactively browse doc files for a specific language and version.
--- @param lang string|nil
--- @param version string|nil
function M.view_docs(lang, version)
	lang = resolve_lang(lang)
	local versions = M.list_versions(lang)

	if not version or version == "" then
		if #versions == 0 then
			notify("No offline docs found for " .. lang .. ". Create one with :KrsDocAdd " .. lang .. " 1.0 main!")
			return
		elseif #versions == 1 then
			version = versions[1]
		else
			vim.ui.select(versions, { prompt = "Select " .. lang .. " documentation version:" }, function(choice)
				if choice then
					M.view_docs(lang, choice)
				end
			end)
			return
		end
	end

	local target_dir = M.settings.docs_dir .. "/" .. lang .. "/" .. version
	if vim.fn.isdirectory(target_dir) == 0 then
		notify("Version directory does not exist: " .. target_dir, vim.log.levels.WARN)
		return
	end

	local has_telescope, builtin = pcall(require, "telescope.builtin")
	if has_telescope then
		builtin.find_files({
			prompt_title = "📖 " .. lang:upper() .. " (v" .. version .. ") Docs",
			cwd = target_dir,
		})
	else
		vim.cmd("Neotree " .. vim.fn.fnameescape(target_dir))
	end
end

--- Creates a new offline doc file for a language, version, and topic.
--- @param lang string|nil
--- @param version string|nil
--- @param topic string|nil
function M.add_doc(lang, version, topic)
	lang = resolve_lang(lang)

	local function do_create(l, v, t)
		local target_dir = M.settings.docs_dir .. "/" .. l .. "/" .. v
		vim.fn.mkdir(target_dir, "p")
		local filename = t:gsub("[^%w_%-]", "_"):lower() .. ".md"
		local filepath = target_dir .. "/" .. filename

		if vim.fn.filereadable(filepath) == 0 then
			local f = io.open(filepath, "w")
			if f then
				local content = string.format(
					[[# 📚 %s (v%s) — %s

## Overview
Offline documentation reference for %s version %s.

## Quick Reference
- Topic: %s
- Added: %s

## API & Examples
```%s
-- Code snippet or usage example
```
]],
					l:upper(),
					v,
					t,
					l,
					v,
					t,
					os.date("%Y-%m-%d"),
					l
				)
				f:write(content)
				f:close()
			end
		end

		vim.cmd("edit " .. vim.fn.fnameescape(filepath))
		notify("Created offline doc: " .. filepath)
	end

	if not version or version == "" then
		vim.ui.input({ prompt = "Language Version (e.g. 5.4, 8.3, 3.12, 1.22, 12): ", default = "1.0" }, function(v)
			if not v or v == "" then
				return
			end
			vim.ui.input({ prompt = "Doc Topic Name (e.g. string_functions, arrays, async): ", default = "overview" }, function(t)
				if not t or t == "" then
					return
				end
				do_create(lang, v, t)
			end)
		end)
	elseif not topic or topic == "" then
		vim.ui.input({ prompt = "Doc Topic Name (e.g. string_functions, arrays, async): ", default = "overview" }, function(t)
			if not t or t == "" then
				return
			end
			do_create(lang, version, t)
		end)
	else
		do_create(lang, version, topic)
	end
end

--- Main interactive Offline Doc Manager UI picker.
function M.open_manager()
	local ft = vim.bo.filetype ~= "" and vim.bo.filetype or "lua"
	local options = {
		"🔍 Search All Offline Docs (Telescope Grep)",
		"📖 View Docs for Current Language (" .. ft .. ")",
		"➕ Create New Offline Doc (Add Topic)",
		"📂 Open Offline Docs Root Folder in Explorer",
	}

	vim.ui.select(options, { prompt = "📚 KRS Offline Documentation Store" }, function(choice, idx)
		if not idx then
			return
		end

		if idx == 1 then
			M.search_docs()
		elseif idx == 2 then
			M.view_docs(ft)
		elseif idx == 3 then
			M.add_doc(ft)
		elseif idx == 4 then
			local dir = M.ensure_dir()
			vim.cmd("Neotree " .. vim.fn.fnameescape(dir))
		end
	end)
end

--- Registers user commands and keymaps.
function M.setup()
	vim.api.nvim_create_user_command("DocManager", function()
		M.open_manager()
	end, { desc = "Open KRS Offline Doc Manager" })

	vim.api.nvim_create_user_command("KrsDocManager", function()
		M.open_manager()
	end, { desc = "Open KRS Offline Doc Manager" })

	vim.api.nvim_create_user_command("KrsDocSearch", function(opts)
		M.search_docs(opts.args ~= "" and opts.args or nil)
	end, { nargs = "?", desc = "Search offline documentation" })

	vim.api.nvim_create_user_command("KrsDocView", function(opts)
		local args = vim.split(opts.args, "%s+", { trimempty = true })
		M.view_docs(args[1], args[2])
	end, { nargs = "*", desc = "View offline docs for language and version" })

	vim.api.nvim_create_user_command("KrsDocAdd", function(opts)
		local args = vim.split(opts.args, "%s+", { trimempty = true })
		M.add_doc(args[1], args[2], args[3])
	end, { nargs = "*", desc = "Add new offline doc topic" })
end

return setmetatable({
	name = "doc_manager",
	dir = require("krs.core.lazyspec").for_module(),
	lazy = false,
	config = M.setup,
}, { __index = M })
