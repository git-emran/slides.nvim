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

--- Format slide lines for vertical centering without mutating leading line tokens
--- (preserving markdown syntax so lines aren't misidentified as indented code blocks)
--- @param raw_lines table List of slide lines
--- @param win integer Window handle
--- @param config table Plugin configuration
--- @return table final_lines, integer top_pad, table trimmed_lines
function M.format_slide_lines(raw_lines, win, config)
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

  local top_pad = 0
  if vert_align == "center" then
    local content_h = #trimmed_lines
    local reserved = show_footer and 1 or 0
    top_pad = math.max(0, math.floor((win_height - reserved - content_h) / 2))
  end

  local final_lines = {}
  for _ = 1, top_pad do
    table.insert(final_lines, "")
  end
  for _, line in ipairs(trimmed_lines) do
    table.insert(final_lines, line)
  end

  -- Pad down to window bottom so the footer line rests at the bottom of the window
  if show_footer and win_height > #final_lines then
    while #final_lines < win_height do
      table.insert(final_lines, "")
    end
  end

  if #final_lines == 0 then
    final_lines = { "" }
  end

  return final_lines, top_pad, trimmed_lines
end

--- Apply footer indicator (e.g. "1/12") at the bottom of the slide view
--- @param buf integer Buffer handle
--- @param win integer Window handle
--- @param state table Presentation state
--- @param config table Plugin configuration
function M.apply_footer_indicator(buf, win, state, config)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, M.footer_ns, 0, -1)

  local options = (config and config.options) or {}
  if options.show_footer == false then
    return
  end

  local status_text = string.format("%d/%d", state.current_slide or 1, (state.slides and #state.slides) or 1)
  local footer_align = options.footer_align or "left"

  local line_count = vim.api.nvim_buf_line_count(buf)
  local target_row = line_count - 1

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
    local win_width = (win and vim.api.nvim_win_is_valid(win)) and vim.api.nvim_win_get_width(win) or 80
    local pad = math.max(0, math.floor((win_width - #status_text) / 2))
    pcall(vim.api.nvim_buf_set_extmark, buf, M.footer_ns, target_row, 0, {
      virt_text = { { string.rep(" ", pad) .. status_text, "SlidesFooter" } },
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
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
  pcall(vim.api.nvim_buf_set_name, slide_buf, "slides://presentation." .. ext)

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
    vim.api.nvim_win_set_buf(win, slide_buf)
    state.slide_tab = tab
    state.slide_win = win
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
        M.set_slide_content(state, state.current_slide, config)
      end
    end,
  })

  return true
end

--- Update slide buffer lines with current slide content
--- @param state table Presentation state
--- @param slide_idx integer Slide index to display
--- @param config table|nil Plugin configuration
function M.set_slide_content(state, slide_idx, config)
  if not state or not state.slide_buf or not vim.api.nvim_buf_is_valid(state.slide_buf) then
    return false
  end

  local raw_lines = state.slides[slide_idx] or { "" }
  state.current_slide = slide_idx

  local final_lines, top_pad, trimmed_lines = M.format_slide_lines(raw_lines, state.slide_win, config)

  vim.bo[state.slide_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.slide_buf, 0, -1, false, final_lines)
  vim.bo[state.slide_buf].modifiable = false

  -- Apply horizontal centering without altering line text tokens
  M.apply_horizontal_padding(state.slide_buf, state.slide_win, top_pad, trimmed_lines, config)

  -- Apply footer indicator at the bottom of the slide (e.g. 1/12)
  M.apply_footer_indicator(state.slide_buf, state.slide_win, state, config)

  -- Ensure syntax and treesitter highlighting are active
  if state.filetype and state.filetype ~= "" then
    if vim.bo[state.slide_buf].syntax ~= state.filetype then
      vim.bo[state.slide_buf].syntax = state.filetype
    end
    pcall(vim.treesitter.start, state.slide_buf, state.filetype)
  end

  -- Reset cursor to first line of slide content
  if state.slide_win and vim.api.nvim_win_is_valid(state.slide_win) then
    pcall(vim.api.nvim_win_set_cursor, state.slide_win, { math.max(1, top_pad + 1), 0 })
  end

  return true
end

--- Destroy presentation view and restore user's original context
--- @param state table Presentation state
--- @param config table Plugin configuration
function M.destroy_view(state, config)
  if not state then
    return
  end

  local mode = config.options.mode or "tab"

  if mode == "tab" then
    -- Close presentation tab if valid
    if state.slide_tab and vim.api.nvim_tabpage_is_valid(state.slide_tab) then
      if vim.api.nvim_get_current_tabpage() == state.slide_tab then
        pcall(vim.cmd, "tabclose")
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
    end
  end
end

return M
