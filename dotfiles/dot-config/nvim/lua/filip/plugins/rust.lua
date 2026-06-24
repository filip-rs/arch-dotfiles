return {
  "mrcjkb/rustaceanvim",
  version = "^6",
  ft = { "rust" },
  config = function()
    -- rustaceanvim manages rust-analyzer itself (do NOT also enable it via
    -- lspconfig/mason-lspconfig). It reads this global when it attaches.
    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    vim.g.rustaceanvim = {
      server = {
        capabilities = capabilities,
        default_settings = {
          ["rust-analyzer"] = {
            cargo = { allFeatures = true },
            checkOnSave = true,
            check = { command = "clippy" },
          },
        },
      },
    }
  end,
}
