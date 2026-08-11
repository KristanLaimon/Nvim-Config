-- ============================================================================
-- 🐹 Go — delve, via nvim-dap-go
-- ============================================================================
-- nvim-dap-go registers the adapter and the standard configurations (debug
-- file, debug test, attach), so there is nothing to add by hand here.
-- ============================================================================

return function(_)
	local ok, dap_go = pcall(require, "dap-go")
	if ok then
		dap_go.setup()
	end
end
