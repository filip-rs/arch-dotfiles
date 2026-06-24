return {
  "neovim/nvim-lspconfig",
  event = "BufReadPre",
  dependencies = {
    "mason-org/mason.nvim",
    "mason-org/mason-lspconfig.nvim",
    "hrsh7th/cmp-nvim-lsp",
    {
      "ray-x/lsp_signature.nvim",
      opts = {
        bind = true,
        handler_opts = { border = "rounded" },
        hint_enable = true,
        hint_prefix = "> ",
      },
    },
  },
  config = function()
    local cmp_nvim_lsp = require("cmp_nvim_lsp")
    local capabilities = cmp_nvim_lsp.default_capabilities()

    -- LSP keymaps on attach
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("UserLspConfig", {}),
      callback = function(ev)
        local opts = { buffer = ev.buf, silent = true }

        vim.keymap.set("n", "gR", "<cmd>Telescope lsp_references<CR>", vim.tbl_extend("force", opts, { desc = "Show LSP references" }))
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", opts, { desc = "Go to declaration" }))
        vim.keymap.set("n", "gd", "<cmd>Telescope lsp_definitions<CR>", vim.tbl_extend("force", opts, { desc = "Show LSP definitions" }))
        vim.keymap.set("n", "gi", "<cmd>Telescope lsp_implementations<CR>", vim.tbl_extend("force", opts, { desc = "Show LSP implementations" }))
        vim.keymap.set("n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", vim.tbl_extend("force", opts, { desc = "Show LSP type definitions" }))
        vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "See available code actions" }))
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Smart rename" }))
        vim.keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", vim.tbl_extend("force", opts, { desc = "Show buffer diagnostics" }))
        vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, vim.tbl_extend("force", opts, { desc = "Show line diagnostics" }))
        vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, vim.tbl_extend("force", opts, { desc = "Go to previous diagnostic" }))
        vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, vim.tbl_extend("force", opts, { desc = "Go to next diagnostic" }))
        vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Show documentation" }))
        vim.keymap.set("n", "<leader>rs", ":LspRestart<CR>", vim.tbl_extend("force", opts, { desc = "Restart LSP" }))
      end,
    })

    -- Diagnostic float on cursor hold
    vim.api.nvim_create_autocmd("CursorHold", {
      callback = function()
        vim.diagnostic.open_float(nil, { focus = false, scope = "cursor" })
      end,
    })

    -- Configure servers using new vim.lsp.config API (Neovim 0.11+).
    -- These merge on top of the defaults shipped by nvim-lspconfig.
    vim.lsp.config.pyright = { capabilities = capabilities }
    vim.lsp.config.ts_ls = { capabilities = capabilities }
    vim.lsp.config.html = { capabilities = capabilities }
    vim.lsp.config.cssls = { capabilities = capabilities }
    vim.lsp.config.jsonls = { capabilities = capabilities }
    vim.lsp.config.bashls = { capabilities = capabilities }
    vim.lsp.config.tailwindcss = { capabilities = capabilities }

    -- Ruff handles Python linting / import sorting; let pyright own hover.
    vim.lsp.config.ruff = {
      capabilities = capabilities,
      on_attach = function(client)
        client.server_capabilities.hoverProvider = false
      end,
    }

    vim.lsp.config.gopls = {
      capabilities = capabilities,
      cmd = { "gopls" },
      filetypes = { "go", "gomod", "gowork", "gotmpl" },
      root_markers = { "go.work", "go.mod", ".git" },
    }

    vim.lsp.config.lua_ls = {
      capabilities = capabilities,
      settings = {
        Lua = {
          diagnostics = { globals = { "vim" } },
          workspace = { checkThirdParty = false },
        },
      },
    }

    -- Enable all configured servers.
    -- (rust-analyzer is intentionally absent here — rustaceanvim manages it.)
    vim.lsp.enable({
      "pyright",
      "ruff",
      "gopls",
      "ts_ls",
      "html",
      "cssls",
      "jsonls",
      "bashls",
      "tailwindcss",
      "lua_ls",
    })
  end,
}
