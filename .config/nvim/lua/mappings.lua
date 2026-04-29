require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
--

-- Rust / rustaceanvim actions
map("n", "<leader>rr", function()
  vim.cmd.RustLsp("runnables")
end, { desc = "Rust runnables" })

map("n", "<leader>re", function()
  vim.cmd.RustLsp("expandMacro")
end, { desc = "Expand macro" })

map("n", "<leader>rc", function()
  vim.cmd.RustLsp("openCargo")
end, { desc = "Open Cargo.toml" })

map("n", "<leader>rd", function()
  vim.cmd.RustLsp("debuggables")
end, { desc = "Rust debuggables" })

map("n", "K", function()
  vim.cmd.RustLsp({ "hover", "actions" })
end, { desc = "Hover actions" })

-- Crates.nvim (in Cargo.toml)
map("n", "<leader>cu", function()
  require("crates").upgrade_crate()
end, { desc = "Upgrade crate" })

map("n", "<leader>ca", function()
  require("crates").upgrade_all_crates()
end, { desc = "Upgrade all crates" })

-- Neotest
map("n", "<leader>tt", function()
  require("neotest").run.run()
end, { desc = "Run nearest test" })

map("n", "<leader>tf", function()
  require("neotest").run.run(vim.fn.expand("%"))
end, { desc = "Run file tests" })

-- Trouble diagnostics
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",
  { desc = "Toggle diagnostics" })
