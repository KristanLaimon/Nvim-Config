# 🦊 KRS Neovim Configuration Wiki

Welcome to the official documentation and wiki for **KRS Neovim**, a custom, high-performance, modular Neovim configuration built for speed, productivity, and modern floating UI components.

---

## 📌 Quick Table of Contents

| Topic | Description |
| :--- | :--- |
| ⌨️ [**Keyboard Shortcuts & Keybinds**](keybinds.md) | Complete list of all QOL, LSP, navigation, split, and module keybindings |
| 📝 [**Reusable Input Modal Component**](input-modal.md) | Documentation on the floating input dialog used for rename, new files, and git commits |
| 🖥️ [**Multi-Terminal Manager**](terminals.md) | 9 independent terminal buffers with `<Alt+1..9>` switching and `<C-;>` toggling |
| 🛠️ [**Task Runner & Chains**](tasks.md) | Per-project build runner, task chains, background slots, and `<C-S-;>` output window |
| 🗂️ [**Workspaces & Session Manager**](workspaces.md) | Project workspace saving/loading (`<C-S-w>`), clean session state excluding terminals |
| 🐙 [**Git Control Center**](git-center.md) | Instant Git Control Center (`<C-S-g>`), staging, restore (`r`/`R`), push (`P`), live diffs |
| 📁 [**File Explorers & Move Picker**](file-explorer.md) | Desktop & WSL explorers, folder picker, and Neo-tree move file picker (`m` / `O`) |
| 🎨 [**Color Palette & Aesthetics**](color-palette.md) | Modern color schemes, highlights, and custom visual elements |
| 🧰 [**Command Palette**](command-palette.md) | Interactive command launcher and utility shortcuts |
| 🌐 [**Adding Languages & LSPs**](adding-language.md) | Installing and configuring new LSPs, formatters, and linters |
| 📄 [**JSON & TOML Schemas**](schemas-json.md) | Auto-validation and completion for configuration files |

---

## 🚀 Key Features Overview

1. **Ultra-Fast & Modular Architecture**
   - Built on `lazy.nvim` with custom modules in `lua/config/krs/` and `lua/plugins/krs/`.
   - Asynchronous execution for instant UI response (< 30ms loading times).

2. **Unified Custom Floating UI**
   - Clean, rounded floating dialogs for input prompts, diagnostics, code actions, terminals, git control, and file exploration.
   - Global `vim.ui.input` override utilizing the reusable `input_modal` component.

3. **International Keyboard Layout Support**
   - Native keymap support for both **US Standard** and **US International** keyboard layouts (`<C-'>`, `<C-/>`, `<C-_>`, `<C-S-'>`).
   - Clean terminal mode (`t` mode) key handling without PTY character leakage.

4. **Clean Session & Workspace Preservation**
   - Sessions isolate project state and window layouts without saving stale terminal buffers or polluting recent project history when viewing documentation.

---

## 💡 Quick Launch Shortcuts

- **Dashboard / Main Menu**: `<Ctrl + Shift + M>`
- **Workspaces Picker**: `<Ctrl + Shift + W>`
- **Git Control Center**: `<Ctrl + Shift + G>`
- **Desktop File Explorer**: `<Ctrl + Shift + F>`
- **Project Tasks Menu**: `<Ctrl + Shift + T>`
- **Toggle Task Output**: `<Ctrl + Shift + ;>`
- **Toggle Active Terminal**: `<Ctrl + ;>`
- **Select Terminal #1..9**: `<Alt + 1..9>`
