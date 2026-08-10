-- Self-check for the Type Injector reference generation + tsconfig handling.
-- Run: nvim --headless -u init.lua -c "luafile scratch/test_type_injector.lua"
-- Asserts only; prints OK and exits 0, or throws.

local ti = require("config.krs.type_injector")

local store = ti.get_schemas_base_dir("typescript_javascript") .. "/__selfcheck"
local entry = store .. "/node_modules/@types/fake/index.d.ts"

-- fake npm-style schema: @types package with a sibling runtime dep
vim.fn.mkdir(store .. "/node_modules/@types/fake", "p")
vim.fn.mkdir(store .. "/node_modules/fake-dep", "p")
vim.fn.writefile({ "declare module 'fake' {}" }, entry)

local function new_project()
	local p = vim.fs.normalize(vim.fn.tempname()) .. "/proj"
	vim.fn.mkdir(p, "p")
	-- an ancestor tsconfig would make the "no config anywhere" cases meaningless
	local above = vim.fs.find({ "tsconfig.json", "jsconfig.json" }, { path = p, upward = true, type = "file" })
	assert(#above == 0, "stray config above the temp dir invalidates this test: " .. (above[1] or ""))
	return p
end

local function read(path)
	return table.concat(vim.fn.readfile(path), "\n")
end

-- 1. bare project: config is created, reference points into the store
local proj = new_project()
ti.sync_ts_type_links(proj, { "__selfcheck" })

local ref = proj .. "/" .. ti.REF_FILE
assert(ti.REF_FILE:find("^%.krsnvim/"), "generated file belongs in .krsnvim/")
assert(read(ref):find('reference path="' .. entry .. '"', 1, true), "reference must be absolute into the store")
assert(not read(ref):find("fake-dep", 1, true), "runtime deps resolve on their own, must not be referenced")
assert(vim.uv.fs_lstat(proj .. "/node_modules") == nil, "activation must not create node_modules")

local cfg = read(proj .. "/tsconfig.json")
assert(vim.json.decode(cfg).compilerOptions.allowJs == true, "created tsconfig must set allowJs")
assert(cfg:find(ti.INCLUDE_GLOB, 1, true), "created tsconfig must include the .krsnvim glob")

ti.sync_ts_type_links(proj, {})
assert(vim.uv.fs_lstat(ref) == nil, "deactivating must remove the reference file")

-- 2. existing config: include is extended in place, comments survive
proj = new_project()
vim.fn.writefile({ "{", "\t// keep me", '\t"include": ["src/**/*"]', "}" }, proj .. "/tsconfig.json")
ti.sync_ts_type_links(proj, { "__selfcheck" })
cfg = read(proj .. "/tsconfig.json")
assert(cfg:find("// keep me", 1, true), "comments must survive the include patch")
assert(cfg:find("src/%*%*/%*"), "existing include entries must survive")
assert(cfg:find(ti.INCLUDE_GLOB, 1, true), "glob was not added to existing include")

-- idempotent: a second activation must not add it twice
ti.sync_ts_type_links(proj, { "__selfcheck" })
local _, n = read(proj .. "/tsconfig.json"):gsub(vim.pesc(ti.INCLUDE_GLOB), "")
assert(n == 1, "include glob added " .. n .. " times, must be idempotent")

-- 3. config with no include key at all
proj = new_project()
vim.fn.writefile({ '{ "compilerOptions": { "strict": true } }' }, proj .. "/tsconfig.json")
ti.sync_ts_type_links(proj, { "__selfcheck" })
local parsed = vim.json.decode(read(proj .. "/tsconfig.json"))
assert(vim.tbl_contains(parsed.include, "**/*"), "adding include must preserve the default **/*")
assert(vim.tbl_contains(parsed.include, ti.INCLUDE_GLOB), "glob missing from generated include")
assert(parsed.compilerOptions.strict == true, "existing compilerOptions must survive")

-- 4. config above the project root: glob is rewritten relative to it
proj = new_project()
vim.fn.writefile({ "{}" }, proj .. "/tsconfig.json")
local pkg = proj .. "/packages/app"
vim.fn.mkdir(pkg, "p")
ti.sync_ts_type_links(pkg, { "__selfcheck" })
assert(vim.uv.fs_lstat(pkg .. "/tsconfig.json") == nil, "must not create a config under a parent one")
assert(
	read(proj .. "/tsconfig.json"):find("packages/app/" .. ti.INCLUDE_GLOB, 1, true),
	"parent config needs the glob relative to itself"
)

vim.fn.delete(store, "rf")
print("OK: type_injector references + tsconfig handling")
