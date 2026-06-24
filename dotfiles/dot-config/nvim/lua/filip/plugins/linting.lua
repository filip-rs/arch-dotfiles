return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local lint = require("lint")

    -- LSP servers already cover most diagnostics (ruff for Python, bashls +
    -- shellcheck for Bash, etc.); nvim-lint fills the ESLint gap for web files.
    -- eslint_d is a no-op in projects without an eslint config.
    lint.linters_by_ft = {
      javascript = { "eslint_d" },
      typescript = { "eslint_d" },
      javascriptreact = { "eslint_d" },
      typescriptreact = { "eslint_d" },
      svelte = { "eslint_d" },
    }

    -- Resolve a linter's executable name (cmd may be a string or a function).
    local function linter_executable(name)
      local linter = lint.linters[name]
      local cmd = type(linter) == "table" and linter.cmd or name
      if type(cmd) == "function" then
        local ok, resolved = pcall(cmd)
        cmd = ok and resolved or name
      end
      return cmd
    end

    -- Only run linters whose binary is actually installed. This keeps the config
    -- portable across machines (desktop, WSL, fresh installs): a missing linter
    -- is silently skipped instead of raising an ENOENT on every save.
    local function lint_if_available()
      local names = lint.linters_by_ft[vim.bo.filetype]
      if not names then
        return
      end
      local available = vim.tbl_filter(function(name)
        return vim.fn.executable(linter_executable(name)) == 1
      end, names)
      if #available > 0 then
        lint.try_lint(available)
      end
    end

    local group = vim.api.nvim_create_augroup("filip_lint", { clear = true })
    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
      group = group,
      callback = lint_if_available,
    })

    vim.keymap.set("n", "<leader>ll", lint_if_available, { desc = "Trigger linting for current file" })
  end,
}
