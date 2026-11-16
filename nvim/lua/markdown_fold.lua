-- Heading folds for markdown, like collapsing a heading in Obsidian: a heading folds everything up to
-- the next heading of the same or a higher level (blank lines included), and nothing else folds.
-- Replaces the treesitter/LSP folds, which also fold lists, leave trailing lines visible and, on an
-- empty heading, fold the parent section instead. Used by after/ftplugin/markdown.lua.
local M = {}

local cache = {} -- buf -> { tick, levels = { [lnum] = foldexpr value }, ends = { [heading lnum] = last line } }

local function heading_level(line)
    local hashes = line:match("^(#+)%s") or line:match("^(#+)$")
    return hashes and #hashes <= 6 and #hashes or nil
end

local function compute(buf)
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    local c = cache[buf]
    if c and c.tick == tick then return c end

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local levels, ends = {}, {}
    local stack = {} -- open headings: { level, lnum }
    local fence, frontmatter = nil, lines[1] == "---"

    local function close_until(lvl, before)
        while #stack > 0 and stack[#stack][1] >= lvl do
            ends[stack[#stack][2]] = before
            table.remove(stack)
        end
    end

    for i, line in ipairs(lines) do
        local lvl
        if frontmatter then
            if i > 1 and (line == "---" or line == "...") then frontmatter = false end
        elseif fence then
            if line:match("^%s*" .. fence) then fence = nil end
        else
            local f = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
            if f then fence = f else lvl = heading_level(line) end
        end

        if lvl then
            close_until(lvl, i - 1)
            table.insert(stack, { lvl, i })
            levels[i] = ">" .. #stack
        else
            levels[i] = tostring(#stack)
        end
    end
    close_until(0, #lines)

    c = { tick = tick, levels = levels, ends = ends }
    cache[buf] = c
    return c
end

vim.api.nvim_create_autocmd("BufWipeout", {
    group = vim.api.nvim_create_augroup("markdown_fold_cache", { clear = true }),
    callback = function(ev) cache[ev.buf] = nil end,
})

function M.expr()
    return compute(vim.api.nvim_get_current_buf()).levels[vim.v.lnum] or "0"
end

-- Is the cursor on a heading that has something to fold?
function M.foldable_heading()
    local lnum = vim.fn.line(".")
    local c = compute(vim.api.nvim_get_current_buf())
    local e = c.ends[lnum]
    return e ~= nil and e > lnum
end

function M.is_heading()
    return compute(vim.api.nvim_get_current_buf()).ends[vim.fn.line(".")] ~= nil
end

-- Keys for a heading line: fold/unfold its section; an empty heading does nothing (instead of
-- folding the section it sits in)
function M.toggle_keys()
    return M.foldable_heading() and "za" or ""
end

return M
