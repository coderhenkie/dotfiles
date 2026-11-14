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

-- Markdown/Obsidian: hide link and formatting syntax (render-markdown + obsidian.nvim need >= 1)
opt.conceallevel = 2
