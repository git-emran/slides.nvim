local T = require("tests.test_helper")
local Slides = require("slides")

T.describe("slides (core & integration)", function()
  T.it("initializes with setup and validates configuration", function()
    Slides.setup({
      options = { mode = "tab", wrap = false },
      keep_separator = false,
    })
    T.assert_equal(Slides.config.options.mode, "tab")
    T.assert_equal(Slides.config.options.wrap, false)
    T.assert_equal(Slides.config.keep_separator, false)

    -- Reset to default setup
    Slides.setup()
    T.assert_equal(Slides.config.options.mode, "tab")
    T.assert_equal(Slides.config.options.wrap, true)
    T.assert_equal(Slides.config.keep_separator, true)
  end)

  T.it("presents markdown buffer and navigates with controls", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(0, buf)
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "# First Slide",
      "Line 1",
      "# Second Slide",
      "Line 2",
      "# Third Slide",
      "Line 3",
    })

    T.assert_false(Slides.is_presenting())

    -- Start presentation
    Slides.start()
    T.assert_true(Slides.is_presenting())
    T.assert_equal(Slides.current_slide(), 1)
    T.assert_equal(Slides.total_slides(), 3)
    T.assert_equal(Slides.status(), "1/3")

    -- Check slide 1 content in slide buffer
    T.assert_deep_equal(Slides._state.slides[1], { "# First Slide", "Line 1" })
    local lines1 = vim.api.nvim_buf_get_lines(Slides._state.slide_buf, 0, -1, false)
    local has_title = false
    for _, l in ipairs(lines1) do
      if l:match("# First Slide") then has_title = true end
    end
    T.assert_true(has_title, "Expected rendered lines to contain '# First Slide'")

    -- Navigate next
    Slides.next()
    T.assert_equal(Slides.current_slide(), 2)
    T.assert_equal(Slides.status(), "2/3")
    T.assert_deep_equal(Slides._state.slides[2], { "# Second Slide", "Line 2" })
    local lines2 = vim.api.nvim_buf_get_lines(Slides._state.slide_buf, 0, -1, false)
    local has_slide2 = false
    for _, l in ipairs(lines2) do
      if l:match("# Second Slide") then has_slide2 = true end
    end
    T.assert_true(has_slide2, "Expected rendered lines to contain '# Second Slide'")

    -- Navigate next to last
    Slides.next()
    T.assert_equal(Slides.current_slide(), 3)
    T.assert_equal(Slides.status(), "3/3")

    -- Bound check: cannot go beyond last
    Slides.next()
    T.assert_equal(Slides.current_slide(), 3)

    -- Navigate prev
    Slides.prev()
    T.assert_equal(Slides.current_slide(), 2)

    -- Navigate first
    Slides.first()
    T.assert_equal(Slides.current_slide(), 1)

    -- Bound check: cannot go before 1
    Slides.prev()
    T.assert_equal(Slides.current_slide(), 1)

    -- Navigate last
    Slides.last()
    T.assert_equal(Slides.current_slide(), 3)

    -- Quit presentation
    Slides.quit()
    T.assert_false(Slides.is_presenting())
    T.assert_nil(Slides.current_slide())
    T.assert_nil(Slides.total_slides())

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  T.it("supports :Slides user command navigation", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(0, buf)
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "# Command Slide 1",
      "# Command Slide 2",
    })

    -- Toggle on via command
    vim.cmd("Slides")
    T.assert_true(Slides.is_presenting())
    T.assert_equal(Slides.current_slide(), 1)

    -- Next via command
    vim.cmd("Slides next")
    T.assert_equal(Slides.current_slide(), 2)

    -- Prev via command
    vim.cmd("Slides prev")
    T.assert_equal(Slides.current_slide(), 1)

    -- Last via command
    vim.cmd("Slides last")
    T.assert_equal(Slides.current_slide(), 2)

    -- First via command
    vim.cmd("Slides first")
    T.assert_equal(Slides.current_slide(), 1)

    -- Quit via command
    vim.cmd("Slides quit")
    T.assert_false(Slides.is_presenting())

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  T.it("cleans up state automatically if buffer is closed externally", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(0, buf)
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# Auto Cleanup Slide" })

    Slides.start()
    T.assert_true(Slides.is_presenting())

    local slide_buf = Slides._state.slide_buf
    -- Wipe buffer as if user did :bdelete! or :bwipeout!
    vim.api.nvim_buf_delete(slide_buf, { force = true })

    -- State should automatically be cleaned up
    T.assert_false(Slides.is_presenting())

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  T.it("maps default keys on slide buffer and responds to key commands", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(0, buf)
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "# Keymap Slide 1",
      "# Keymap Slide 2",
      "# Keymap Slide 3",
    })

    Slides.start()
    T.assert_true(Slides.is_presenting())

    local slide_buf = Slides._state.slide_buf
    local keymaps = vim.api.nvim_buf_get_keymap(slide_buf, "n")
    local mapped_keys = {}
    for _, km in ipairs(keymaps) do
      mapped_keys[km.lhs] = true
    end

    -- Verify default keys are mapped
    T.assert_true(mapped_keys["n"] == true, "Expected 'n' to be mapped")
    T.assert_true(mapped_keys["p"] == true, "Expected 'p' to be mapped")
    T.assert_true(mapped_keys["q"] == true, "Expected 'q' to be mapped")
    T.assert_true(mapped_keys["f"] == true, "Expected 'f' to be mapped")
    T.assert_true(mapped_keys["l"] == true, "Expected 'l' to be mapped")

    -- Trigger next via keymap callback
    Slides.config.keymaps["n"]()
    T.assert_equal(Slides.current_slide(), 2)

    -- Trigger last via keymap callback
    Slides.config.keymaps["l"]()
    T.assert_equal(Slides.current_slide(), 3)

    -- Trigger first via keymap callback
    Slides.config.keymaps["f"]()
    T.assert_equal(Slides.current_slide(), 1)

    -- Trigger prev via keymap callback
    Slides.config.keymaps["p"]()
    T.assert_equal(Slides.current_slide(), 1)

    -- Trigger quit via keymap callback
    Slides.config.keymaps["q"]()
    T.assert_false(Slides.is_presenting())

    vim.api.nvim_buf_delete(buf, { force = true })
  end)
end)
