---
name: krsnvimscript
description: Write, run, test and transpile `.krsnvim` automation scripts (Lua-based build/CLI scripting suite shipped with the user's Neovim config at %LOCALAPPDATA%\nvim\lua\krsnvim). Use whenever a task needs a build script, task runner, CLI tool, HTTP call, or JSON/YAML/TOML file handling and the user wants it in krsnvimscript, mentions `.krsnvim`, `krsnvim.*`, `import()`, `KrsExport`, or asks for a script that must also run as `.sh` and `.ps1`.
---

# krsnvimscript

Lua automation suite living in the user's Neovim config (`lua/krsnvim/`). Scripts are plain Lua in `*.krsnvim` files. Runs anywhere Neovim is installed — no Node, no Python, no curl. Optionally transpiles to native `.sh` + `.ps1` for CI/servers.

Use it for: build scripts, task runners, small CLI tools, HTTP calls, config file read/write, test suites.
Do NOT use it for: application code, plugin code, anything that must run without Neovim (transpile instead).

## Run a script

```bash
nvim --headless -c "lua require[[krsnvim]].setup_globals()" -l build.krsnvim
```

Inside Neovim: `<C-,>` runs/saves current script (or opens Launch Profiles). `<C-S-,>` opens the wiki docs.
`.krsnvim` files register as filetype `krsnvim` with Lua syntax.

## Globals

`setup_globals()` injects four globals — no require needed: `krsnvim`, `console`, `fetch`, `import`.
Everything else: `import("fs")`, `import("json")`, ... Aliases work with or without prefix (`"fs"` == `"krsnvim.fs"`).

`import()` also loads data files by extension: `import("package.json")`, `import("config.yaml")`, `import("Cargo.toml")` return parsed tables.

## API

`import("terminal")` — call it directly, commonly aliased `$`:
```lua
local $ = import("terminal")
local res = $("git status")      -- { code, ok, stdout, stderr, output }
assert(res.ok, "git failed: " .. res.code)
$.cwd()                          -- string
$.is_windows                     -- boolean
```
Runs `cmd.exe /C` on Windows, `bash -c` elsewhere. Sync only.

`fs` — `exists(path)`, `read(path)` (throws if missing), `write(path, content)`, `mkdir(path)` (recursive, mkdir -p), `list(dir)` (one level, returns array of paths).

`json` / `yaml` / `toml` — same shape each: `decode(str)`, `encode(obj)`, `load(filepath)`, `save(filepath, obj)`. Pure Lua parsers, no external tools.

`fetch` — web-standard client, pure Lua sockets for http, native OS TLS for https:
```lua
local res = fetch.get("https://api.github.com/zen")
res.status, res.ok, res.headers, res.body, res.url
res:text()                       -- raw body
res:json()                       -- parsed table, or nil, err
fetch.post(url, { name = "x" })  -- table body auto-encodes JSON + Content-Type
```
Also `put`, `patch`, `delete`, `head`, and `fetch(url, opts)`.
`opts`: `method`, `headers`, `body` (table auto-JSON), `query` (table, auto percent-encoded), `timeout` (ms, default 15000), `callback(err, res)` for async.
Headers are case-insensitive both directions.

`console` — `log`, `info`, `warn`, `error`, `debug` (all pretty-print tables as JSON, handle cycles), `json(obj, indent)`, `dir(obj)`.

`cli`:
```lua
local cli = import("cli")
local args = cli.parse_args({ "--verbose", "--env=prod", "input.txt" })
-- args.flags.verbose == true, args.flags.env == "prod", args.positional[1] == "input.txt"
cli.menu("Pick:", { "Build", "Test", "Clean" }, function(choice, idx) ... end)
cli.help(schema)                 -- schema: { name, description, options }
```

`tests` — Vitest/bun:test style: `describe`, `test`/`it`, `expect`, `beforeEach`, `afterEach`, `beforeAll`, `afterAll`, `run()`.
Matchers: `toBe`, `toEqual` (deep), `toBeTruthy`, `toBeFalsy`, `toBeNil`/`toBeNull`/`toBeUndefined`, `toBeDefined`, `toContain`, `toHaveLength`, `toBeGreaterThan(OrEqual)`, `toBeLessThan(OrEqual)`, `toThrow`. Negate with `expect(x).not_.toBe(y)` or `.isNot` (`not` is a Lua keyword — use `not_`).

## Transpile to .sh / .ps1

For CI runners or machines without Neovim.

```lua
local t = import("krsnvimtranspiler")
t.export_sh("build.krsnvim")     -- build.sh
t.export_ps1("build.krsnvim")    -- build.ps1
t.export_both("build.krsnvim")   -- { sh = ..., ps1 = ... }
t.to_sh(code_string)             -- returns script text
```
Commands: `:KrsExport [sh|ps1|both] [out]`, `:KrsExportSh`, `:KrsExportPs1`.

Transpiler covers a subset: functions, `print`, `assert`, `error`, `fs.*`, `fetch.get/json`, `json.*`, `yaml.load`, `$ "cmd"`, numeric/ipairs `for`, `while`. Anything outside that (closures, metatables, `cli.menu`, `tests`) will not transpile cleanly — keep transpile-targeted scripts flat and imperative.

## Project config

Per-project state lives in `.krsnvim/` at the project root (fallbacks: `.krslocal`, `.nvimkrs`): `tasks.json`, `launch.json`, `breakpoints.json`, `git-center.json`. Launch profiles can run a script with runtime `krsnvimscript`, or transpile it with runtime `krsnvimtranspiler` (`args` = `sh` | `ps1` | anything else = both).

## Style

Match the user's existing scripts: `local x = import("...")` at top, `console.log` over `print` for structured data, check `res.ok` after every `$()`, `assert` with a message on failure paths.

```lua
-- build.krsnvim
local $ = import("terminal")
local fs = import("fs")
local pkg = import("package.json")

console.log("Building", pkg.name, pkg.version)
fs.mkdir("dist")

local res = $("bun run build")
assert(res.ok, "build failed: " .. res.output)

fs.write("dist/VERSION", pkg.version)
console.info("Done")
```

## Full docs

`lua/krsnvim/docs/*.md` in the nvim config: `index.md`, `fetch.md`, `console.md`, `cli.md`, `terminal.md`, `import.md`, `json_yaml_toml.md`, `test.md`, `krsnvimtranspiler.md`. Source is heavily annotated with `@param`/`@return`/`@example` — read `lua/krsnvim/<module>.lua` when a signature is unclear. Tests/usage examples: `lua/krsnvim/tests/*_spec.lua`.
