-- ============================================================================
-- KRS PHP: Centralized PHP Language Configuration Entry Point
-- ============================================================================
-- WHAT IT DOES
--   Central entry point for PHP environment configurations and language submodules:
--   - Composer vendor bin PATH prepending (`krs.langs.php.composer`)
--   - PHP/Laravel toolchain check modal (`plugins.krs.php_tools_modal`)
-- ============================================================================

local M = {}

M.composer = require("krs.langs.php.composer")
M.modal = require("plugins.krs.php_tools_modal")

--- Initialize PHP language configurations.
function M.setup()
	M.composer.setup()
end

return M
