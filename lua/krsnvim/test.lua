--- @module "krsnvim.test"
--- Vitest / Bun:test inspired Testing Framework for `krsnvimscript`.
--- Provides `describe`, `test`/`it`, `expect`, and lifecycle hooks (`beforeEach`, `afterEach`, `beforeAll`, `afterAll`).
--- Explicitly imported via `local t = import("test"); local describe, test, expect = t.describe, t.test, t.expect`.
---
--- @example
--- local t = import("test")
--- local describe, it, expect = t.describe, t.it, t.expect
---
--- describe("Math Operations", function()
---     it("should add numbers correctly", function()
---         expect(2 + 2).toBe(4)
---         expect({ a = 1 }).toEqual({ a = 1 })
---         expect("neovim").toContain("vim")
---         expect(10).not.toBe(5)
---     end)
--- end)
---
--- t.run()
local M = {}

local state = {
	current_suite = nil,
	suites = {},
}

-- ----------------------------------------------------------------------------
-- Deep Equality & Formatting Helpers
-- ----------------------------------------------------------------------------
local function deep_equal(a, b)
	if a == b then return true end
	local ta, tb = type(a), type(b)
	if ta ~= tb then return false end
	if ta ~= "table" then return false end

	for k, v in pairs(a) do
		if not deep_equal(v, b[k]) then return false end
	end
	for k, _ in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end

local function format_val(v)
	local t = type(v)
	if t == "string" then
		return '"' .. v .. '"'
	elseif t == "table" then
		local ok, json = pcall(require("krsnvim.json").encode, v)
		if ok and json then return json end
		return tostring(v)
	else
		return tostring(v)
	end
end

-- ----------------------------------------------------------------------------
-- Expect Assertion Class & Matchers
-- ----------------------------------------------------------------------------

--- @class ExpectMatchers
--- @field toBe function(expected: any) Strict equality check (`actual == expected`).
--- @field toEqual function(expected: any) Deep equality check for tables, objects, and arrays.
--- @field toBeTruthy function() Asserts that value is not `nil` and not `false`.
--- @field toBeFalsy function() Asserts that value is `nil` or `false`.
--- @field toBeNil function() Asserts that value is `nil`.
--- @field toBeNull function() Alias for `toBeNil()`.
--- @field toBeUndefined function() Alias for `toBeNil()`.
--- @field toBeDefined function() Asserts that value is not `nil`.
--- @field toContain function(item: any) Asserts string contains substring or table contains item.
--- @field toHaveLength function(len: number) Asserts length `#val` equals `len`.
--- @field toBeGreaterThan function(num: number) Asserts `actual > num`.
--- @field toBeGreaterThanOrEqual function(num: number) Asserts `actual >= num`.
--- @field toBeLessThan function(num: number) Asserts `actual < num`.
--- @field toBeLessThanOrEqual function(num: number) Asserts `actual <= num`.
--- @field toThrow function(expected_err: string|nil) Asserts function throws an error when invoked.
--- @field ["not"] ExpectMatchers Inverted assertions builder.
--- @field not_ ExpectMatchers Alias of `not`, usable with dot access (`not` is a keyword).
--- @field isNot ExpectMatchers Alias of `not`.

local function create_expect(actual, is_not)
	local matchers = {}

	local function assert_cond(cond, msg_pass, msg_fail)
		if is_not then
			if cond then
				error(msg_pass, 3)
			end
		else
			if not cond then
				error(msg_fail, 3)
			end
		end
	end

	matchers.toBe = function(expected)
		assert_cond(
			actual == expected,
			"Expected value NOT to be " .. format_val(expected) .. ", but got " .. format_val(actual),
			"Expected " .. format_val(actual) .. " to be " .. format_val(expected)
		)
	end

	matchers.toEqual = function(expected)
		assert_cond(
			deep_equal(actual, expected),
			"Expected value NOT to equal " .. format_val(expected) .. ", but got " .. format_val(actual),
			"Expected " .. format_val(actual) .. " to equal " .. format_val(expected)
		)
	end

	matchers.toBeTruthy = function()
		local truthy = (actual ~= nil and actual ~= false)
		assert_cond(
			truthy,
			"Expected " .. format_val(actual) .. " NOT to be truthy",
			"Expected " .. format_val(actual) .. " to be truthy"
		)
	end

	matchers.toBeFalsy = function()
		local falsy = (actual == nil or actual == false)
		assert_cond(
			falsy,
			"Expected " .. format_val(actual) .. " NOT to be falsy",
			"Expected " .. format_val(actual) .. " to be falsy"
		)
	end

	matchers.toBeNil = function()
		assert_cond(
			actual == nil,
			"Expected value NOT to be nil, but got " .. format_val(actual),
			"Expected " .. format_val(actual) .. " to be nil"
		)
	end
	matchers.toBeNull = matchers.toBeNil
	matchers.toBeUndefined = matchers.toBeNil

	matchers.toBeDefined = function()
		assert_cond(
			actual ~= nil,
			"Expected value NOT to be defined, but got nil",
			"Expected value to be defined, but got nil"
		)
	end

	matchers.toContain = function(item)
		local found = false
		if type(actual) == "string" then
			found = actual:find(tostring(item), 1, true) ~= nil
		elseif type(actual) == "table" then
			for _, v in pairs(actual) do
				if deep_equal(v, item) then
					found = true
					break
				end
			end
		end
		assert_cond(
			found,
			"Expected " .. format_val(actual) .. " NOT to contain " .. format_val(item),
			"Expected " .. format_val(actual) .. " to contain " .. format_val(item)
		)
	end

	matchers.toHaveLength = function(expected_len)
		local actual_len = 0
		if type(actual) == "string" or type(actual) == "table" then
			actual_len = #actual
		end
		assert_cond(
			actual_len == expected_len,
			"Expected length NOT to be " .. tostring(expected_len) .. ", but got " .. tostring(actual_len),
			"Expected length to be " .. tostring(expected_len) .. ", but got " .. tostring(actual_len)
		)
	end

	matchers.toBeGreaterThan = function(num)
		assert_cond(
			actual > num,
			"Expected " .. format_val(actual) .. " NOT to be > " .. format_val(num),
			"Expected " .. format_val(actual) .. " to be > " .. format_val(num)
		)
	end

	matchers.toBeGreaterThanOrEqual = function(num)
		assert_cond(
			actual >= num,
			"Expected " .. format_val(actual) .. " NOT to be >= " .. format_val(num),
			"Expected " .. format_val(actual) .. " to be >= " .. format_val(num)
		)
	end

	matchers.toBeLessThan = function(num)
		assert_cond(
			actual < num,
			"Expected " .. format_val(actual) .. " NOT to be < " .. format_val(num),
			"Expected " .. format_val(actual) .. " to be < " .. format_val(num)
		)
	end

	matchers.toBeLessThanOrEqual = function(num)
		assert_cond(
			actual <= num,
			"Expected " .. format_val(actual) .. " NOT to be <= " .. format_val(num),
			"Expected " .. format_val(actual) .. " to be <= " .. format_val(num)
		)
	end

	matchers.toThrow = function(expected_err)
		if type(actual) ~= "function" then
			error("expect(fn).toThrow() requires a function argument", 3)
		end
		local ok, err = pcall(actual)
		local threw = not ok
		local matches_err = true
		if threw and expected_err then
			matches_err = tostring(err):find(tostring(expected_err), 1, true) ~= nil
		end
		assert_cond(
			threw and matches_err,
			"Expected function NOT to throw error matching " .. format_val(expected_err or "any"),
			threw and ("Expected error message to contain " .. format_val(expected_err) .. ", got: " .. tostring(err)) or "Expected function to throw an error, but it executed successfully"
		)
	end

	if not is_not then
		local inv = create_expect(actual, true)
		matchers["not"] = inv
		matchers.not_ = inv
		matchers.isNot = inv
	end

	return matchers
end

--- Creates an assertion builder object for `actual` value with chainable matchers.
---
--- @param actual any The value or function to test.
--- @return ExpectMatchers matchers Object containing `.toBe()`, `.toEqual()`, `.not`, etc.
---
--- @example
--- expect(5).toBe(5)
--- expect("hello").toContain("ell")
--- expect({ a = 1 }).toEqual({ a = 1 })
--- expect(10).not.toBe(5)
function M.expect(actual)
	return create_expect(actual, false)
end

-- ----------------------------------------------------------------------------
-- Suite & Test Registration
-- ----------------------------------------------------------------------------

--- Groups related test cases into a test suite block.
---
--- @param suite_name string Name/description of the test suite.
--- @param suite_fn function Callback function containing `test()` or `it()` definitions.
---
--- @example
--- describe("User Service", function()
---     it("should create user", function() ... end)
--- end)
function M.describe(suite_name, suite_fn)
	local suite = {
		name = suite_name,
		tests = {},
		before_each = {},
		after_each = {},
		before_all = {},
		after_all = {},
	}
	local prev_suite = state.current_suite
	state.current_suite = suite
	table.insert(state.suites, suite)

	local ok, err = pcall(suite_fn)

	state.current_suite = prev_suite
	if not ok then
		error("Error in describe block '" .. tostring(suite_name) .. "': " .. tostring(err))
	end
end

--- Defines a test case within a `describe()` block.
---
--- @param test_name string Name of the test case.
--- @param test_fn function Callback function executing test assertions.
---
--- @example
--- it("should calculate total", function()
---     expect(10 + 20).toBe(30)
--- end)
function M.test(test_name, test_fn)
	if not state.current_suite then
		M.describe("Default Test Suite", function()
			M.test(test_name, test_fn)
		end)
		return
	end
	table.insert(state.current_suite.tests, {
		name = test_name,
		fn = test_fn,
	})
end

--- Alias for `test()`.
M.it = M.test

--- Registers a setup hook to run before each test case in the current suite.
--- @param fn function
function M.beforeEach(fn)
	if state.current_suite then
		table.insert(state.current_suite.before_each, fn)
	end
end

--- Registers a teardown hook to run after each test case in the current suite.
--- @param fn function
function M.afterEach(fn)
	if state.current_suite then
		table.insert(state.current_suite.after_each, fn)
	end
end

--- Registers a setup hook to run once before all tests in the current suite.
--- @param fn function
function M.beforeAll(fn)
	if state.current_suite then
		table.insert(state.current_suite.before_all, fn)
	end
end

--- Registers a teardown hook to run once after all tests in the current suite.
--- @param fn function
function M.afterAll(fn)
	if state.current_suite then
		table.insert(state.current_suite.after_all, fn)
	end
end

-- ----------------------------------------------------------------------------
-- Test Suite Execution & Output Formatting
-- ----------------------------------------------------------------------------

--- Executes all registered `describe` and `test` blocks and prints formatted results.
---
--- @return table summary Object containing `passed`, `failed`, and `duration` (ms).
---
--- @example
--- local test_runner = import("test")
--- test_runner.describe("Sample Test", function()
---     test_runner.it("passes", function()
---         test_runner.expect(1).toBe(1)
---     end)
--- end)
--- test_runner.run()
function M.run()
	local total_passed = 0
	local total_failed = 0
	local get_time = function()
		if vim and vim.uv and vim.uv.hrtime then
			return vim.uv.hrtime() / 1e6
		end
		return os.clock() * 1000
	end

	local start_time = get_time()

	print("\n==========================================")
	print(" 🧪 Running krsnvim.test Test Runner")
	print("==========================================")

	for _, suite in ipairs(state.suites) do
		print("\n 📦 " .. suite.name)

		for _, fn in ipairs(suite.before_all) do
			pcall(fn)
		end

		for _, t in ipairs(suite.tests) do
			for _, fn in ipairs(suite.before_each) do
				pcall(fn)
			end

			local t_start = get_time()
			local ok, err = pcall(t.fn)
			local elapsed = math.floor(get_time() - t_start)

			if ok then
				total_passed = total_passed + 1
				print(string.format("   ✓ %s (%dms)", t.name, elapsed))
			else
				total_failed = total_failed + 1
				print(string.format("   ❌ %s (%dms)", t.name, elapsed))
				print("      Error: " .. tostring(err))
			end

			for _, fn in ipairs(suite.after_each) do
				pcall(fn)
			end
		end

		for _, fn in ipairs(suite.after_all) do
			pcall(fn)
		end
	end

	local total_time = math.floor(get_time() - start_time)
	print("\n==========================================")
	print(string.format(" Test Results: %d Passed, %d Failed (%dms)", total_passed, total_failed, total_time))
	print("==========================================\n")

	-- Reset state for subsequent test runs
	state.suites = {}
	state.current_suite = nil

	if total_failed > 0 then
		error("Test suite failed with " .. total_failed .. " error(s).")
	end

	return { passed = total_passed, failed = total_failed, duration = total_time }
end

return M
