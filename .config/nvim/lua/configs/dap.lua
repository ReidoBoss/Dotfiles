local dap = require("dap")
local dapui = require("dapui")

-- codelldb adapter (install via mason: :MasonInstall codelldb)
dap.adapters.codelldb = {
  type = "server",
  port = "${port}",
  executable = {
    command = vim.fn.stdpath("data")
      .. "/mason/bin/codelldb",
    args = { "--port", "${port}" },
  },
}

dap.configurations.rust = {
  {
    name    = "Launch binary",
    type    = "codelldb",
    request = "launch",
    program = function()
      return vim.fn.input(
        "Path to binary: ",
        vim.fn.getcwd() .. "/target/debug/",
        "file"
      )
    end,
    cwd         = "${workspaceFolder}",
    stopOnEntry = false,
  },
}

-- Open/close dapui automatically
dap.listeners.after.event_initialized["dapui"] = function()
  dapui.open()
end
dap.listeners.before.event_terminated["dapui"] = function()
  dapui.close()
end

dapui.setup()

-- DAP keymaps
local map = vim.keymap.set
map("n", "<F5>",  dap.continue,          { desc = "Debug: continue"    })
map("n", "<F10>", dap.step_over,         { desc = "Debug: step over"   })
map("n", "<F11>", dap.step_into,         { desc = "Debug: step into"   })
map("n", "<F12>", dap.step_out,          { desc = "Debug: step out"    })
map("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
map("n", "<leader>du", dapui.toggle,          { desc = "Toggle DAP UI"     })
