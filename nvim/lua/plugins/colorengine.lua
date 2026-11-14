-- Colors come from the dotfiles theme engine (scripts/apply-theme.sh -> ~/.cache/theme/nvim.lua),
-- loaded through colors/colorengine.lua. mini.base16 turns the palette into highlights for every
-- plugin LazyVim uses (pickers, completion, which-key, statusline, diagnostics, treesitter...).
return {
    { "nvim-mini/mini.base16", lazy = false, priority = 1000 },
    { "LazyVim/LazyVim", opts = { colorscheme = "colorengine" } },
    -- LazyVim's bundled themes aren't used
    { "folke/tokyonight.nvim", enabled = false },
    { "catppuccin/nvim", name = "catppuccin", enabled = false },
}
