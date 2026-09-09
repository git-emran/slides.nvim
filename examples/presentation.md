# slides.nvim

A lightweight, distraction-free presentation plugin for Neovim that turns your markdown, org-mode, and asciidoc files into slides rendered directly inside a dedicated **new tab** or a **new buffer**.

Inspired by [presenting.nvim](https://github.com/sotte/presenting.nvim), but built to present slides cleanly in their own tab/buffer without awkward floating overlays or horizontal pane splits.

---

## ✨ Features

- **Isolated Tab or Buffer View**: Slides open in a dedicated tabpage (`mode = "tab"`, default) or replace the buffer in the current window (`mode = "buffer"`). Quitting cleanly restores your prior window layout and cursor position.
- **Identical Controls**: Familiar keyboard controls (`n`, `p`, `f`, `l`, `q`, `<CR>`, `<BS>`).
- **Unified Command**: Single intuitive command `:Slides` with subcommands and custom separator support.
- **Markup Support**: Built-in separators for Markdown, Org-mode, and AsciiDoc, plus support for frontmatter stripping and custom separators (`---`, etc.).
- **Auto-Cleanup**: Automatically cleans up state if a tab or buffer is closed unexpectedly (`:tabclose`, `:bdelete`).
- **Zero External Dependencies**: Pure Lua, fully tested with headless Neovim unit tests.

---

## 📦 Installation

Install with your favorite plugin manager:

### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
  "git-emran/slides.nvim",
  cmd = { "Slides" },
  opts = {
    options = {
      mode = "tab", -- "tab" (default) or "buffer"
    },
  },
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use({
  "git-emran/slides.nvim",
  config = function()
    require("slides").setup()
  end,
})
```

---

## 🚀 Usage

Open any Markdown, Org, or AsciiDoc document and run:

```vim
:Slides
```

### Navigation Controls (Slide Buffer)

| Key | Action |
|---|---|
| `n` or `<CR>` | Next slide |
| `p` or `<BS>` | Previous slide |
| `f` | First slide |
| `l` | Last slide |
| `q` | Quit presentation mode |

### Command Usage

```vim
:Slides          " Toggle presentation mode
:Slides next     " Jump to next slide
:Slides prev     " Jump to previous slide
:Slides first    " Jump to first slide
:Slides last     " Jump to last slide
:Slides quit     " Exit presentation
:Slides ^---     " Present using custom separator
```

---

## ⚙️ Configuration

Pass any overrides to `require("slides").setup()`:

```lua
require("slides").setup({
  options = {
    -- Presentation display mode: "tab" (new tabpage) or "buffer" (current window)
    mode = "tab",
    -- Wrap lines in slide window
    wrap = true,
    -- Show slide indicator in the window statusline bar (off by default, footer is used instead)
    show_statusline = false,
    -- Display slide counter indicator at the bottom-left of the slide (e.g. "1/12")
    show_footer = true,
    -- Footer alignment: "left" (default), "right", or "center"
    footer_align = "left",
    -- Vertical alignment: "center" (default) or "top"
    vertical_align = "center",
    -- Horizontal alignment: "left" (default), "center" (block-centered), or "line" (each line centered)
    horizontal_align = "left",
  },
  separator = {
    markdown = "^#+ ",
    org = "^*+ ",
    adoc = "^==+ ",
    asciidoctor = "^==+ ",
  },
  -- Retain header/separator lines in slide content
  keep_separator = true,
  -- Strip YAML frontmatter between leading '---' lines
  parse_frontmatter = false,
  -- Local keymaps for the slide buffer
  keymaps = {
    ["n"] = function() Slides.next() end,
    ["p"] = function() Slides.prev() end,
    ["q"] = function() Slides.quit() end,
    ["f"] = function() Slides.first() end,
    ["l"] = function() Slides.last() end,
    ["<CR>"] = function() Slides.next() end,
    ["<BS>"] = function() Slides.prev() end,
  },
  -- Custom hook to configure slide buffer
  configure_slide_buffer = nil,
})
```

---

## 🧪 Running Tests

Run the test suite via headless Neovim:

```bash
make test
```

---

## 📄 License

MIT
