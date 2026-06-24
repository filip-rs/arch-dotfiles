-- Headless smoke test for the Neovim config.
-- Run with:  nvim --headless -c "luafile scripts/ci-check.lua"
--
-- Catches *config* breakage (Lua errors in plugin setup, treesitter parser /
-- query mismatches, telescope <-> treesitter API regressions) without starting
-- language servers — whether a server binary is installed is an environment
-- concern, not a config bug, and spawning real servers (rust-analyzer's
-- `cargo check`, ...) makes headless runs slow and prone to hanging on exit.
--
-- Strategy: force-load the heavy plugins so their `config` runs (Lua validated),
-- then validate treesitter + the telescope previewer on scratch buffers using an
-- explicit language, so no FileType event fires and no LSP attaches.

local errors = {}

-- Keep headless runs from blocking on a "press ENTER" prompt.
vim.o.more = false
vim.opt.shortmess:append("aF")

local NOISE = {
  "language server", "not installed", "executable", "mason",
  "rust%-analyzer", "rustaceanvim", "rustlsp", "cargo", "workspace",
  "linkedprojects", "no project root", "get_buffers_by_client_id",
}
local ERROR_SIGNATURES = {
  "attempt to call", "attempt to index", "attempt to perform", "nil value",
  "stack traceback", "query error", "error executing", "e5108", "e5113",
}

local function is_noise(line)
  local l = line:lower()
  for _, p in ipairs(NOISE) do
    if l:find(p) then return true end
  end
  return false
end

local function is_error(line)
  if is_noise(line) then return false end
  local l = line:lower()
  for _, sig in ipairs(ERROR_SIGNATURES) do
    if l:find(sig, 1, true) then return true end
  end
  if line:find("E%d%d%d") then return true end
  return false
end

-- Capture non-noise ERROR notifications.
local orig_notify = vim.notify
vim.notify = function(msg, level, opts)
  if level == vim.log.levels.ERROR and not is_noise(tostring(msg)) then
    table.insert(errors, "notify: " .. tostring(msg):gsub("%s+", " "))
  end
  return orig_notify(msg, level, opts)
end

-- 1) Force-load the plugins whose `config` we want to validate. Any Lua error in
--    their setup surfaces here.
local plugins = {
  "mason.nvim", "mason-lspconfig.nvim", "nvim-lspconfig", "nvim-treesitter",
  "nvim-treesitter-textobjects", "telescope.nvim", "conform.nvim", "nvim-lint",
  "rustaceanvim", "gitsigns.nvim", "nvim-cmp", "nvim-ts-autotag",
  "nvim-autopairs", "Comment.nvim",
}
for _, p in ipairs(plugins) do
  local ok, err = pcall(function() require("lazy").load({ plugins = { p } }) end)
  if not ok then
    table.insert(errors, "load " .. p .. ": " .. tostring(err))
  end
end

-- 2) Treesitter: load each parser + run its highlight queries on a scratch
--    buffer (explicit lang => no FileType => no LSP). Catches missing parsers
--    and stale-parser query errors.
local samples = {
  lua = "local a = 1",
  python = "def f():\n    return 1",
  rust = "fn main() {}",
  typescript = "const a: number = 1",
  tsx = "const C = () => null",
  html = "<div></div>",
  css = ".a { color: red }",
  bash = "echo hi",
  json = '{"a": 1}',
  go = "package main",
  yaml = "a: 1",
  toml = "a = 1",
  markdown = "# hi",
}
for lang, code in pairs(samples) do
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(code, "\n"))
  local ok, err = pcall(vim.treesitter.start, buf, lang)
  if not ok then
    table.insert(errors, "treesitter " .. lang .. ": " .. tostring(err))
  end
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

-- 3) Telescope previewer highlighter — the path that broke when nvim-treesitter
--    `main` removed parsers.ft_to_lang.
local ok_req, putils = pcall(require, "telescope.previewers.utils")
if ok_req then
  for _, ft in ipairs({ "lua", "python", "rust", "typescript", "json", "html" }) do
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x" })
    local ok, err = pcall(putils.highlighter, buf, ft)
    if not ok then
      table.insert(errors, "telescope highlighter " .. ft .. ": " .. tostring(err))
    end
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
else
  table.insert(errors, "require telescope.previewers.utils: " .. tostring(putils))
end

-- Let any scheduled callbacks run, then scan the message log.
vim.wait(500)
local msgs = vim.api.nvim_exec2("messages", { output = true }).output or ""
for line in msgs:gmatch("[^\n]+") do
  if is_error(line) then
    table.insert(errors, "message: " .. line)
  end
end

if #errors > 0 then
  io.stderr:write("\n\27[31m❌ Neovim config check FAILED (" .. #errors .. " issue(s)):\27[0m\n")
  for _, e in ipairs(errors) do
    io.stderr:write("  - " .. e .. "\n")
  end
  vim.cmd("cquit 1")
else
  io.stderr:write("\n\27[32m✅ Neovim config loaded cleanly (plugins + treesitter + telescope)\27[0m\n")
  vim.cmd("qa!")
end
