-- Minimal, isolated debug setup. Loads NOTHING from your config.
--
--   nvim -u dapmin.lua path\to\file.ts
--
--   F9   toggle breakpoint       F5   launch this file
--   F10  step over               F11  step into
--   F8   terminate               F7   toggle dap-ui
--
-- If the code IS visible here when you stop at a breakpoint, the problem lives
-- in the main config and we bisect from there. If it is NOT visible here, the
-- problem is the environment (adapter, runtime, terminal), not the config.

local lazy = vim.fn.stdpath("data") .. "/lazy"
for _, plugin in ipairs({ "nvim-dap", "nvim-dap-ui", "nvim-nio" }) do
  vim.opt.runtimepath:append(lazy .. "/" .. plugin)
end

vim.o.number = true
vim.o.termguicolors = true
vim.o.mouse = "a"

-- `nvim -u <file>` skips the defaults, and without filetype detection
-- dap.continue() reports "No configuration found for ``".
vim.cmd("filetype plugin indent on")
vim.cmd("syntax on")

local dap = require("dap")
local dapui = require("dapui")

local server = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js"
if vim.fn.filereadable(server) == 0 then
  vim.notify("js-debug not found at " .. server, vim.log.levels.ERROR)
end

dap.adapters["pwa-node"] = {
  type = "server",
  host = "localhost",
  port = "${port}",
  executable = { command = "node", args = { server, "${port}" } },
}

for _, ft in ipairs({ "typescript", "javascript", "typescriptreact", "javascriptreact" }) do
  dap.configurations[ft] = {
    {
      type = "pwa-node",
      request = "launch",
      name = "Launch current file",
      program = "${file}",
      cwd = "${workspaceFolder}",
      console = "integratedTerminal",
      sourceMaps = true,
    },
  }
end

dapui.setup()

vim.fn.sign_define("DapBreakpoint", { text = "B", texthl = "ErrorMsg" })
vim.fn.sign_define("DapStopped", { text = ">", texthl = "WarningMsg", linehl = "Visual" })

dap.listeners.before.launch["ui"] = function()
  dapui.open()
end
dap.listeners.before.event_terminated["ui"] = function()
  dapui.close()
end
dap.listeners.before.event_exited["ui"] = function()
  dapui.close()
end

-- The one non-stock bit: js-debug reports pause-type stops with
-- allThreadsStopped=false, and nvim-dap skips the jump for those.
dap.listeners.after.event_stopped["jump_on_pause"] = function(session, body)
  if body.reason ~= "pause" or body.allThreadsStopped or not body.threadId then
    return
  end
  session:request("stackTrace", { threadId = body.threadId, startFrame = 0, levels = 1 }, function(err, resp)
    local frame = resp and resp.stackFrames and resp.stackFrames[1]
    if not err and frame and frame.source and frame.source.path then
      session:_frame_set(frame)
    end
  end)
end

-- Report every stop right in the message area, so it is obvious whether the
-- session stopped at all and where it thinks it is.
dap.listeners.after.event_stopped["report"] = function(session, body)
  vim.defer_fn(function()
    local frame = session.current_frame
    vim.notify(string.format(
      "stopped: reason=%s frame=%s line=%s",
      tostring(body.reason),
      frame and vim.fn.fnamemodify(tostring(frame.source and frame.source.path), ":t") or "NONE",
      frame and tostring(frame.line) or "-"
    ))
  end, 200)
end

vim.keymap.set("n", "<F9>", dap.toggle_breakpoint)
vim.keymap.set("n", "<F5>", dap.continue)
vim.keymap.set("n", "<F10>", dap.step_over)
vim.keymap.set("n", "<F11>", dap.step_into)
vim.keymap.set("n", "<F8>", function()
  dap.terminate()
  dapui.close()
end)
vim.keymap.set("n", "<F7>", dapui.toggle)
