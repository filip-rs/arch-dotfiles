return {
  "mfussenegger/nvim-dap",
  dependencies = {
    { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
    "theHamsta/nvim-dap-virtual-text",
  },
  -- Load when a Rust buffer opens (so <leader>rd debuggables has dap ready)
  -- or when any debug key is pressed.
  ft = { "rust" },
  keys = {
    { "<leader>xb", function() require("dap").toggle_breakpoint() end, desc = "Debug: toggle breakpoint" },
    { "<leader>xB", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "Debug: conditional breakpoint" },
    { "<leader>xc", function() require("dap").continue() end, desc = "Debug: continue / start" },
    { "<leader>xo", function() require("dap").step_over() end, desc = "Debug: step over" },
    { "<leader>xi", function() require("dap").step_into() end, desc = "Debug: step into" },
    { "<leader>xO", function() require("dap").step_out() end, desc = "Debug: step out" },
    { "<leader>xt", function() require("dap").terminate() end, desc = "Debug: terminate" },
    { "<leader>xr", function() require("dap").repl.toggle() end, desc = "Debug: toggle REPL" },
    { "<leader>xu", function() require("dapui").toggle() end, desc = "Debug: toggle UI" },
    -- Classic function-key aliases for run control.
    { "<F5>", function() require("dap").continue() end, desc = "Debug: continue" },
    { "<F10>", function() require("dap").step_over() end, desc = "Debug: step over" },
    { "<F11>", function() require("dap").step_into() end, desc = "Debug: step into" },
    { "<F12>", function() require("dap").step_out() end, desc = "Debug: step out" },
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    dapui.setup()
    require("nvim-dap-virtual-text").setup({})

    -- Open/close the DAP UI automatically with the debug session.
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end

    vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError", linehl = "", numhl = "" })
    vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual", numhl = "" })
  end,
}
