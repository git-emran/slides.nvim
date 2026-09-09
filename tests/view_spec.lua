local T = require("tests.test_helper")
local view = require("slides.view")

T.describe("slides.view", function()
  T.it("configures buffer with correct options", function()
    local buf = vim.api.nvim_create_buf(false, true)
    view.default_configure_buffer(buf, "markdown")

    T.assert_equal(vim.bo[buf].buftype, "nofile")
    T.assert_equal(vim.bo[buf].bufhidden, "wipe")
    T.assert_equal(vim.bo[buf].swapfile, false)
    T.assert_equal(vim.bo[buf].modifiable, false)
    T.assert_equal(vim.bo[buf].filetype, "markdown")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  T.it("formats slide lines with vertical centering and applies horizontal extmark padding", function()
    local win = vim.api.nvim_get_current_win()
    local raw = { "# Title", "Paragraph text" }

    -- Test center alignment
    local centered, top_pad, trimmed = view.format_slide_lines(raw, win, {
      options = { vertical_align = "center", horizontal_align = "center", show_footer = false },
    })
    T.assert_true(#centered > #raw, "Expected vertical top padding")
    T.assert_true(top_pad > 0, "Expected top padding offset")
    -- Ensure raw markdown tokens are preserved without leading spaces
    T.assert_equal(centered[top_pad + 1], "# Title")

    -- Test extmark horizontal padding
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, centered)
    view.apply_horizontal_padding(buf, win, top_pad, trimmed, {
      options = { horizontal_align = "center" },
    })

    local marks = vim.api.nvim_buf_get_extmarks(buf, view.ns_id, 0, -1, { details = true })
    T.assert_true(#marks > 0, "Expected horizontal virtual padding extmarks")
    vim.api.nvim_buf_delete(buf, { force = true })

    -- Test top/left alignment without footer padding
    local uncentered, uncentered_top = view.format_slide_lines(raw, win, {
      options = { vertical_align = "top", horizontal_align = "left", show_footer = false },
    })
    T.assert_equal(uncentered_top, 0)
    T.assert_deep_equal(uncentered, raw)
  end)

  T.it("renders footer indicator at the bottom of the slide", function()
    local win = vim.api.nvim_get_current_win()
    local state = {
      filetype = "markdown",
      slides = { { "# Slide 1" }, { "# Slide 2" }, { "# Slide 3" } },
      current_slide = 1,
    }
    local config = {
      options = { show_footer = true, footer_align = "right" },
    }
    local buf = vim.api.nvim_create_buf(false, true)
    state.slide_buf = buf
    state.slide_win = win

    view.set_slide_content(state, 1, config)
    local marks = vim.api.nvim_buf_get_extmarks(buf, view.footer_ns, 0, -1, { details = true })
    T.assert_true(#marks > 0, "Expected footer extmark")
    local mark_text = marks[1][4].virt_text[1][1]
    T.assert_true(mark_text:match("1/3") ~= nil, "Expected footer to contain '1/3'")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  T.it("creates and destroys view in tab mode cleanly", function()
    local orig_tab_count = #vim.api.nvim_list_tabpages()
    local orig_tab = vim.api.nvim_get_current_tabpage()
    local orig_win = vim.api.nvim_get_current_win()

    local state = {
      filetype = "markdown",
      slides = {
        { "# Slide 1", "Content 1" },
        { "# Slide 2", "Content 2" },
      },
      current_slide = 1,
    }

    local config = {
      options = {
        mode = "tab",
        wrap = true,
        show_statusline = false,
        show_footer = false,
        vertical_align = "top",
        horizontal_align = "left",
      },
      keymaps = {},
    }

    local cleaned_up = false
    view.create_view(state, config, function()
      cleaned_up = true
    end)

    T.assert_equal(#vim.api.nvim_list_tabpages(), orig_tab_count + 1)
    T.assert_not_nil(state.slide_tab)
    T.assert_not_nil(state.slide_buf)
    T.assert_not_nil(state.slide_win)

    view.set_slide_content(state, 1, config)
    local lines = vim.api.nvim_buf_get_lines(state.slide_buf, 0, -1, false)
    T.assert_deep_equal(lines, { "# Slide 1", "Content 1" })

    -- Test destroy view
    view.destroy_view(state, config)

    T.assert_equal(#vim.api.nvim_list_tabpages(), orig_tab_count)
    T.assert_equal(vim.api.nvim_get_current_tabpage(), orig_tab)
    T.assert_equal(vim.api.nvim_get_current_win(), orig_win)
  end)

  T.it("creates and destroys view in buffer mode cleanly", function()
    local test_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(0, test_buf)
    local orig_win = vim.api.nvim_get_current_win()

    local state = {
      filetype = "markdown",
      slides = {
        { "# Slide 1" },
        { "# Slide 2" },
      },
      current_slide = 1,
    }

    local config = {
      options = { mode = "buffer", wrap = true, show_statusline = false, show_footer = false },
      keymaps = {},
    }

    view.create_view(state, config)
    T.assert_equal(vim.api.nvim_win_get_buf(orig_win), state.slide_buf)

    view.destroy_view(state, config)
    T.assert_equal(vim.api.nvim_win_get_buf(orig_win), test_buf)

    vim.api.nvim_buf_delete(test_buf, { force = true })
  end)

  T.it("formats long slide content as a scrollable view with scroll status indicators", function()
    local win = vim.api.nvim_get_current_win()
    -- Create 40 lines of text
    local raw = {}
    for i = 1, 40 do
      table.insert(raw, string.format("Line %d of lots of text", i))
    end

    local config = {
      options = { vertical_align = "center", show_footer = true, footer_align = "left" },
    }

    -- 1. Initial view at top (scroll_offset = 0)
    local lines_top, top_pad, visible, status, offset, max_offset, is_scrollable =
      view.format_slide_lines(raw, win, config, 0, "down")

    T.assert_true(is_scrollable, "Expected long slide to be scrollable")
    T.assert_equal(status, "Scroll down", "Expected 'Scroll down' at top of slide")
    T.assert_equal(offset, 0)
    T.assert_true(max_offset > 0, "Expected max_offset to be > 0")
    T.assert_equal(visible[1], "Line 1 of lots of text")

    -- 2. Scrolled down to end (scroll_offset = max_offset)
    local lines_end, _, visible_end, status_end =
      view.format_slide_lines(raw, win, config, max_offset, "down")

    T.assert_equal(status_end, "End", "Expected 'End' status at bottom of slide")
    T.assert_equal(visible_end[#visible_end], "Line 40 of lots of text")

    -- 3. Scrolled up in the middle (scroll_offset = 5, last_scroll_dir = 'up')
    local _, _, _, status_up =
      view.format_slide_lines(raw, win, config, 5, "up")
    T.assert_equal(status_up, "Scroll up", "Expected 'Scroll up' status when scrolling up in middle")

    -- 4. Test footer rendering with scroll status
    local state = {
      filetype = "markdown",
      slides = { raw },
      current_slide = 1,
      scroll_status = "Scroll down",
    }
    local buf = vim.api.nvim_create_buf(false, true)
    state.slide_buf = buf
    state.slide_win = win

    view.set_slide_content(state, 1, config)
    local marks = vim.api.nvim_buf_get_extmarks(buf, view.footer_ns, 0, -1, { details = true })
    T.assert_true(#marks > 0, "Expected footer extmark")
    local mark_text = marks[1][4].virt_text[1][1]
    T.assert_true(mark_text:match("1/1") ~= nil, "Expected footer to contain '1/1'")
    T.assert_true(mark_text:match("Scroll down") ~= nil, "Expected footer to contain 'Scroll down'")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)
end)
