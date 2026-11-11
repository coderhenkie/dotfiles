-- ==========================================
-- Neovim Configuration (Dynamic Color Engine)
-- ==========================================

-- Base settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.termguicolors = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.smartindent = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.clipboard = "unnamedplus"
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8
vim.opt.updatetime = 250

-- Load the dynamic theme generated in ~/.cache/theme/nvim.lua
local theme_file = vim.fn.expand("~/.cache/theme/nvim.lua")

local function load_dynamic_theme()
    if vim.fn.filereadable(theme_file) == 1 then
        pcall(dofile, theme_file)
    end
end

-- Load theme immediately on startup
load_dynamic_theme()

-- Live reload: watch ~/.cache/theme for changes so open Neovim windows
-- update their colors immediately when switching themes or wallpapers
local uv = vim.uv or vim.loop
if uv then
    local watcher = uv.new_fs_event()
    local cache_dir = vim.fn.expand("~/.cache/theme")
    if watcher and vim.fn.isdirectory(cache_dir) == 1 then
        watcher:start(cache_dir, {}, vim.schedule_wrap(function(err, filename)
            if not err and (not filename or filename == "nvim.lua") then
                load_dynamic_theme()
            end
        end))
    end
end
