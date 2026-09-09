local T = require("tests.test_helper")
local parser = require("slides.parser")

T.describe("slides.parser", function()
  T.it("parses empty input safely into single empty slide", function()
    local slides = parser.parse_slides({}, "^#+ ", true, false)
    T.assert_equal(#slides, 1)
    T.assert_deep_equal(slides[1], { "" })
  end)

  T.it("parses single slide with no separators", function()
    local input = { "Just a title", "And some content", "Without headings" }
    local slides = parser.parse_slides(input, "^#+ ", true, false)
    T.assert_equal(#slides, 1)
    T.assert_deep_equal(slides[1], input)
  end)

  T.it("parses markdown headings with keep_separator = true", function()
    local input = {
      "# Intro",
      "Welcome to the presentation",
      "## Next Step",
      "Details here",
      "# Summary",
      "Conclusion",
    }
    local slides = parser.parse_slides(input, "^#+ ", true, false)
    T.assert_equal(#slides, 3)
    T.assert_deep_equal(slides[1], { "# Intro", "Welcome to the presentation" })
    T.assert_deep_equal(slides[2], { "## Next Step", "Details here" })
    T.assert_deep_equal(slides[3], { "# Summary", "Conclusion" })
  end)

  T.it("parses markdown horizontal rule separators with keep_separator = false", function()
    local input = {
      "Slide 1 Title",
      "Body 1",
      "---",
      "Slide 2 Title",
      "Body 2",
      "---",
      "Slide 3 Title",
    }
    local slides = parser.parse_slides(input, "^%-%-%-%s*$", false, false)
    T.assert_equal(#slides, 3)
    T.assert_deep_equal(slides[1], { "Slide 1 Title", "Body 1" })
    T.assert_deep_equal(slides[2], { "Slide 2 Title", "Body 2" })
    T.assert_deep_equal(slides[3], { "Slide 3 Title" })
  end)

  T.it("parses org-mode headings", function()
    local input = {
      "* Org Slide 1",
      "Text 1",
      "** Org Slide 2",
      "Text 2",
    }
    local slides = parser.parse_slides(input, "^%*+ ", true, false)
    T.assert_equal(#slides, 2)
    T.assert_deep_equal(slides[1], { "* Org Slide 1", "Text 1" })
    T.assert_deep_equal(slides[2], { "** Org Slide 2", "Text 2" })
  end)

  T.it("parses asciidoc headings", function()
    local input = {
      "== Asciidoc Slide 1",
      "Para 1",
      "=== Asciidoc Slide 2",
      "Para 2",
    }
    local slides = parser.parse_slides(input, "^==+ ", true, false)
    T.assert_equal(#slides, 2)
    T.assert_deep_equal(slides[1], { "== Asciidoc Slide 1", "Para 1" })
    T.assert_deep_equal(slides[2], { "=== Asciidoc Slide 2", "Para 2" })
  end)

  T.it("parses and strips frontmatter when parse_frontmatter = true", function()
    local input = {
      "---",
      "title: My Presentation",
      "author: Jane Doe",
      "---",
      "",
      "# Real Slide 1",
      "Hello world",
      "# Real Slide 2",
      "Second slide",
    }
    local slides = parser.parse_slides(input, "^#+ ", true, true)
    T.assert_equal(#slides, 2)
    T.assert_deep_equal(slides[1], { "# Real Slide 1", "Hello world" })
    T.assert_deep_equal(slides[2], { "# Real Slide 2", "Second slide" })
  end)

  T.it("retains frontmatter lines when parse_frontmatter = false", function()
    local input = {
      "---",
      "title: My Presentation",
      "---",
      "# Real Slide 1",
    }
    local slides = parser.parse_slides(input, "^#+ ", true, false)
    T.assert_equal(#slides, 2)
    T.assert_deep_equal(slides[1], { "---", "title: My Presentation", "---" })
    T.assert_deep_equal(slides[2], { "# Real Slide 1" })
  end)
end)
