local M = {}

M.ns_id = vim.api.nvim_create_namespace("slides_view_padding")
M.footer_ns = vim.api.nvim_create_namespace("slides_view_footer")
pcall(vim.api.nvim_set_hl, 0, "SlidesFooter", { default = true, link = "Comment" })

--- Configure default buffer options for the slide buffer
--- @param buf integer
--- @param filetype string
function M.default_configure_buffer(buf, filetype)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  if filetype and filetype ~= "" then
    vim.bo[buf].filetype = filetype
    vim.bo[buf].syntax = filetype
    pcall(vim.treesitter.start, buf, filetype)
  end
end

--- Configure presentation window options
--- @param win integer
--- @param config table
function M.configure_window(win, config)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].cursorline = false
  vim.wo[win].wrap = config.options.wrap ~= false

  if config.options.show_statusline then
    vim.wo[win].statusline = "%!v:lua.require('slides')._statusline()"
  end
end

--- Register keymaps on the slide buffer
--- @param buf integer
--- @param keymaps table
function M.setup_keymaps(buf, keymaps)
  if not vim.api.nvim_buf_is_valid(buf) or not keymaps then
    return
  end

  for lhs, action in pairs(keymaps) do
    if action ~= nil then
      vim.keymap.set("n", lhs, action, {
        buffer = buf,
        nowait = true,
        silent = true,
      })
    end
  end
end

--- Format slide lines for vertical centering and scrolling while keeping the entire slide intact
--- (preserving markdown code blocks, language injections, and treesitter syntax states)
--- @param raw_lines table List of slide lines
--- @param win integer Window handle
--- @param config table Plugin configuration
--- @param scroll_offset integer|nil Current scroll offset (0-indexed)
--- @param last_scroll_dir string|nil "up" or "down"
--- @return table final_lines, integer top_pad, table trimmed_lines, string scroll_status, integer scroll_offset, integer max_scroll_offset, boolean is_scrollable
function M.format_slide_lines(raw_lines, win, config, scroll_offset, last_scroll_dir)
  raw_lines = raw_lines or { "" }
  local options = (config and config.options) or {}
  local vert_align = options.vertical_align or "center"
  local show_footer = options.show_footer ~= false

  -- Trim leading and trailing empty lines for accurate vertical centering calculation
  local trimmed_lines = vim.deepcopy(raw_lines)
  while #trimmed_lines > 1 and trimmed_lines[1]:match("^%s*$") do
    table.remove(trimmed_lines, 1)
  end
  while #trimmed_lines > 1 and trimmed_lines[#trimmed_lines]:match("^%s*$") do
    table.remove(trimmed_lines, #trimmed_lines)
  end

  local win_height = (win and vim.api.nvim_win_is_valid(win)) and vim.api.nvim_win_get_height(win) or 24
  local reserved = show_footer and 1 or 0

  -- Determine margin / padding so big texts don't fill up the entire screen (preserving UI layout)
  local min_margin = 0
  if vert_align == "center" then
    min_margin = math.max(1, math.floor(win_height * 0.08))
  end

  local viewport_h = math.max(1, win_height - reserved - 2 * min_margin)
  if vert_align == "top" then
    viewport_h = math.max(1, win_height - reserved)
  end

  local total_lines = #trimmed_lines
  local is_scrollable = total_lines > viewport_h
  local top_pad = 0
  local max_scroll_offset = 0
  local actual_scroll_offset = 0
  local scroll_status = ""

  if not is_scrollable then
    if vert_align == "center" then
      top_pad = math.max(0, math.floor((win_height - reserved - total_lines) / 2))
    end
    actual_scroll_offset = 0
    max_scroll_offset = 0
    scroll_status = ""
  else
    max_scroll_offset = total_lines - viewport_h
    actual_scroll_offset = math.max(0, math.min(scroll_offset or 0, max_scroll_offset))

    if vert_align == "center" then
      top_pad = min_margin
    else
      top_pad = 0
    end

    if actual_scroll_offset == 0 then
      scroll_status = "Scroll down"
    elseif actual_scroll_offset >= max_scroll_offset then
      scroll_status = "End"
    else
      if last_scroll_dir == "up" then
        scroll_status = "Scroll up"
      else
        scroll_status = "Scroll down"
      end
    end
  end

  local final_lines = {}
  for _ = 1, top_pad do
    table.insert(final_lines, "")
  end
  for _, line in ipairs(trimmed_lines) do
    table.insert(final_lines, line)
  end

  -- Pad bottom empty lines
  if not is_scrollable then
    if show_footer and win_height > #final_lines then
      while #final_lines < win_height do
        table.insert(final_lines, "")
      end
    end
  else
    -- For scrollable slides, append padding lines at the end to allow smooth scrolling
    for _ = 1, win_height do
      table.insert(final_lines, "")
    end
  end

  if #final_lines == 0 then
    final_lines = { "" }
  end

  return final_lines, top_pad, trimmed_lines, scroll_status, actual_scroll_offset, max_scroll_offset, is_scrollable
end

--- Apply footer indicator (e.g. "1/12  Scroll down") at the bottom of the slide view
--- @param buf integer Buffer handle
--- @param win integer Window handle
--- @param state table Presentation state
--- @param config table Plugin configuration
function M.apply_footer_indicator(buf, win, state, config)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, M.footer_ns, 0, -1)
  end

  local options = (config and config.options) or {}
  if options.show_footer == false then
    if state and state.footer_win and vim.api.nvim_win_is_valid(state.footer_win) then
      pcall(vim.api.nvim_win_close, state.footer_win, true)
      state.footer_win = nil
    end
    return
  end

  local base_text = string.format("%d/%d", (state and state.current_slide) or 1, (state and state.slides and #state.slides) or 1)
  local scroll_status = (state and state.scroll_status) or ""
  local status_text = base_text
  if scroll_status ~= "" then
    status_text = string.format("%s  %s", base_text, scroll_status)
  end

  local footer_align = options.footer_align or "left"
  local win_width = (win and vim.api.nvim_win_is_valid(win)) and vim.api.nvim_win_get_width(win) or 80
  local win_height = (win and vim.api.nvim_win_is_valid(win)) and vim.api.nvim_win_get_height(win) or 24

  local formatted_line = ""
  if footer_align == "right" then
    local pad = math.max(0, win_width - vim.fn.strdisplaywidth(status_text) - 1)
    formatted_line = string.rep(" ", pad) .. status_text .. " "
  elseif footer_align == "center" then
    local pad = math.max(0, math.floor((win_width - vim.fn.strdisplaywidth(status_text)) / 2))
    formatted_line = string.rep(" ", pad) .. status_text
  else
    formatted_line = " " .. status_text
  end

  -- Render floating footer window docked at bottom of slide window
  if state and win and vim.api.nvim_win_is_valid(win) then
    local footer_buf = state.footer_buf
    if not footer_buf or not vim.api.nvim_buf_is_valid(footer_buf) then
      footer_buf = vim.api.nvim_create_buf(false, true)
      vim.bo[footer_buf].buftype = "nofile"
      vim.bo[footer_buf].bufhidden = "wipe"
      vim.bo[footer_buf].swapfile = false
      state.footer_buf = footer_buf
    end

    vim.bo[footer_buf].modifiable = true
    vim.api.nvim_buf_set_lines(footer_buf, 0, -1, false, { formatted_line })
    vim.bo[footer_buf].modifiable = false

    local footer_win = state.footer_win
    if not footer_win or not vim.api.nvim_win_is_valid(footer_win) then
      local ok, created_win = pcall(vim.api.nvim_open_win, footer_buf, false, {
        relative = "win",
        win = win,
        row = win_height - 1,
        col = 0,
        width = win_width,
        height = 1,
        style = "minimal",
        focusable = false,
        zindex = 50,
      })
      if ok then
        state.footer_win = created_win
        pcall(function()
          vim.wo[created_win].winhl = "Normal:SlidesFooter,NormalNC:SlidesFooter"
          vim.wo[created_win].wrap = false
        end)
      end
    else
      pcall(vim.api.nvim_win_set_config, footer_win, {
        relative = "win",
        win = win,
        row = win_height - 1,
        col = 0,
        width = win_width,
        height = 1,
      })
    end
  end

  -- Also set extmark on the buffer for headless/compatibility use
  if buf and vim.api.nvim_buf_is_valid(buf) then
    local line_count = vim.api.nvim_buf_line_count(buf)
    local target_row = math.max(0, line_count - 1)

    if footer_align == "right" then
      pcall(vim.api.nvim_buf_set_extmark, buf, M.footer_ns, target_row, 0, {
        virt_text = { { status_text .. " ", "SlidesFooter" } },
        virt_text_pos = "right_align",
        hl_mode = "combine",
      })
    elseif footer_align == "left" then
      pcall(vim.api.nvim_buf_set_extmark, buf, M.footer_ns, target_row, 0, {
        virt_text = { { " " .. status_text, "SlidesFooter" } },
        virt_text_pos = "inline",
        hl_mode = "combine",
      })
    elseif footer_align == "center" then
      local pad = math.max(0, math.floor((win_width - #status_text) / 2))
      pcall(vim.api.nvim_buf_set_extmark, buf, M.footer_ns, target_row, 0, {
        virt_text = { { string.rep(" ", pad) .. status_text, "SlidesFooter" } },
        virt_text_pos = "eol",
        hl_mode = "combine",
      })
    end
  end
end

--- Apply horizontal centering via inline virtual text extmarks.
--- This visually centers lines without prepending spaces into the actual text buffer,
--- allowing Markdown, Treesitter, and colorschemes to highlight headings and text accurately.
--- @param buf integer Buffer handle
--- @param win integer Window handle
--- @param top_pad integer Top padding offset lines
--- @param trimmed_lines table Unpadded slide content lines
--- @param config table Plugin configuration
function M.apply_horizontal_padding(buf, win, top_pad, trimmed_lines, config)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)

  local options = (config and config.options) or {}
  local horiz_align = options.horizontal_align or "left"
  if horiz_align == "left" then
    return
  end

  local win_width = (win and vim.api.nvim_win_is_valid(win)) and vim.api.nvim_win_get_width(win) or 80

  if horiz_align == "center" then
    -- Block centering: centers the entire slide block while preserving internal indentations
    local max_w = 0
    for _, line in ipairs(trimmed_lines) do
      max_w = math.max(max_w, vim.fn.strdisplaywidth(line))
    end
    local left_pad = math.max(0, math.floor((win_width - max_w) / 2))
    if left_pad > 0 then
      local pad_str = string.rep(" ", left_pad)
      for i, line in ipairs(trimmed_lines) do
        if not line:match("^%s*$") then
          local row = top_pad + i - 1
          pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, row, 0, {
            virt_text = { { pad_str, "Normal" } },
            virt_text_pos = "inline",
            hl_mode = "combine",
          })
        end
      end
    end
  elseif horiz_align == "line" then
    -- Line-by-line centering
    for i, line in ipairs(trimmed_lines) do
      if not line:match("^%s*$") then
        local line_w = vim.fn.strdisplaywidth(line)
        local left_pad = math.max(0, math.floor((win_width - line_w) / 2))
        if left_pad > 0 then
          local row = top_pad + i - 1
          pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, row, 0, {
            virt_text = { { string.rep(" ", left_pad), "Normal" } },
            virt_text_pos = "inline",
            hl_mode = "combine",
          })
        end
      end
    end
  end
end

--- Create the presentation view according to config (tab or buffer mode)
--- @param state table Presentation state
--- @param config table Plugin configuration
--- @param on_cleanup function Cleanup callback when buffer is wiped
function M.create_view(state, config, on_cleanup)
  local mode = config.options.mode or "tab"

  -- Record source context
  state.source_tab = vim.api.nvim_get_current_tabpage()
  state.source_win = vim.api.nvim_get_current_win()
  state.source_buf = vim.api.nvim_get_current_buf()

  -- Determine file extension based on filetype so syntax and plugins attach properly
  local ext = "md"
  if state.filetype == "org" then
    ext = "org"
  elseif state.filetype == "adoc" or state.filetype == "asciidoctor" then
    ext = "adoc"
  end

  -- Create dedicated slide buffer
  local slide_buf = vim.api.nvim_create_buf(false, true)
  local existing = vim.fn.bufnr("^Slides$")
  if existing ~= -1 and existing ~= slide_buf and vim.api.nvim_buf_is_valid(existing) then
    pcall(vim.api.nvim_buf_delete, existing, { force = true })
  end
  pcall(vim.api.nvim_buf_set_name, slide_buf, "Slides")

  M.default_configure_buffer(slide_buf, state.filetype)

  if type(config.configure_slide_buffer) == "function" then
    pcall(config.configure_slide_buffer, slide_buf)
  end

  state.slide_buf = slide_buf

  if mode == "tab" then
    -- Open a new tabpage for presentation
    vim.cmd("tabnew")
    local tab = vim.api.nvim_get_current_tabpage()
    local win = vim.api.nvim_get_current_win()
    local old_buf = vim.api.nvim_win_get_buf(win)
    vim.api.nvim_win_set_buf(win, slide_buf)
    if old_buf ~= slide_buf and vim.api.nvim_buf_is_valid(old_buf) then
      pcall(vim.api.nvim_buf_delete, old_buf, { force = true })
    end
    state.slide_tab = tab
    state.slide_win = win
    pcall(vim.api.nvim_tabpage_set_var, tab, "tab_title", "Slides")
    pcall(vim.api.nvim_tabpage_set_var, tab, "name", "Slides")
    M.configure_window(win, config)
  else
    -- Buffer mode: replace current window buffer
    local win = state.source_win
    vim.api.nvim_win_set_buf(win, slide_buf)
    state.slide_win = win
    state.slide_tab = state.source_tab
    M.configure_window(win, config)
  end

  -- Apply keymaps
  M.setup_keymaps(slide_buf, config.keymaps)

  -- Self-cleaning autocmd if user closes window/buffer manually
  local augroup = vim.api.nvim_create_augroup("SlidesLifecycle_" .. slide_buf, { clear = true })
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = augroup,
    buffer = slide_buf,
    once = true,
    callback = function()
      if state.footer_win and vim.api.nvim_win_is_valid(state.footer_win) then
        pcall(vim.api.nvim_win_close, state.footer_win, true)
        state.footer_win = nil
      end
      if state.footer_buf and vim.api.nvim_buf_is_valid(state.footer_buf) then
        pcall(vim.api.nvim_buf_delete, state.footer_buf, { force = true })
        state.footer_buf = nil
      end
      if on_cleanup then
        on_cleanup()
      end
    end,
  })

  -- Window resize autocmd to maintain centering on resize
  vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
    group = augroup,
    callback = function()
      if state and state.current_slide and state.slide_buf and vim.api.nvim_buf_is_valid(state.slide_buf) then
        M.set_slide_content(state, state.current_slide, config, false)
      end
    end,
  })

  return true
end

--- Update slide buffer lines with current slide content
--- @param state table Presentation state
--- @param slide_idx integer Slide index to display
--- @param config table|nil Plugin configuration
--- @param reset_scroll boolean|nil Whether to reset scroll position (defaults to true)
function M.set_slide_content(state, slide_idx, config, reset_scroll)
  if not state or not state.slide_buf or not vim.api.nvim_buf_is_valid(state.slide_buf) then
    return false
  end

  if reset_scroll ~= false then
    state.scroll_offset = 0
    state.last_scroll_dir = "down"
  end

  local raw_lines = state.slides[slide_idx] or { "" }
  state.current_slide = slide_idx

  local final_lines, top_pad, trimmed_lines, scroll_status, actual_scroll_offset, max_scroll_offset, is_scrollable =
    M.format_slide_lines(raw_lines, state.slide_win, config, state.scroll_offset, state.last_scroll_dir)

  state.top_pad = top_pad
  state.scroll_status = scroll_status
  state.scroll_offset = actual_scroll_offset
  state.max_scroll_offset = max_scroll_offset
  state.is_scrollable = is_scrollable
  state.viewport_h = #trimmed_lines

  vim.bo[state.slide_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.slide_buf, 0, -1, false, final_lines)
  vim.bo[state.slide_buf].modifiable = false

  -- Apply horizontal centering without altering line text tokens
  M.apply_horizontal_padding(state.slide_buf, state.slide_win, top_pad, trimmed_lines, config)

  -- Ensure syntax and treesitter highlighting are active
  if state.filetype and state.filetype ~= "" then
    if vim.bo[state.slide_buf].syntax ~= state.filetype then
      vim.bo[state.slide_buf].syntax = state.filetype
    end
    pcall(vim.treesitter.start, state.slide_buf, state.filetype)
  end

  -- Set window scroll position and cursor
  if state.slide_win and vim.api.nvim_win_is_valid(state.slide_win) then
    local topline = 1 + state.scroll_offset
    local cursor_lnum = math.max(topline, top_pad + 1)
    pcall(vim.api.nvim_win_call, state.slide_win, function()
      vim.fn.winrestview({ topline = topline, lnum = cursor_lnum, col = 0 })
    end)
  end

  -- Apply footer indicator at the bottom of the slide (e.g. 1/12  Scroll down)
  M.apply_footer_indicator(state.slide_buf, state.slide_win, state, config)

  if config and config.options and config.options.show_statusline then
    pcall(vim.cmd, "redrawstatus")
  end

  return true
end

--- Smoothly update window scroll position without re-mutating buffer lines
--- @param state table Presentation state
--- @param config table Plugin configuration
function M.scroll_slide(state, config)
  if not state or not state.slide_win or not vim.api.nvim_win_is_valid(state.slide_win) then
    return
  end

  local offset = state.scroll_offset or 0
  local max_offset = state.max_scroll_offset or 0

  if offset == 0 then
    state.scroll_status = "Scroll down"
  elseif offset >= max_offset then
    state.scroll_status = "End"
  else
    state.scroll_status = (state.last_scroll_dir == "up") and "Scroll up" or "Scroll down"
  end

  local topline = 1 + offset
  local cursor_lnum = math.max(topline, (state.top_pad or 0) + 1)
  pcall(vim.api.nvim_win_call, state.slide_win, function()
    vim.fn.winrestview({ topline = topline, lnum = cursor_lnum, col = 0 })
  end)

  M.apply_footer_indicator(state.slide_buf, state.slide_win, state, config)

  if config and config.options and config.options.show_statusline then
    pcall(vim.cmd, "redrawstatus")
  end
end

--- Re-render the current slide without resetting scroll position
--- @param state table Presentation state
--- @param config table|nil Plugin configuration
function M.render_current_slide(state, config)
  return M.set_slide_content(state, state.current_slide or 1, config, false)
end

--- Destroy presentation view and restore user's original context
--- @param state table Presentation state
--- @param config table Plugin configuration
function M.destroy_view(state, config)
  if not state then
    return
  end

  -- Close footer floating window if open
  if state.footer_win and vim.api.nvim_win_is_valid(state.footer_win) then
    pcall(vim.api.nvim_win_close, state.footer_win, true)
    state.footer_win = nil
  end
  if state.footer_buf and vim.api.nvim_buf_is_valid(state.footer_buf) then
    pcall(vim.api.nvim_buf_delete, state.footer_buf, { force = true })
    state.footer_buf = nil
  end

  local mode = config.options.mode or "tab"

  if mode == "tab" then
    -- Close presentation tab if valid
    if state.slide_tab and vim.api.nvim_tabpage_is_valid(state.slide_tab) then
      if vim.api.nvim_get_current_tabpage() == state.slide_tab then
        pcall(vim.cmd, "tabclose!")
      else
        local wins = vim.api.nvim_tabpage_list_wins(state.slide_tab)
        for _, w in ipairs(wins) do
          if vim.api.nvim_win_is_valid(w) then
            pcall(vim.api.nvim_win_close, w, true)
          end
        end
      end
    end

    -- Return focus to original tabpage and window
    if state.source_tab and vim.api.nvim_tabpage_is_valid(state.source_tab) then
      pcall(vim.api.nvim_set_current_tabpage, state.source_tab)
    end
    if state.source_win and vim.api.nvim_win_is_valid(state.source_win) then
      pcall(vim.api.nvim_set_current_win, state.source_win)
    end

    -- Delete presentation buffer if still valid
    if state.slide_buf and vim.api.nvim_buf_is_valid(state.slide_buf) then
      pcall(vim.api.nvim_buf_delete, state.slide_buf, { force = true })
      state.slide_buf = nil
    end
  else
    -- Buffer mode: restore original buffer
    if state.source_win and vim.api.nvim_win_is_valid(state.source_win) then
      if state.source_buf and vim.api.nvim_buf_is_valid(state.source_buf) then
        pcall(vim.api.nvim_win_set_buf, state.source_win, state.source_buf)
      end
    end
    -- Delete presentation buffer if still valid
    if state.slide_buf and vim.api.nvim_buf_is_valid(state.slide_buf) then
      pcall(vim.api.nvim_buf_delete, state.slide_buf, { force = true })
      state.slide_buf = nil
    end
  end
end

return M

