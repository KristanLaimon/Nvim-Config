-- ============================================================================
-- krs.git.diff -- Turning `git diff` output into a readable, coloured buffer.
-- ============================================================================
-- WHAT IT DOES
--   Strips the machine noise from a diff (`diff --git`, `index abc..def`, the
--   `---`/`+++` pair) and keeps the hunks, each under a labelled separator. The
--   second return value tags every line so the caller can highlight it.
--
-- WHY LINES ARE SPLIT DEFENSIVELY
--   `nvim_buf_set_lines` rejects any entry containing a newline, and git can
--   smuggle one in through binary or CRLF-mangled content. Every line funnels
--   through `push`, which splits before appending.
--
-- USAGE
--   local diff = require("krs.git.diff")
--   diff.setup_highlights()
--   local lines, kinds = diff.format(raw_lines, false)
--   diff.apply_highlights(bufnr, kinds)
-- ============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Configuration -- colours and layout of the rendered diff
-- ---------------------------------------------------------------------------

--- Namespace owning the diff highlights.
M.namespace = vim.api.nvim_create_namespace("git_center_diff_hl")

--- Highlight group per line kind, in VSCode-ish colours.
--- `default = true` so a colorscheme can override any of them.
M.highlights = {
	add = { name = "GitCenterDiffAdd", opts = { bg = "#1c3427", fg = "#a6e3a1", default = true } },
	delete = { name = "GitCenterDiffDelete", opts = { bg = "#3b1d22", fg = "#f38ba8", default = true } },
	header = { name = "GitCenterDiffHeader", opts = { bg = "#1e293b", fg = "#89dceb", bold = true, default = true } },
	context = { name = "GitCenterDiffContext", opts = { fg = "#cdd6f4", default = true } },
}

--- Diff lines that carry no information for a reader.
M.noise_patterns = {
	"^diff %--git",
	"^index %x+%.%.%x+",
	"^%-%-%- a/",
	"^%+%+%+ b/",
	"^new file mode",
	"^deleted file mode",
}

--- Matches a hunk header, e.g. `@@ -1,7 +1,9 @@ function foo()`.
M.hunk_pattern = "^@@ %-%d+,?%d* %+%d+,?%d* @@"

--- Width a hunk separator is padded to.
M.separator_width = 65

--- Banner shown above the contents of a new, untracked file.
M.untracked_banner = " ─── 📄 New Untracked File ──────────────────────────────────────────"

--- Shown when a file has no visible changes (mode change, whitespace only).
M.empty_message = " (no visible changes in this file)"

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

--- Defines the diff highlight groups. Safe to call repeatedly.
function M.setup_highlights()
	for _, highlight in pairs(M.highlights) do
		vim.api.nvim_set_hl(0, highlight.name, highlight.opts)
	end
end

--- True when a diff line is header noise rather than content.
--- @param line string
--- @return boolean
local function is_noise(line)
	for _, pattern in ipairs(M.noise_patterns) do
		if line:match(pattern) then
			return true
		end
	end
	return false
end

--- Formats raw diff output for display.
---
--- @param raw_lines string[] Output of `git diff --color=never`, or the file's
---   own contents when `is_untracked` is true.
--- @param is_untracked boolean|nil Render every line as an addition.
--- @return string[] lines Buffer-ready lines.
--- @return string[] kinds Line kind per line: "add" | "delete" | "header" | "context".
function M.format(raw_lines, is_untracked)
	local lines, kinds = {}, {}

	--- Appends one logical line, splitting any embedded newlines.
	local function push(text, kind)
		for _, part in ipairs(vim.split(text, "\n", { plain = true })) do
			table.insert(lines, part)
			table.insert(kinds, kind)
		end
	end

	if is_untracked then
		push(M.untracked_banner, "header")
		for _, line in ipairs(raw_lines) do
			push("+ " .. line, "add")
		end
		return lines, kinds
	end

	-- Everything before the first hunk header is preamble and gets dropped.
	local in_header = true
	local hunk_count = 0

	for _, line in ipairs(raw_lines) do
		if is_noise(line) then -- skip
		elseif line:match(M.hunk_pattern) then
			in_header = false
			hunk_count = hunk_count + 1

			local context = line:match("@@ %-%d+,?%d* %+%d+,?%d* @@(.*)") or ""
			local range = line:match("(@@ %-%d+,?%d* %+%d+,?%d* @@)") or line
			local header = string.format(
				" ─── Hunk %d %s %s",
				hunk_count,
				range,
				context ~= "" and ("(" .. context:gsub("^%s*", "") .. ") ") or ""
			)
			if #header < M.separator_width then
				header = header .. string.rep("─", M.separator_width - #header)
			end
			push(header, "header")
		elseif not in_header then
			local first = line:sub(1, 1)
			push(line, first == "+" and "add" or (first == "-" and "delete" or "context"))
		end
	end

	if #lines == 0 then
		push(M.empty_message, "context")
	end
	return lines, kinds
end

--- Applies the diff colours to a buffer already filled by `M.format`.
--- @param bufnr integer Buffer holding the formatted lines.
--- @param kinds string[] Second return value of `M.format`.
function M.apply_highlights(bufnr, kinds)
	vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)

	for index, kind in ipairs(kinds) do
		local highlight = M.highlights[kind]
		if highlight then
			vim.api.nvim_buf_add_highlight(bufnr, M.namespace, highlight.name, index - 1, 0, -1)
		end
	end
end

return M
