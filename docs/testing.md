# 🧪 Testing

[← Back to Wiki Index](index.md)

This configuration has a test suite. It exists because a Neovim config fails at
the worst possible moment — on startup, in the middle of something else — and a
typo in a plugin file is invisible until then.

---

## 🏃 Running the tests

| Command | What it checks | Speed |
| :--- | :--- | :--- |
| `nvim -l tests/syntax_check.lua` | Every `.lua` file parses | instant |
| `nvim -l tests/run.lua` | Unit specs, no plugins loaded | ~1s |
| `nvim -l tests/run.lua tasks` | Only specs whose name contains "tasks" | ~1s |
| `nvim --headless -S tests/integration/run.lua` | Specs that need the real editor | a few seconds |
| `:KrsTest` | The unit specs, from inside the editor | ~1s |
| `:KrsTest git` | Filtered, from inside the editor | ~1s |

All of them exit non-zero on failure, so they work unchanged in CI or a git hook.

---

## 🗂️ Layout

```
tests/
├── run.lua              Unit runner: loads tests/spec/*_spec.lua, prints one summary
├── syntax_check.lua     Compiles (never runs) every Lua file in the repository
├── spec/                Unit specs -- pure logic, no plugins
│   ├── core_path_spec.lua
│   ├── core_store_spec.lua
│   ├── core_project_spec.lua
│   ├── core_ui_spec.lua
│   ├── core_dock_spec.lua
│   ├── tasks_spec.lua
│   ├── launch_runtimes_spec.lua
│   ├── tailwind_organizer_spec.lua
│   ├── git_status_spec.lua
│   ├── git_diff_spec.lua
│   ├── favorites_spec.lua
│   ├── code_action_menu_spec.lua
│   ├── context_help_spec.lua
│   └── wsl_spec.lua
└── integration/         Specs that need plugins and a real UI
    ├── run.lua
    ├── commands_spec.lua
    ├── dap_breakpoints_spec.lua
    └── dap_adapters_spec.lua
```

The `krsnvimscript` library keeps its own suite in `lua/krsnvim/tests/`, run with
`require("krsnvim.tests").run_all()`.

---

## ✍️ Writing a spec

Both runners use the same framework, `krsnvim.test` — the Vitest-style
`describe` / `it` / `expect` already shipped with the krsnvimscript library.

```lua
-- ============================================================================
-- tests/spec/my_feature_spec.lua -- What this file pins down.
-- ============================================================================
-- Why these particular cases matter.
-- ============================================================================

local t = require("krsnvim.test")
local describe, it, expect = t.describe, t.it, t.expect
local feature = require("krs.core.path")

describe("krs.core.path.normalize", function()
    it("converts backslashes to forward slashes", function()
        expect(feature.normalize([[C:\a\b]])).toBe("C:/a/b")
    end)
end)
```

Available matchers: `toBe`, `toEqual` (deep), `toBeTruthy`, `toBeFalsy`,
`toBeNil`, `toBeDefined`, `toContain`, `toHaveLength`, `toBeGreaterThan`,
`toBeGreaterThanOrEqual`, `toBeLessThan`, `toBeLessThanOrEqual`, `toThrow`, and
`not_` to invert any of them (`expect(x).not_.toBe(y)` — `not` is a Lua keyword,
so it cannot be used with a dot).

Lifecycle hooks: `beforeEach`, `afterEach`, `beforeAll`, `afterAll`.

### Rules

1. **Specs must be side-effect free.** No keymaps, no writes outside
   `vim.fn.tempname()`, no changing the working directory. Clean up in
   `afterEach`.
2. **Unit specs must not need a plugin.** If it needs telescope or nvim-dap, it
   belongs in `tests/integration/`, which boots the full config.
3. **Test the contract, not the implementation.** A spec that breaks whenever the
   code is reorganized is worse than no spec.
4. **Name the case, not the function.** `it("returns the fallback for malformed
   JSON")` beats `it("works")`.

---

## 🎯 What is covered

| Area | Spec | What it pins |
| :--- | :--- | :--- |
| Paths | `core_path_spec` | Drive letters, trailing slashes, case rules, relative paths |
| Persistence | `core_store_spec` | Corrupt and missing files degrade instead of throwing |
| Project config | `core_project_spec` | `.krsnvim` → `.krslocal` → `.nvimkrs` lookup ORDER |
| Floats | `core_ui_spec` | Fractional sizes, centering, clamping, dismiss keys |
| Bottom dock | `core_dock_spec` | Task output vs terminal classification, pane lookup |
| Task runner | `tasks_spec` | Chain resolution, `depends_on`, discovery, legacy files |
| Languages | `launch_runtimes_spec` | Command line and DAP config per runtime |
| Tailwind | `tailwind_organizer_spec` | Row assignment, sort order, attribute rewriting |
| Git | `git_status_spec`, `git_diff_spec` | Porcelain parsing, diff formatting and highlight tags |
| WSL | `wsl_spec` | UNC path parsing and the `wsl.exe --cd` command |
| Favorites | `favorites_spec` | Storage key format, toggle, rename, removal |
| Code actions | `code_action_menu_spec` | Ranking of quickfix / refactor / source actions |
| Context help | `context_help_spec` | Which surface `?` documents, and the editor fallback |
| Public surface | `commands_spec` (integration) | Every user command and keymap still registers |
| Breakpoints | `dap_breakpoints_spec` (integration) | Disable/enable/persist/restore round trip |
| Debug adapters | `dap_adapters_spec` (integration) | Every language still registers its configurations |

UI-heavy flows (pickers, modals in use, terminal execution) are deliberately not
covered: they need a driven UI, and the checks would be brittle. The logic behind
them is factored out into `lua/krs/`, which IS covered.
