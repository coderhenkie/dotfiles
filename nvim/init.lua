-- ==========================================
-- Neovim Configuratie (Dynamische Color Engine)
-- ==========================================

-- Basis instellingen
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

-- Functie om het dynamische thema uit ~/.cache/theme/nvim.lua in te laden
local theme_file = vim.fn.expand("~/.cache/theme/nvim.lua")

local function load_dynamic_theme()
    if vim.fn.filereadable(theme_file) == 1 then
        pcall(dofile, theme_file)
    end
end

-- Laad thema direct bij opstarten
load_dynamic_theme()

-- Live reload: luister naar wijzigingen in ~/.cache/theme zodat openstaande
-- Neovim-vensters direct meekleuren zodra je een ander thema of wallpaper kiest
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
