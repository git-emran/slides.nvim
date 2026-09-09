local parser = require("slides.parser")
local view = require("slides.view")

local Slides = {}
Slides._state = nil

--- Default configuration
Slides.config = {
  options = {
    -- Presentation display mode: "tab" (new tabpage) or "buffer" (current window)
    mode = "tab",
    -- Wrap long lines in slide window
    wrap = true,
    -- Show slide status indicator in statusline
    show_statusline = true,
  },
  separator = {
    markdown = "^#+ ",
    org = "^*+ ",
    adoc = "^==+ ",
    asciidoctor = "^==+ ",
  },
  -- Retain separator lines as part of slide content
  keep_separator = true,
  -- Parse and strip YAML frontmatter
  parse_frontmatter = false,
  -- Local buffer keymaps active during presentation
  keymaps = {
    ["n"] = function() Slides.next() end,
    ["p"] = function() Slides.prev() end,
    ["q"] = function() Slides.quit() end,
    ["f"] = function() Slides.first() end,
    ["l"] = function() Slides.last() end,
    ["<CR>"] = function() Slides.next() end,
    ["<BS>"] = function() Slides.prev() end,
  },
  -- Optional user hook: function(buf) ... end
  configure_slide_buffer = nil,
}

local default_config = vim.deepcopy(Slides.config)

--- Setup user options
--- @param user_config table|nil
function Slides.setup(user_config)
  _G.Slides = Slides

  if user_config then
    vim.validate({
      options = { user_config.options, "table", true },
      separator = { user_config.separator, "table", true },
      keep_separator = { user_config.keep_separator, "boolean", true },
      parse_frontmatter = { user_config.parse_frontmatter, "boolean", true },
      keymaps = { user_config.keymaps, "table", true },
      configure_slide_buffer = { user_config.configure_slide_buffer, "function", true },
    })

    Slides.config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), user_config)
  else
    Slides.config = vim.deepcopy(default_config)
  end

  Slides._register_command()
end

--- Check if presentation mode is active
--- @return boolean
function Slides.is_presenting()
  return Slides._state ~= nil
end

--- Return current slide index
--- @return integer|nil
function Slides.current_slide()
  return Slides._state and Slides._state.current_slide or nil
end

--- Return total slides count
--- @return integer|nil
function Slides.total_slides()
  return Slides._state and #Slides._state.slides or nil
end

--- Return formatted slide status string e.g. "1/5"
--- @return string
function Slides.status()
  if not Slides.is_presenting() then
    return ""
  end
  return string.format("%d/%d", Slides._state.current_slide, #Slides._state.slides)
end

--- Statusline expression callback
--- @return string
function Slides._statusline()
  if not Slides.is_presenting() then
    return ""
  end
  return string.format("  Slides: %s ", Slides.status())
end

--- Start presentation for the current buffer
--- @param separator string|nil Optional separator override
function Slides.start(separator)
  if Slides.is_presenting() then
    vim.notify("slides.nvim: already presenting", vim.log.levels.WARN)
    return
  end

  if type(separator) == "table" then
    -- Handle cases where user command passes arguments table
    separator = separator.args ~= "" and separator.args or nil
  end

  local filetype = vim.bo.filetype
  separator = separator or Slides.config.separator[filetype]

  if not separator or separator == "" then
    vim.notify(
      string.format(
        "slides.nvim: unsupported filetype '%s'. Specify a separator, e.g. :Slides ^---",
        filetype or "unknown"
      ),
      vim.log.levels.ERROR
    )
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local slides = parser.parse_slides(
    lines,
    separator,
    Slides.config.keep_separator,
    Slides.config.parse_frontmatter
  )

  Slides._state = {
    filetype = filetype,
    slides = slides,
    current_slide = 1,
    separator = separator,
  }

  local ok, err = pcall(function()
    view.create_view(Slides._state, Slides.config, function()
      -- Automatically clean up state if buffer is closed/wiped externally
      Slides._state = nil
    end)
    view.set_slide_content(Slides._state, 1)
  end)

  if not ok then
    Slides._state = nil
    vim.notify("slides.nvim: failed to start presentation: " .. tostring(err), vim.log.levels.ERROR)
  end
end

--- Quit presentation mode and restore original view
function Slides.quit()
  if not Slides.is_presenting() then
    vim.notify("slides.nvim: not in presenting mode", vim.log.levels.WARN)
    return
  end

  local state = Slides._state
  Slides._state = nil

  view.destroy_view(state, Slides.config)
end

--- Toggle presentation mode on/off
--- @param separator string|nil
function Slides.toggle(separator)
  if Slides.is_presenting() then
    Slides.quit()
  else
    Slides.start(separator)
  end
end

--- Navigate to next slide
function Slides.next()
  if not Slides.is_presenting() then
    vim.notify("slides.nvim: not presenting", vim.log.levels.WARN)
    return
  end

  local next_idx = math.min(Slides._state.current_slide + 1, #Slides._state.slides)
  if next_idx ~= Slides._state.current_slide then
    view.set_slide_content(Slides._state, next_idx)
  end
end

--- Navigate to previous slide
function Slides.prev()
  if not Slides.is_presenting() then
    vim.notify("slides.nvim: not presenting", vim.log.levels.WARN)
    return
  end

  local prev_idx = math.max(Slides._state.current_slide - 1, 1)
  if prev_idx ~= Slides._state.current_slide then
    view.set_slide_content(Slides._state, prev_idx)
  end
end

--- Navigate to first slide
function Slides.first()
  if not Slides.is_presenting() then
    vim.notify("slides.nvim: not presenting", vim.log.levels.WARN)
    return
  end

  if Slides._state.current_slide ~= 1 then
    view.set_slide_content(Slides._state, 1)
  end
end

--- Navigate to last slide
function Slides.last()
  if not Slides.is_presenting() then
    vim.notify("slides.nvim: not presenting", vim.log.levels.WARN)
    return
  end

  local last_idx = #Slides._state.slides
  if Slides._state.current_slide ~= last_idx then
    view.set_slide_content(Slides._state, last_idx)
  end
end

--- Register :Slides user command
function Slides._register_command()
  pcall(vim.api.nvim_create_user_command, "Slides", function(opts)
    local arg = opts.args and vim.trim(opts.args) or ""

    if arg == "" then
      Slides.toggle()
    elseif arg == "next" then
      Slides.next()
    elseif arg == "prev" then
      Slides.prev()
    elseif arg == "quit" or arg == "close" then
      Slides.quit()
    elseif arg == "first" then
      Slides.first()
    elseif arg == "last" then
      Slides.last()
    elseif arg == "toggle" then
      Slides.toggle()
    else
      -- Treat any other argument as a custom separator
      Slides.toggle(arg)
    end
  end, {
    nargs = "?",
    desc = "Control slides.nvim presentation",
    complete = function(arglead)
      local subcommands = { "toggle", "next", "prev", "first", "last", "quit" }
      local matches = {}
      for _, cmd in ipairs(subcommands) do
        if vim.startswith(cmd, arglead) then
          table.insert(matches, cmd)
        end
      end
      return matches
    end,
  })
end

return Slides
