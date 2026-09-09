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

  T.it("formats slide lines with vertical and horizontal centering", function()
    local win = vim.api.nvim_get_current_win()
    local raw = { "# Title", "Paragraph text" }

    -- Test center alignment
    local centered, first_line = view.format_slide_lines(raw, win, {
      options = { vertical_align = "center", horizontal_align = "center" },
    })
    T.assert_true(#centered > #raw, "Expected vertical top padding")
    T.assert_true(first_line > 1, "Expected first content line to be after top padding")
    T.assert_true(centered[first_line]:match("^%s+# Title$") ~= nil, "Expected horizontal padding on title")

    -- Test top/left alignment
    local uncentered, uncentered_first = view.format_slide_lines(raw, win, {
      options = { vertical_align = "top", horizontal_align = "left" },
    })
    T.assert_equal(uncentered_first, 1)
    T.assert_deep_equal(uncentered, raw)
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
      options = { mode = "buffer", wrap = true, show_statusline = false },
      keymaps = {},
    }

    view.create_view(state, config)
    T.assert_equal(vim.api.nvim_win_get_buf(orig_win), state.slide_buf)

    view.destroy_view(state, config)
    T.assert_equal(vim.api.nvim_win_get_buf(orig_win), test_buf)

    vim.api.nvim_buf_delete(test_buf, { force = true })
  end)
end)
