local M = {}

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

--- Format slide lines with vertical and horizontal centering according to configuration
--- @param raw_lines table List of slide lines
--- @param win integer Window handle
--- @param config table Plugin configuration
--- @return table formatted_lines, integer first_content_line
function M.format_slide_lines(raw_lines, win, config)
  raw_lines = raw_lines or { "" }
  local options = (config and config.options) or {}
  local vert_align = options.vertical_align or "center"
  local horiz_align = options.horizontal_align or "center"

  -- Trim leading and trailing empty lines for accurate vertical centering calculation
  local lines = vim.deepcopy(raw_lines)
  while #lines > 1 and lines[1]:match("^%s*$") do
    table.remove(lines, 1)
  end
  while #lines > 1 and lines[#lines]:match("^%s*$") do
    table.remove(lines, #lines)
  end

  local win_height = (win and vim.api.nvim_win_is_valid(win)) and vim.api.nvim_win_get_height(win) or 24
  local win_width = (win and vim.api.nvim_win_is_valid(win)) and vim.api.nvim_win_get_width(win) or 80

  -- Horizontal centering
  local formatted_content = {}
  if horiz_align == "center" then
    -- Block centering: centers the entire block while preserving indentation and code layout
    local max_w = 0
    for _, line in ipairs(lines) do
      max_w = math.max(max_w, vim.fn.strdisplaywidth(line))
    end
    local left_pad = math.max(0, math.floor((win_width - max_w) / 2))
    local pad_str = string.rep(" ", left_pad)
    for _, line in ipairs(lines) do
      if line:match("^%s*$") then
        table.insert(formatted_content, "")
      else
        table.insert(formatted_content, pad_str .. line)
      end
    end
  elseif horiz_align == "line" then
    -- Line-by-line centering
    for _, line in ipairs(lines) do
      if line:match("^%s*$") then
        table.insert(formatted_content, "")
      else
        local line_w = vim.fn.strdisplaywidth(line)
        local left_pad = math.max(0, math.floor((win_width - line_w) / 2))
        table.insert(formatted_content, string.rep(" ", left_pad) .. line)
      end
    end
  else
    -- Left aligned (no padding)
    formatted_content = lines
  end

  -- Vertical centering
  local final_lines = {}
  local first_content_line = 1
  if vert_align == "center" then
    local content_h = #formatted_content
    local top_pad = math.max(0, math.floor((win_height - content_h) / 2))
    for _ = 1, top_pad do
      table.insert(final_lines, "")
    end
    first_content_line = top_pad + 1
  end

  for _, line in ipairs(formatted_content) do
    table.insert(final_lines, line)
  end

  if #final_lines == 0 then
    final_lines = { "" }
  end

  return final_lines, first_content_line
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

  -- Create dedicated slide buffer
  local slide_buf = vim.api.nvim_create_buf(false, true)
  pcall(vim.api.nvim_buf_set_name, slide_buf, "slides://presentation")

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

  local formatted_lines, first_line = M.format_slide_lines(raw_lines, state.slide_win, config)

  vim.bo[state.slide_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.slide_buf, 0, -1, false, formatted_lines)
  vim.bo[state.slide_buf].modifiable = false

  -- Reset cursor to first line of slide content
  if state.slide_win and vim.api.nvim_win_is_valid(state.slide_win) then
    pcall(vim.api.nvim_win_set_cursor, state.slide_win, { math.max(1, first_line or 1), 0 })
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
