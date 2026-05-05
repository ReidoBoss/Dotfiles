vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "autocmds"

vim.schedule(function()
  require "mappings"
end)

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.rs", "*.toml", "*.lua" },
  callback = function()
    -- 1. Format the file
    vim.lsp.buf.format({ async = false })

    -- 2. Ensure exactly one blank line at the end
    -- This removes trailing whitespace/newlines and adds one clean empty line
    vim.cmd([[silent! %s/\n\+\%$//e]])
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "" })
  end,
})
