return {
  "mason-org/mason.nvim",
  event = "BufReadPre",
  dependencies = {
    "mason-org/mason-lspconfig.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  },
  config = function()
    local mason = require("mason")
    local mason_lspconfig = require("mason-lspconfig")
    local mason_tool_installer = require("mason-tool-installer")

    mason.setup({
      ui = {
        icons = {
          package_installed = "O",
          package_pending = ">",
          package_uninstalled = "X",
        },
      },
    })

    mason_lspconfig.setup({
      ensure_installed = {
        "lua_ls",
        "pyright",
        "ruff",
        "gopls",
        "ts_ls",
        "html",
        "cssls",
        "jsonls",
        "bashls",
        "tailwindcss",
      },
      -- Servers are configured + enabled manually in lspconfig.lua, so don't
      -- let mason-lspconfig auto-enable them (avoids double vim.lsp.enable).
      automatic_enable = false,
    })

    mason_tool_installer.setup({
      ensure_installed = {
        "stylua",        -- lua formatter
        "prettier",      -- web formatter (used by conform)
        "black",         -- python formatter
        "isort",         -- python import sorter
        "eslint_d",      -- js/ts linter (used by nvim-lint)
        "shellcheck",    -- bash linter (used by bashls)
        "rust-analyzer", -- rust LSP (used by rustaceanvim)
      },
    })
  end,
}
