local M = {}

--- Parse buffer lines into individual slides.
---
--- @param lines table List of string lines
--- @param separator string Lua pattern used to separate slides
--- @param keep_separator boolean Whether to retain separator lines in the slide content
--- @param parse_frontmatter boolean Whether to strip frontmatter between leading '---' lines
--- @return table List of slides, where each slide is a list of string lines
function M.parse_slides(lines, separator, keep_separator, parse_frontmatter)
  lines = lines or {}
  if #lines == 0 then
    return { { "" } }
  end

  local content_lines = {}

  -- Frontmatter handling
  if parse_frontmatter then
    local in_frontmatter = false
    local frontmatter_count = 0
    local leading_checked = false

    for _, line in ipairs(lines) do
      if not leading_checked and line:match("^%s*$") then
        -- Skip empty lines before frontmatter
        goto continue_fm
      end
      leading_checked = true

      if line:match("^%-%-%-%s*$") then
        frontmatter_count = frontmatter_count + 1
        if frontmatter_count == 1 then
          in_frontmatter = true
          goto continue_fm
        elseif frontmatter_count == 2 then
          in_frontmatter = false
          goto continue_fm
        end
      end

      if not in_frontmatter then
        table.insert(content_lines, line)
      end

      ::continue_fm::
    end

    -- Strip leading blank lines after frontmatter
    while #content_lines > 0 and content_lines[1]:match("^%s*$") do
      table.remove(content_lines, 1)
    end
  else
    content_lines = lines
  end

  if #content_lines == 0 then
    return { { "" } }
  end

  local slides = {}
  local current_slide = {}

  for _, line in ipairs(content_lines) do
    if line:match(separator) then
      if #current_slide > 0 then
        table.insert(slides, current_slide)
        current_slide = {}
      elseif #slides == 0 and #current_slide == 0 then
        -- First line is a separator and no slides collected yet
        if keep_separator then
          table.insert(current_slide, line)
        end
        goto continue_line
      end

      if keep_separator then
        table.insert(current_slide, line)
      end
    else
      table.insert(current_slide, line)
    end

    ::continue_line::
  end

  if #current_slide > 0 then
    table.insert(slides, current_slide)
  end

  if #slides == 0 then
    slides = { { "" } }
  end

  return slides
end

return M
