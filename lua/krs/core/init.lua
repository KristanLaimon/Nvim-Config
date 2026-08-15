-- ============================================================================
-- krs.core -- Shared foundation layer for every KRS module.
-- ============================================================================
-- WHAT LIVES HERE
--   path      Cross-platform path normalize / join / compare.
--   store     JSON file load & save that never throws.
--   project   Project root detection and `.krsnvim/` config resolution.
--   ui        Floating window and scratch buffer factory.
--   lazyspec  Unique lazy.nvim `dir` per local plugin spec.
--
-- RULES FOR THIS LAYER
--   * No module in krs.core may require anything from `plugins.*`. Dependencies
--     point downward only: plugins -> krs.core -> Neovim API.
--   * No global state, no autocmds, no keymaps. Pure helpers only.
--
-- USAGE -- require submodules directly, or the aggregate for convenience:
--   local path = require("krs.core.path")
--   local core = require("krs.core"); core.store.load(file, {})
-- ============================================================================

return {
	path = require("krs.core.path"),
	store = require("krs.core.store"),
	project = require("krs.core.project"),
	ui = require("krs.core.ui"),
	lazyspec = require("krs.core.lazyspec"),
	z_index = require("krs.core.z_index"),
	zindex = require("krs.core.z_index"),
}
