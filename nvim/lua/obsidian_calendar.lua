-- Calendar for obsidian.nvim daily notes, modelled on the Obsidian app's Calendar plugin.
-- Opened with <leader>oc (lua/plugins/obsidian.lua). A month grid in a floating window:
--   * dots under a day that has a note: one per 250 words (1 to 5), plus a hollow dot when the
--     note still has open tasks (- [ ])
--   * today is highlighted, the daily note you came from is underlined, days of the
--     neighbouring months are dimmed; weeks start on Monday
--   * Enter / click opens that day's note, or asks to create it (from the daily template)
-- Paths, date format and template come from obsidian.nvim's daily_notes settings, so the
-- calendar always matches :Obsidian today.

local M = {}

-- Same settings as the app's Calendar plugin (.obsidian/plugins/calendar/data.json)
M.config = {
    words_per_dot = 250,
    max_dots = 5,
    week_start = 2, -- os.date wday: 1 = Sunday, 2 = Monday
    confirm_before_create = true,
}

local CELL = 7 -- width of one day column
local PAD = 1 -- left margin
local ns = vim.api.nvim_create_namespace("obsidian_calendar")
local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August",
    "September", "October", "November", "December" }
local WEEKDAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

local state = {} -- buf, win, prev_win, dir, sel, active, cells, buttons
local stats_cache = {} -- path -> { mtime, size, words, tasks }

-- Noon avoids DST jumps when adding days; os.time normalises day 0 / day 32 etc.
local function day(y, m, d) return os.time({ year = y, month = m, day = d, hour = 12 }) end
local function ymd(ts) return os.date("*t", ts) end
local function same_day(a, b)
    local x, y = ymd(a), ymd(b)
    return x.year == y.year and x.month == y.month and x.day == y.day
end
local function days_in_month(y, m) return ymd(day(y, m + 1, 0)).day end

local function set_highlights()
    local set = function(name, opts) vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", opts, { default = true })) end
    set("ObsidianCalendarTitle", { link = "Title" })
    set("ObsidianCalendarButton", { link = "Special" })
    set("ObsidianCalendarWeekday", { link = "Comment" })
    set("ObsidianCalendarOtherMonth", { link = "Comment" })
    set("ObsidianCalendarToday", { link = "Special" })
    set("ObsidianCalendarSelected", { link = "Visual" })
    set("ObsidianCalendarActive", { underline = true, bold = true })
    set("ObsidianCalendarDot", { link = "Special" })
    set("ObsidianCalendarHint", { link = "Comment" })
end

local function note_path(ts)
    local path = require("obsidian.daily").daily_note_path(ts, state.dir)
    return tostring(path)
end

-- Word count and open tasks of a note, cached on mtime + size
local function note_stats(path)
    local st = vim.uv.fs_stat(path)
    if not st then return nil end
    local key = st.mtime.sec .. "." .. st.mtime.nsec .. ":" .. st.size
    local c = stats_cache[path]
    if c and c.key == key then return c end

    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then return nil end
    local words, tasks, in_fm = 0, 0, false
    for i, line in ipairs(lines) do
        if i == 1 and line == "---" then
            in_fm = true
        elseif in_fm then
            if line == "---" then in_fm = false end
        else
            for _ in line:gmatch("%S+") do words = words + 1 end
            if line:match("^%s*[-*+] %[ %]") or line:match("^%s*%d+[.)] %[ %]") then tasks = tasks + 1 end
        end
    end
    c = { key = key, words = words, tasks = tasks }
    stats_cache[path] = c
    return c
end

local function dots_for(path)
    local s = note_stats(path)
    if not s then return "" end
    local n = math.max(1, math.min(M.config.max_dots, math.floor(s.words / M.config.words_per_dot)))
    return string.rep("•", n) .. (s.tasks > 0 and "◦" or "")
end

local function center(text, width)
    local w = vim.fn.strdisplaywidth(text)
    local left = math.floor((width - w) / 2)
    return string.rep(" ", left) .. text .. string.rep(" ", width - w - left), left
end

local function width() return PAD + 7 * CELL end

local function render()
    local buf = state.buf
    local sel = ymd(state.sel)
    local y, m = sel.year, sel.month
    local today = os.time()
    local lines, marks = {}, {}
    local function mark(line, s, e, hl, prio) table.insert(marks, { line, s, e, hl, prio or 100 }) end

    -- Header: "November 2026" on the left, "‹  Today  ›" on the right (clickable)
    local title = MONTHS[m] .. " " .. y
    local nav = "‹  Today  ›"
    local navw = vim.fn.strdisplaywidth(nav)
    local gap = width() - PAD - #title - navw
    lines[1] = string.rep(" ", PAD) .. title .. string.rep(" ", gap) .. nav
    mark(0, PAD, PAD + #title, "ObsidianCalendarTitle")
    local nav_byte = PAD + #title + gap
    mark(0, nav_byte, #lines[1], "ObsidianCalendarButton")
    local nav_col = PAD + #title + gap -- display column (0-based) where nav starts
    state.buttons = {
        { s = nav_col, e = nav_col + 1, action = "prev" },
        { s = nav_col + 3, e = nav_col + 8, action = "today" },
        { s = nav_col + 10, e = nav_col + 11, action = "next" },
    }
    lines[2] = ""

    local hdr = string.rep(" ", PAD)
    for i = 0, 6 do
        hdr = hdr .. center(WEEKDAYS[(M.config.week_start - 1 + i) % 7 + 1], CELL)
    end
    lines[3] = hdr
    mark(2, 0, #hdr, "ObsidianCalendarWeekday")

    -- Grid: whole weeks covering the month, neighbouring days included
    local first_wday = ymd(day(y, m, 1)).wday
    local offset = (first_wday - M.config.week_start) % 7
    local weeks = math.ceil((offset + days_in_month(y, m)) / 7)
    state.cells = {}
    for w = 0, weeks - 1 do
        local num_line, dot_line = string.rep(" ", PAD), string.rep(" ", PAD)
        local num_idx = #lines -- 0-based index of the number line
        local dot_marks = {}
        for d = 0, 6 do
            local ts = day(y, m, 1 - offset + w * 7 + d)
            local t = ymd(ts)
            local path = note_path(ts)
            local cell_start = #num_line
            local txt, left = center(tostring(t.day), CELL)
            num_line = num_line .. txt
            local ns_, ne = cell_start + left, cell_start + left + #tostring(t.day)

            if t.month ~= m then mark(num_idx, ns_, ne, "ObsidianCalendarOtherMonth", 110) end
            if same_day(ts, today) then mark(num_idx, ns_, ne, "ObsidianCalendarToday", 120) end
            if state.active == path then mark(num_idx, ns_, ne, "ObsidianCalendarActive", 130) end
            if same_day(ts, state.sel) then
                mark(num_idx, ns_ - 1, ne + 1, "ObsidianCalendarSelected", 90)
                state.cursor = { num_idx + 1, ns_ }
            end

            local dots = dots_for(path)
            local dtxt = center(dots, CELL)
            local dstart = #dot_line
            dot_line = dot_line .. dtxt
            if dots ~= "" then table.insert(dot_marks, { dstart, dstart + #dtxt }) end

            table.insert(state.cells, { line = num_idx, s = cell_start, e = cell_start + CELL, ts = ts })
            table.insert(state.cells, { line = num_idx + 1, s = cell_start, e = cell_start + CELL, ts = ts })
        end
        lines[#lines + 1] = num_line
        lines[#lines + 1] = dot_line
        for _, dm in ipairs(dot_marks) do mark(num_idx + 1, dm[1], dm[2], "ObsidianCalendarDot") end
    end

    lines[#lines + 1] = ""
    local hint = " ⏎ open  hjkl day  [ ] month  t today  s split  q close"
    lines[#lines + 1] = hint
    mark(#lines - 1, 0, #hint, "ObsidianCalendarHint")

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, mk in ipairs(marks) do
        vim.api.nvim_buf_set_extmark(buf, ns, mk[1], math.max(0, mk[2]), {
            end_col = math.min(mk[3], #lines[mk[1] + 1]),
            hl_group = mk[4],
            priority = mk[5],
        })
    end

    if state.win and vim.api.nvim_win_is_valid(state.win) then
        local cfg = vim.api.nvim_win_get_config(state.win)
        if cfg.height ~= #lines then
            vim.api.nvim_win_set_config(state.win, vim.tbl_extend("force", cfg, { height = #lines,
                row = math.floor((vim.o.lines - #lines) / 2) - 1 }))
        end
        if state.cursor then pcall(vim.api.nvim_win_set_cursor, state.win, state.cursor) end
    end
end

local function close()
    if state.win and vim.api.nvim_win_is_valid(state.win) then vim.api.nvim_win_close(state.win, true) end
    state.win = nil
end

local function move_days(n)
    state.sel = state.sel + n * 86400
    state.sel = day(ymd(state.sel).year, ymd(state.sel).month, ymd(state.sel).day) -- back to noon
    render()
end

local function move_months(n)
    local t = ymd(state.sel)
    local target = ymd(day(t.year, t.month + n, 1))
    state.sel = day(target.year, target.month, math.min(t.day, days_in_month(target.year, target.month)))
    render()
end

local function go_today()
    local t = ymd(os.time())
    state.sel = day(t.year, t.month, t.day)
    render()
end

-- Open (or create) the daily note for `ts`; `split` opens it in a vertical split
local function open_day(ts, split)
    local note = require("obsidian.daily").daily({ date = ts, dir = state.dir })
    local exists = note:exists()
    if not exists and M.config.confirm_before_create then
        local choice = vim.fn.confirm(
            ("Daily note %s doesn't exist yet. Create it?"):format(note.id), "&Create\n&Cancel", 1)
        if choice ~= 1 then return end
    end
    close()
    if state.prev_win and vim.api.nvim_win_is_valid(state.prev_win) then
        vim.api.nvim_set_current_win(state.prev_win)
    end
    if not exists then note:write() end
    note:open({ sync = true, open_strategy = split and "vsplit_force" or "current" })
end

local function on_click()
    local pos = vim.fn.getmousepos()
    if pos.winid ~= state.win then
        -- Click outside the calendar: close it and let the click through
        close()
        vim.api.nvim_feedkeys(vim.keycode("<LeftMouse>"), "n", false)
        return
    end
    local line, col = pos.line - 1, pos.column - 1
    if line == 0 then
        for _, b in ipairs(state.buttons) do
            if col >= b.s and col < b.e then
                if b.action == "prev" then move_months(-1)
                elseif b.action == "next" then move_months(1)
                else go_today() end
                return
            end
        end
        return
    end
    for _, c in ipairs(state.cells) do
        if c.line == line and col >= c.s and col < c.e then
            state.sel = c.ts
            render()
            open_day(c.ts, false)
            return
        end
    end
end

function M.open()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        close()
        return
    end
    if not package.loaded["obsidian"] then pcall(function() require("lazy").load({ plugins = { "obsidian.nvim" } }) end) end
    if not rawget(_G, "Obsidian") then
        vim.notify("obsidian.nvim isn't loaded (no vault found)", vim.log.levels.WARN)
        return
    end
    set_highlights()

    state.prev_win = vim.api.nvim_get_current_win()
    state.dir = require("obsidian.api").resolve_workspace_dir()
    state.active = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")

    -- Start on the daily note you're in, otherwise on today
    local t = ymd(os.time())
    state.sel = day(t.year, t.month, t.day)
    local fmt = Obsidian.opts.daily_notes.date_format
    local stem = vim.fn.fnamemodify(state.active, ":t:r")
    local ok, parsed = pcall(require("obsidian.date").parse, stem, fmt)
    if ok and type(parsed) == "table" and parsed.year then
        local ts = day(parsed.year, parsed.month, parsed.day)
        if note_path(ts) == state.active then state.sel = ts end
    end

    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].bufhidden = "wipe"
    vim.bo[state.buf].filetype = "obsidian_calendar"
    render()
    local height = vim.api.nvim_buf_line_count(state.buf)
    state.win = vim.api.nvim_open_win(state.buf, true, {
        relative = "editor",
        width = width() + 1,
        height = height,
        row = math.floor((vim.o.lines - height) / 2) - 1,
        col = math.floor((vim.o.columns - width()) / 2),
        style = "minimal",
        border = "rounded",
        title = " Calendar ",
        title_pos = "center",
    })
    vim.wo[state.win].cursorline = false
    vim.wo[state.win].wrap = false
    render() -- places the cursor now that the window exists

    local map = function(lhs, fn, desc)
        vim.keymap.set("n", lhs, fn, { buffer = state.buf, nowait = true, silent = true, desc = desc })
    end
    map("h", function() move_days(-1) end, "Previous day")
    map("l", function() move_days(1) end, "Next day")
    map("k", function() move_days(-7) end, "Previous week")
    map("j", function() move_days(7) end, "Next week")
    map("<Left>", function() move_days(-1) end, "Previous day")
    map("<Right>", function() move_days(1) end, "Next day")
    map("<Up>", function() move_days(-7) end, "Previous week")
    map("<Down>", function() move_days(7) end, "Next week")
    for _, k in ipairs({ "[", "H", "<", "<PageUp>", "<ScrollWheelUp>" }) do map(k, function() move_months(-1) end, "Previous month") end
    for _, k in ipairs({ "]", "L", ">", "<PageDown>", "<ScrollWheelDown>" }) do map(k, function() move_months(1) end, "Next month") end
    map("{", function() move_months(-12) end, "Previous year")
    map("}", function() move_months(12) end, "Next year")
    map("t", go_today, "Today")
    map("<CR>", function() open_day(state.sel, false) end, "Open day")
    map("o", function() open_day(state.sel, false) end, "Open day")
    map("s", function() open_day(state.sel, true) end, "Open day in split")
    map("<C-CR>", function() open_day(state.sel, true) end, "Open day in split")
    map("<LeftMouse>", on_click, "Open clicked day")
    map("q", close, "Close")
    map("<Esc>", close, "Close")

    vim.api.nvim_create_autocmd("WinLeave", {
        buffer = state.buf,
        once = true,
        callback = function() vim.schedule(close) end,
    })
end

return M
