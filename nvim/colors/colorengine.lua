-- :colorscheme colorengine -> the palette apply-theme.sh writes to ~/.cache/theme/nvim.lua
local theme_file = vim.fn.expand("~/.cache/theme/nvim.lua")
if vim.fn.filereadable(theme_file) == 1 then
    local ok, err = pcall(dofile, theme_file)
    if not ok then vim.notify("colorengine: " .. err, vim.log.levels.WARN) end
else
    vim.cmd.colorscheme("habamax")
end
