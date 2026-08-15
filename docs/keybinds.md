# ⌨️ Keybinds

Leader is `<Space>`. Global mappings live in `lua/config/keymaps/` — one file per domain (`editor`, `search`, `lsp`, `debug`, `krs`) — while module-local ones are defined by the module itself, in its `M.settings.keys` block.

Forgot one? `?` or `<F1>` shows a context-aware cheatsheet for whatever is focused, and `<C-S-p>` fuzzy-searches every registered command.

---

## 🛠️ General editing (VSCode-flavoured)

| Shortcut | Mode | Action |
| :--- | :---: | :--- |
| `<C-s>` | n, i, v | Save file (`:w`) |
| `<C-c>` | v | Copy selection to system clipboard |
| `<C-v>` / `<C-S-v>` | n, i, v, t | Paste from system clipboard |
| `<C-z>` | n, i, v | Undo |
| `<C-y>` / `<C-S-z>` | n, i | Redo |
| `<C-w>` | n | Close current buffer (tab-close style) |
| `<C-'>` / `<C-S-'>` / `<C-">` / `` <C-`> `` / `<C-~>` / `<C-^>` / `<C-acute>` | n, i, v, t | Toggle comment — line, or selection in visual mode |
| `<leader>ff` | n, v | Format file or selection (Conform, LSP fallback) |
| `<F2>` | n | Rename symbol, file on disk, or Neo-tree item |
| `<C-+>` / `<C-=>` | n, i, v, t | Increase font size (persisted) |
| `<C-->` | n, i, v, t | Decrease font size |
| `<C-0>` | n, i, v, t | Reset font size |
| `<leader>i` | n | View image as pixel art (`chafa`) |
| `<C-S-Enter>` | n | Open image/video with the OS default app |
| `<C-LeftMouse>` | all | Open the URL under the cursor in a browser |
| `:q` / `:q!` / `<leader>q` | n, Cmd | Smart quit — split → tab → dashboard → quit |
| `<leader>cd` | n | Open the default netrw directory browser |
| `<leader>mp` | n | Markdown preview |
| `:ReloadConfig` | Cmd | Reload the Neovim configuration |

> Commenting is mapped across a whole family of keys because `'` is a dead key on US-International, ES and Latam layouts — one of them will reach Neovim whatever your layout does. From terminal mode it leaves insert, hops to the previous window, and comments there.

---

## 🪟 Windows, splits & buffers

| Shortcut | Mode | Action |
| :--- | :---: | :--- |
| `<C-h>` / `<C-l>` | n | Focus left / right window |
| `<C-S-j>` / `<C-S-k>` | n | Focus bottom / top window |
| `<C-S-h>` / `<C-S-j>` / `<C-S-k>` / `<C-S-l>` | n, i, v | Find a file and open it in a split (left / down / up / right) |
| `<C-Left>` / `<C-Right>` | n | Widen / narrow the window |
| `<C-Up>` / `<C-Down>` | n | Taller / shorter |
| `gt` / `<A-l>` / `<A-Right>` | n | Next buffer |
| `gT` / `<A-h>` / `<A-Left>` | n | Previous buffer |
| `<C-A-Left>` / `<C-A-Right>` | n | Move the current tab left / right |
| `<leader>bh` / `<leader>bl` | n | Move the current tab left / right (leader variant) |

> While a debug session is running, `<C-S-j>` toggles the repl instead of moving down, and `<A-h>` / `<C-S-h>` flip the breakpoint under the cursor when there is one. Both fall through to the mapping above otherwise.

---

## 💡 LSP, diagnostics & completion

| Shortcut | Mode | Action |
| :--- | :---: | :--- |
| `K` | n | Hover documentation |
| `<A-k>` / `<M-k>` / `<A-j>` / `<M-j>` / `<C-S-d>` | n, i, v | Go to definition (Telescope fallback) |
| `<C-j>` | n, i, v | Signature / parameter help |
| `<C-.>` | n, i, v | Code actions / quick fix at the caret |
| `<leader>k` | n | Diagnostic float under the cursor |
| `<leader>u` / `<leader>o` | n | Previous / next diagnostic |
| `<C-o>` | n | Jump back in the jump list |
| `<CR>` | i | Accept the highlighted completion |
| `<C-space>` / `<C-@>` | i | Force the completion menu / documentation open |

---

## 🐞 Debugging

| Shortcut | Mode | Action |
| :--- | :---: | :--- |
| `<C-b>` | n, i, v | Toggle breakpoint |
| `<A-h>` / `<M-h>` / `<C-S-h>` | n, i, v | Enable ⇄ disable breakpoint under the cursor |
| `<C-S-s>` | n, i, v | Run the default [launch profile](launch-profiles.md) — or stop the running session |
| `<C-S-q>` | n, i, v | Launch profile manager |
| `<F5>` | n, i, v | Start / continue (raw DAP) |
| `<F10>` / `<F11>` / `<F12>` | n, i, v | Step over / into / out |
| `<C-S-x>` | n, i, v | Terminate the debugger and close the UI |
| `<leader>du` | n | Toggle the DAP UI |
| `<C-S-j>` | n | Toggle the repl (while a session is live) |
| `:DapBreakpointsDisableAll` / `EnableAll` / `RemoveAll` | Cmd | Bulk breakpoint operations |

---

## 🚀 Launch, tasks & terminals

| Shortcut | Mode | Action |
| :--- | :---: | :--- |
| `<C-S-t>` / `<leader>ta` | n, i, v | Task menu (select, run, set default `[d]`, add `[a]`, delete `[x]`) |
| `<C-S-a>` | n, i, v | Run the project's default task |
| `<C-1>`..`<C-4>` | n, i, v, t | Toggle the output window for background task slot 1-4 |
| `` <C-`> `` / `<C-[>` | n, i, v, t | Toggle the last-focused task output window |
| `:TaskRestart` / `:TaskKill` | Cmd | Restart / kill the active task |
| `<A-1>`..`<A-9>` | n, i, t | Select & switch to terminal #1-#9 (spawned on first use) |
| `<C-;>` / `<C-S-;>` / `<C-S-:>` / `<A-;>` / `<C-A-;>` | n, i, t | Toggle the selected terminal panel |
| `<C-w>c` | n (terminal) | Close the active terminal window |

> Up to 4 tasks run in the background at once; closing an output window doesn't kill the job. A terminal whose `cwd` sits inside a WSL distro path launches `wsl.exe` there automatically.

---

## 🗂️ Workspaces & sessions

| Shortcut / Command | Mode | Action |
| :--- | :---: | :--- |
| `<C-S-w>` / `<leader>ww` | n, i, v, t | Open the Workspaces picker |
| `<leader>ws` | n | Save the current UI state as a workspace |
| `<C-S-m>` / `<leader>wm` | n, i, v, t | Close the session and return to the dashboard (with save prompt) |
| `<leader>w1`..`<leader>w9` | n | Load workspace slot 1-9 directly |
| `:WorkspaceSave [name]` / `:WorkspaceLoad [name\|slot]` | Cmd | Save / load by name or slot |
| `:WorkspaceDelete` / `:WorkspaceRename` | Cmd | Delete / rename |
| `:Workspaces` / `:WorkspaceSelect` | Cmd | Open the picker |

**Inside the picker:** `<Enter>` load · `a`/`<C-a>` save as new · `s`/`<C-s>` overwrite · `d`/`<C-d>`/`<Del>` delete · `r`/`<C-r>`/`<F2>` rename · `g`/`<C-g>` toggle current-project vs all-projects · `1`-`9` jump to slot.

---

## 🔍 Finding things

| Shortcut | Mode | Action |
| :--- | :---: | :--- |
| `<C-k>` / `<C-/>` / `<C-_>` | n, i | Find files, respecting `.gitignore` |
| `<C-A-k>` / `<C-S-/>` / `<C-?>` / `<leader>fa` | n, i, v | Find files, ignoring `.gitignore` |
| `<C-f>` | n, i | Live grep across the project |
| `<C-S-o>` | n, i, v, t | Sneak-Peek project modal (90% width & height on-top window) |
| `<C-S-f>` | n, i, v | Floating Desktop file explorer |
| `<leader>fw` | n, i, v | Floating WSL file explorer (Windows only) |
| `<C-S-r>` | n | Recent projects |
| `<leader>fh` | n | Search help tags |
| `<C-S-p>` | n, i, v, t | Command palette |

**Inside Recent Projects:** `<C-f>` toggles favourite (pins to the bottom), `<C-r>` removes from history.

---

## 🌴 Neo-tree

| Shortcut | Context | Action |
| :--- | :---: | :--- |
| `<leader>e` / `<C-S-Space>` | n | Toggle the sidebar |
| `a` / `A` / `<C-n>` | Neo-tree | New file or folder (end with `/` for a folder) |
| `r` | Neo-tree | Rename via the input modal |
| `d` | Neo-tree | Delete |
| `c` | Neo-tree | Copy |
| `m` | Neo-tree | Move via the floating explorer (`O` confirms the destination) |

---

## 🐙 Git

| Shortcut | Mode | Action |
| :--- | :---: | :--- |
| `<C-S-g>` | n, i, v, t | Toggle the [Git Control Center](git-center.md) |
| `<A-h>` / `<A-l>` | Git Center | Switch previous / next submodule repository tab |
| `s` / `S` | Git Center | Stage selected / stage all |
| `u` / `U` | Git Center | Unstage selected / unstage all |
| `r` / `R` | Git Center | Restore file under cursor / whole section (confirmed) |
| `c` / `m` / `t` | Git Center | Edit commit title / description / tag |
| `C` | Git Center | Commit (and tag) |
| `P` | Git Center | Push (confirmed, with remote branch selector) |
| `<Enter>` | Neogit status | Open the diff in a vertical split |
| `d` | Neogit status | Quick diff preview |

---

## 📦 Language-specific

| Shortcut / Command | Action |
| :--- | :--- |
| `<leader>ng` / `:NugetManager` | Nuget picker for the project's `.csproj` (`a` add, `u` update, `d` remove) |
| `<leader>ns` / `<leader>nc` | Show / hide inline `package.json` versions |
| `<leader>nu` / `<leader>nd` / `<leader>ni` / `<leader>np` | Update / delete / install / change version of the package under the cursor |
| `<leader>tw` / `:TailwindOrganize` | [Organize Tailwind classes](tailwind-organizer.md) in the current buffer |
| `<leader>tt` / `:TailwindOrganizerToggle` | Toggle organize-on-save |
| `:KrsTypes` / `:TypeInjector` | [Type injector](type-injector.md) menu |
| `:PHPCheckTools` | PHP / Composer / Intelephense / Pint / Xdebug diagnostic modal |
| `:KrsBunDapInstall` | Build the Bun debug adapter |
| `:NvimWiki` | Open this wiki |
