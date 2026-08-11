-- Debug-session diagnostic. Temporary file, delete when done.
--
--   :luafile dapdiag.lua      <- load it, then start a debug session as usual
--   :DapDiagOpen              <- open the log it wrote
--
-- Logs every DAP event, the config actually launched, and the window/buffer
-- state at each stop, so we can see why the source is not showing.

local dap = require("dap")
local logfile = vim.fn.stdpath("state") .. "/dapdiag.log"

local f = io.open(logfile, "w")
local start = vim.loop.hrtime()

local function log(fmt, ...)
  local ok, line = pcall(string.format, fmt, ...)
  if not ok then
    line = tostring(fmt)
  end
  f:write(string.format("[%6.2fs] %s\n", (vim.loop.hrtime() - start) / 1e9, line))
  f:flush()
end

local function dump_state(tag)
  local session = dap.session()
  local frame = session and session.current_frame
  log(
    "%s session=%s stopped_thread=%s current_frame=%s",
    tag,
    session and (session.config and session.config.name or "?") or "nil",
    session and tostring(session.stopped_thread_id) or "nil",
    frame and string.format("%s:%s (%s)", tostring(frame.source and frame.source.path), tostring(frame.line), tostring(frame.name)) or "nil"
  )

  local cur_win = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    log(
      "  %s win=%d buf=%d ft=%-18s bt=%-8s w=%-3d h=%-3d lines=%-5d name=%s",
      win == cur_win and "*" or " ",
      win,
      buf,
      vim.bo[buf].filetype ~= "" and vim.bo[buf].filetype or "-",
      vim.bo[buf].buftype ~= "" and vim.bo[buf].buftype or "-",
      vim.api.nvim_win_get_width(win),
      vim.api.nvim_win_get_height(win),
      vim.api.nvim_buf_line_count(buf),
      vim.api.nvim_buf_get_name(buf)
    )
  end
  log("  cursor=%s switchbuf=%q", vim.inspect(vim.api.nvim_win_get_cursor(cur_win)), vim.o.switchbuf)

  local placed = vim.fn.sign_getplaced("", { group = "*" })
  for _, entry in ipairs(placed or {}) do
    for _, sign in ipairs(entry.signs or {}) do
      log("  sign buf=%s line=%s name=%s group=%s", entry.bufnr, sign.lnum, sign.name, sign.group)
    end
  end
end

dap.set_log_level("TRACE")
log("nvim-dap log: %s", vim.fn.stdpath("cache") .. "/dap.log")
log("adapters registered: %s", table.concat(vim.tbl_keys(dap.adapters), ", "))
log("jump_on_pause listener present: %s", tostring(dap.listeners.after.event_stopped["krs_jump_on_pause"] ~= nil))

-- What actually got launched
local orig_run = dap.run
dap.run = function(config, opts)
  log("dap.run config=%s", vim.inspect(config))
  dump_state("BEFORE-RUN")
  return orig_run(config, opts)
end

dap.listeners.after.event_initialized["dapdiag"] = function()
  log("event_initialized")
  vim.defer_fn(function()
    dump_state("AFTER-INIT")
  end, 300)
end

dap.listeners.after.event_stopped["dapdiag"] = function(_, body)
  log("event_stopped reason=%s threadId=%s allThreadsStopped=%s preserveFocusHint=%s desc=%s",
    tostring(body.reason), tostring(body.threadId), tostring(body.allThreadsStopped),
    tostring(body.preserveFocusHint), tostring(body.description))
  vim.defer_fn(function()
    dump_state("AT-STOP")
  end, 400)
end

dap.listeners.after.setBreakpoints["dapdiag"] = function(_, err, resp)
  if err then
    log("setBreakpoints ERROR %s", vim.inspect(err))
    return
  end
  for _, bp in ipairs((resp or {}).breakpoints or {}) do
    log("breakpoint verified=%s line=%s message=%s", tostring(bp.verified), tostring(bp.line), tostring(bp.message))
  end
end

dap.listeners.after.stackTrace["dapdiag"] = function(_, err, resp)
  if err then
    log("stackTrace ERROR %s", vim.inspect(err))
    return
  end
  local frames = (resp or {}).stackFrames or {}
  log("stackTrace frames=%d", #frames)
  for i, fr in ipairs(frames) do
    if i <= 3 then
      log("  frame%d %s line=%s path=%s ref=%s", i, tostring(fr.name), tostring(fr.line),
        tostring(fr.source and fr.source.path), tostring(fr.source and fr.source.sourceReference))
    end
  end
end

for _, event in ipairs({ "event_terminated", "event_exited", "event_continued" }) do
  dap.listeners.after[event]["dapdiag"] = function(_, body)
    log("%s %s", event, vim.inspect(body))
    vim.defer_fn(function()
      dump_state("AFTER-" .. event)
    end, 300)
  end
end

dap.listeners.after.event_output["dapdiag"] = function(_, body)
  if body.category == "stderr" or body.category == "stdout" then
    log("output[%s] %s", body.category, (body.output or ""):gsub("%s+$", ""))
  end
end

vim.api.nvim_create_user_command("DapDiagOpen", function()
  vim.cmd("tabnew " .. vim.fn.fnameescape(logfile))
end, {})

vim.notify("DAP diagnostic armed -> " .. logfile .. "\nStart a debug session, then :DapDiagOpen", vim.log.levels.INFO)
