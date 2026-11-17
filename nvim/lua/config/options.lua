-- Loaded before LazyVim's plugins; LazyVim's defaults (lua/lazyvim/config/options.lua) apply first.
local opt = vim.opt
opt.relativenumber = true
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.smartindent = true
opt.clipboard = "unnamedplus"
opt.scrolloff = 8
opt.updatetime = 250
-- Don't silently reload files changed outside Neovim (Neovim's default is on); Obsidian notes turn
-- it back on per buffer, since Sync changes them from other devices (lua/plugins/obsidian.lua)
opt.autoread = false

-- Markdown/Obsidian: hide link and formatting syntax (render-markdown + obsidian.nvim need >= 1)
opt.conceallevel = 2
