# 🐙 Interactive Git Control Center (`plugins.krs.git_center`)

The **Git Control Center** (`<C-S-g>`) is a high-speed, interactive floating Git interface with live VSCode-style diff previews, branch status tracking, and one-key staging/commit/push operations.

---

## ⚡ Highlights

- **Instant Opening (< 30ms)**: Asynchronous status parsing without heavy background Git log scans.
- **Git Submodules & Repository Tabs**: Aesthetic tab bar integrated directly at the top of the control panel with support for Git submodules. Root repository is always on the far-left tab, followed by submodules sorted alphabetically.
- **Persistent Active Tab**: Active submodule tab is saved per-project in `.krsnvim/git-center.json` so re-opening Git Center returns directly to the last active submodule repository.
- **VSCode Live Diff Preview**: Right-hand preview window displays soft green (`+`) and soft red (`-`) highlighted diffs dynamically while moving the cursor over changed files.
- **Staging & Unstaging**: Single file staging/unstaging (`s`/`u`) and bulk staging/unstaging (`S`/`U`) scoped to the selected submodule repository.
- **File & Section Restore**: Discard changes for single file (`r`) or entire section (`R`) with confirmation dialogs.
- **Remote Push**: Execute `git push` (`P`) with automatic upstream tracking detection or interactive remote branch selection.
- **Commit & Tag Box**: Multi-line commit title (`c`), description (`m`), and optional tag (`t`) via the `input_modal` component.

---

## ⌨️ Git Center Shortcuts

| Key | Mode | Action |
| :--- | :---: | :--- |
| `<C-S-g>` | All | Toggle Git Control Center open / close |
| `<A-h>` / `<M-h>` | Normal, Visual, Insert, Terminal | Switch to Previous Submodule Tab (Left) |
| `<A-l>` / `<M-l>` | Normal, Visual, Insert, Terminal | Switch to Next Submodule Tab (Right) |
| `s` | Normal, Visual | Stage selected file or selection |
| `S` | Normal, Visual | Stage all files |
| `u` | Normal, Visual | Unstage selected file or selection |
| `U` | Normal, Visual | Unstage all files |
| `r` | Normal | Discard changes / Restore selected file (with confirmation) |
| `R` | Normal | Discard changes / Restore entire section (with confirmation) |
| `P` | Normal | Push to remote (with confirmation and remote branch selector) |
| `c` | Normal | Edit Commit Title via `input_modal` |
| `m` | Normal | Edit Commit Description via `input_modal` |
| `t` | Normal | Edit Optional Tag via `input_modal` |
| `C` | Normal | Execute Commit & Tag |
| `<Tab>` | Normal | Toggle focus between left control panel and right live preview |
| `<C-S-j>` / `<C-S-k>` | Normal | Scroll right live diff preview window |
| `d` | Normal | Open selected file diff in full-screen floating modal UI (no CWD change) |
| `<F5>` / `<C-r>` | Normal | Refresh Git status |

