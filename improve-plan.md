# 🚀 Neovim Enhancement Plan & Advances Log: GitSigns, NvChad CMP Colorify, NvChad Statusline, Nagatoro Theme System, LSP References & Wiki Modal

[← Back to Wiki Index](docs/index.md)

This document tracks all design specs, implementation advances, and test results for adding `gitsigns.nvim`, Shift+Click symbol definition redirect, NvChad-style CMP completion with hand-crafted theme color badges, NvChad statusline with statusline theme picker, nagatoro-krs theme picker with light/dark NvChad themes, LSP Reference Counts / CodeLens, and the interactive Wiki Documentation Center Modal.

---

## 📅 Roadmap & Completed Milestones

- [x] **Phase 1: Shift + Click & Smart Definition Redirect** ([`lua/config/keymaps/lsp.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/lua/config/keymaps/lsp.lua))
  - Shift + Left Click (`<S-LeftMouse>`) moves mouse cursor and calls definition jump.
  - Smart Definition jump: If 1 result is found, goes straight to definition. If >= 2 results are found, opens Telescope `lsp_definitions` picker.
- [x] **Phase 2: GitSigns Integration** ([`lua/plugins/editor/gitsigns.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/lua/plugins/editor/gitsigns.lua) & [`tests/spec/gitsigns_spec.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/tests/spec/gitsigns_spec.lua))
  - Signcolumn glyphs (`▎`, ``), hunk navigation (`]c`, `[c`), preview hunk (`<leader>hp`), stage/reset hunk (`<leader>hs`, `<leader>hr`), blame line (`<leader>hb`).
- [x] **Phase 3: NvChad CMP Completion & Theme Colorify Engine** ([`lua/krs/lsp/colorify.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/lua/krs/lsp/colorify.lua), [`lua/plugins/lsp/lsp.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/lua/plugins/lsp/lsp.lua), [`tests/spec/cmp_colorify_spec.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/tests/spec/cmp_colorify_spec.lua))
  - NvChad layout: Kind icon on left with dedicated background color + accent color pills per completion kind, label in middle, kind text on right (`<Snippet>`, `<Function>`, `<Variable>`, etc.).
  - Hand-crafted palette colors per theme (`CmpKindBg_*` and `CmpItemKind*` definitions across all themes).
  - Hex & RGB colorify engine: Renders rounded color rectangle (` ██ `) with dynamic background color & luminance-based contrasting foreground text (`CmpColor_<hex>`).
- [x] **Phase 4: NvChad Statusline & Statusline Theme Picker** ([`lua/plugins/ui/themes.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/lua/plugins/ui/themes.lua), [`lua/plugins/krs/statusline_picker.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/lua/plugins/krs/statusline_picker.lua), [`tests/spec/statusline_spec.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/tests/spec/statusline_spec.lua))
  - NvChad block/pill modules matching `nagatoro-krs` colors (` NORMAL`, file path, branch ``, diagnostics, position ` L:C`).
  - `:KrsStatuslineTheme` command supporting `nvchad_pills`, `nvchad_blocks`, `nagatoro_classic`, `vscode`, and `minimal` themes with persistence.
- [x] **Phase 5: Nagatoro Themes & Theme Picker** ([`colors/*.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/colors/), [`lua/plugins/krs/theme_picker.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/lua/plugins/krs/theme_picker.lua), [`tests/spec/theme_picker_spec.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/tests/spec/theme_picker_spec.lua))
  - 4 new themes matching `nagatoro-krs` format: `nagatoro-light`, `onedark-krs`, `catppuccin-krs`, `nord-krs`.
  - `:KrsThemePicker` command & `<leader>th` keymap with interactive live preview and store persistence.
- [x] **Phase 6: LSP Function & Class Reference Counter (CodeLens)** ([`lua/plugins/krs/lsp_references.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/lua/plugins/krs/lsp_references.lua) & [`tests/spec/lsp_references_spec.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/tests/spec/lsp_references_spec.lua))
  - Displays LSP reference counts (`󰌹 3 references`, `1 reference`) above functions, methods, classes, and structs.
  - Enabled by default (ON). Toggleable via `:KrsToggleReferences` (or `<leader>tr`) and entry in Command Palette (`<C-Shift-P>`).
  - ZERO extra complexity for new languages: automatically works out of the box when any LSP attached supports CodeLens or reference requests.
- [x] **Phase 7: Wiki Documentation Center Modal (`<C-Shift-D>`)** ([`lua/plugins/krs/wiki_modal.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/lua/plugins/krs/wiki_modal.lua), [`docs/how-to-customize-editor.md`](file:///c:/Users/Kristan/AppData/Local/nvim/docs/how-to-customize-editor.md), [`tests/spec/wiki_modal_spec.lua`](file:///c:/Users/Kristan/AppData/Local/nvim/tests/spec/wiki_modal_spec.lua))
  - Dual-pane interactive Wikipedia modal (`<C-S-d>`).
  - Left pane: Categorized navigation index (Getting Started, How-To & Extension, Explanations & Architecture, Building & Debugging, UI & Workflow, Code Helpers).
  - Right pane: Live document reader with markdown formatting, syntax highlighting, and scrolling.
  - Comprehensive new How-To guide (`how-to-customize-editor.md`) explaining file structure, adding plugins, creating local `.krslocal` plugins, language setup, terminal tweaks, themes, tasks, and setup dependencies with easy copy-paste examples!
- [x] **Phase 8: Full Verification & Integration Test Suite** (`nvim -l tests/syntax_check.lua` & `nvim -l tests/run.lua`)
  - 174 files parsed cleanly with 0 syntax errors.
  - 325 unit tests passing (0 failures).

---

## 🧪 Verification Log

```bash
# Syntax check
nvim -l tests/syntax_check.lua
# Output: Parsed 174 files, 0 with syntax errors.

# Unit test suite
nvim -l tests/run.lua
# Output: Test Results: 325 Passed, 0 Failed
```
