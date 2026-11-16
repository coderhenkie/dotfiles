-- Enter in insert mode continues lists like Obsidian (used by after/ftplugin/markdown.lua):
--   - [ ] task  -> next line "- [ ] " (also after a checked task)
--   - item      -> "- "
--   1. item     -> "2. "
-- Enter on an empty item ends the list: an indented item moves one level out, otherwise the marker is
-- removed. Text after the cursor moves along to the new item. When the completion menu is open,
-- Enter accepts the completion as usual.
local M = {}

local function parse(line)
    local indent, marker, rest = line:match("^(%s*)([-*+]) (.*)$")
    local num, delim
    if not indent then
        indent, num, delim, rest = line:match("^(%s*)(%d+)([.)]) (.*)$")
        if not indent then return nil end
        marker = num .. delim
    end
    local box, after_box = rest:match("^%[(.)%] ?(.*)$")
    local prefix_len = #indent + #marker + 1
    if box then prefix_len = #line - #after_box end
    return {
        indent = indent,
        marker = marker,
        num = tonumber(num),
        delim = delim,
        task = box ~= nil,
        prefix_len = prefix_len,
    }
end

-- What Enter should do on this line: nil for a normal Enter, otherwise the new lines and cursor
local function plan()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    local item = parse(line)
    if not item or col < item.prefix_len then return nil end

    local before, after = line:sub(1, col), line:sub(col + 1)
    local content = before:sub(item.prefix_len + 1)

    -- Empty item: end the list (or move one level out)
    if content:match("^%s*$") and after:match("^%s*$") then
        local new = ""
        if #item.indent > 0 then
            local sw = vim.fn.shiftwidth()
            local indent = item.indent:sub(1, 1) == "\t" and item.indent:sub(2)
                or item.indent:sub(math.min(sw, #item.indent) + 1)
            new = indent .. vim.trim(line:sub(#item.indent + 1)) .. " "
        end
        return { row = row, lines = { new }, cursor = { row, #new } }
    end

    local marker = item.num and (item.num + 1) .. item.delim or item.marker
    local prefix = item.indent .. marker .. " " .. (item.task and "[ ] " or "")
    return {
        row = row,
        lines = { before, prefix .. (after:gsub("^%s+", "")) },
        cursor = { row + 1, #prefix },
    }
end

-- Runs from <Cmd> inside the key sequence, so it happens right away (also when blink.cmp passes
-- Enter on to this mapping) and may change the buffer
function M.apply()
    local p = plan()
    if not p then return end
    vim.api.nvim_buf_set_lines(0, p.row - 1, p.row, false, p.lines)
    vim.api.nvim_win_set_cursor(0, p.cursor)
end

-- Expr mapping: decides only, changes nothing itself
function M.enter()
    local ok, blink = pcall(require, "blink.cmp")
    if ok and blink.is_visible() then return "<Cmd>lua require('blink.cmp').accept()<CR>" end
    if plan() then return "<Cmd>lua require('markdown_list').apply()<CR>" end
    return "<CR>"
end

function M.attach(buf)
    vim.keymap.set("i", "<CR>", M.enter, { buffer = buf, expr = true, desc = "New line, continue list" })
end

return M
