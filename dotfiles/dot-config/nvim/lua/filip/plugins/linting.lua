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

    local group = vim.api.nvim_create_augroup("filip_lint", { clear = true })
    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
      group = group,
      callback = function()
        -- Only lint if a linter is configured for this filetype.
        if lint.linters_by_ft[vim.bo.filetype] then
          lint.try_lint()
        end
      end,
    })

    vim.keymap.set("n", "<leader>ll", function()
      lint.try_lint()
    end, { desc = "Trigger linting for current file" })
  end,
}
