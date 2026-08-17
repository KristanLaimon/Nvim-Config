-- ============================================================================
-- PLUGIN: render-markdown -- readable markdown inside the editor.
-- ============================================================================
-- Renders headings, code blocks, tables, checkboxes and callouts in place, so
-- docs/*.md and the in-editor wiki read like a document rather than raw text.
-- Loads only for markdown buffers.
-- ============================================================================

return {
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown" },
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons",
		},
		opts = {
			heading = {
				enabled = true,
				sign = true,
				icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
			},
			code = {
				enabled = true,
				sign = false,
				style = "full",
			},
			bullet = {
				enabled = true,
			},
			checkbox = {
				enabled = true,
			},
			quote = {
				enabled = true,
			},
			pipe_table = {
				enabled = true,
				preset = "round",
				style = "full",
				cell = "padded",
				padding = 1,
				min_width = 0,
				alignment_indicator = "━",
			},
			callout = {
				note = { raw = "[!NOTE]", rendered = "󰋽 Note", highlight = "RenderMarkdownInfo" },
				tip = { raw = "[!TIP]", rendered = "󰌶 Tip", highlight = "RenderMarkdownSuccess" },
				important = { raw = "[!IMPORTANT]", rendered = "󰅾 Important", highlight = "RenderMarkdownHint" },
				warning = { raw = "[!WARNING]", rendered = "󰀪 Warning", highlight = "RenderMarkdownWarn" },
				caution = { raw = "[!CAUTION]", rendered = "󰳦 Caution", highlight = "RenderMarkdownError" },
			},
		},
		config = function(_, opts)
			require("render-markdown").setup(opts)

			-- Autocmd to map Ctrl+Shift+V only in markdown files
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "markdown",
				callback = function(ev)
					vim.keymap.set("n", "<C-S-v>", "<Cmd>RenderMarkdown toggle<CR>", {
						buffer = ev.buf,
						noremap = true,
						silent = true,
						desc = "Toggle Render Markdown (Buffer)",
					})
					vim.keymap.set("n", "<C-S-V>", "<Cmd>RenderMarkdown toggle<CR>", {
						buffer = ev.buf,
						noremap = true,
						silent = true,
						desc = "Toggle Render Markdown (Buffer)",
					})
				end,
			})
		end,
	},
	{
		"iamcco/markdown-preview.nvim",
		cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
		ft = { "markdown" },
		build = "cd app && npm install",
	},
}
