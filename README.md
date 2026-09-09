# slides.nvim

A lightweight, distraction-free presentation plugin for Neovim that turns your markdown, org-mode, and asciidoc files into slides rendered directly inside a dedicated **new tab** or a **new buffer**.

Inspired by [presenting.nvim](https://github.com/sotte/presenting.nvim), but built to present slides cleanly in their own tab/buffer without awkward floating overlays or horizontal pane splits.

<img width="2244" height="1516" alt="Slides-nvim" src="https://github.com/user-attachments/assets/c434dd78-3126-4b51-8e53-c0b86d83df98" />

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

### Neovim Built-in (`vim.pack` — [Docs](https://neovim.io/doc/user/pack/#vim.pack-examples))

Neovim's native package manager (`vim.pack`). Add to your `init.lua`:

```lua
vim.pack.add({
  "https://github.com/git-emran/slides.nvim",
})

require("slides").setup({
  options = {
    mode = "tab", -- "tab" (default) or "buffer"
  },
})
```

You can also specify a git branch, tag, or version constraint:
```lua
vim.pack.add({
  {
    src = "https://github.com/git-emran/slides.nvim",
    version = "main", -- or tag / version constraint like vim.version.range('1.0')
  },
})
```

- Run `:packupdate` to fetch and confirm updates.

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

### Manual Package Installation ([`:help packages`](https://neovim.io/doc/user/pack/#packages))

Clone into your Neovim pack directory (`~/.local/share/nvim/site/pack/...`):

```bash
# Automatically loaded on startup ("start" package):
git clone https://github.com/git-emran/slides.nvim ~/.local/share/nvim/site/pack/plugins/start/slides.nvim

# Or loaded on-demand ("opt" package):
git clone https://github.com/git-emran/slides.nvim ~/.local/share/nvim/site/pack/plugins/opt/slides.nvim
```

If placed in `opt/`, load it in your `init.lua` with `vim.cmd("packadd slides.nvim")` and call `require("slides").setup()`.

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
| `j` or `<Down>` | Scroll down 1 line (when slide has lots of text) |
| `k` or `<Up>` | Scroll up 1 line |
| `<C-d>` or `d` | Scroll down half-screen |
| `<C-u>` or `u` | Scroll up half-screen |
| `<C-f>` or `<PageDown>` | Scroll down full screen |
| `<C-b>` or `<PageUp>` | Scroll up full screen |
| `gg` | Scroll to top of slide |
| `G` | Scroll to bottom of slide |
| `f` | First slide |
| `l` | Last slide |
| `q` | Quit presentation mode |

### Command Usage

```vim
:Slides               " Toggle presentation mode
:Slides next          " Jump to next slide
:Slides prev          " Jump to previous slide
:Slides first         " Jump to first slide
:Slides last          " Jump to last slide
:Slides scroll_down   " Scroll down inside current slide (alias: :Slides down)
:Slides scroll_up     " Scroll up inside current slide (alias: :Slides up)
:Slides scroll_top    " Jump to top of current slide (alias: :Slides top)
:Slides scroll_bottom " Jump to bottom of current slide (alias: :Slides bottom)
:Slides quit          " Exit presentation
:Slides ^---          " Present using custom separator
```

### Scroll Status Indicator

When slides contain lots of text, the presentation UI retains its padding and structure without overflowing the screen. The text area becomes scrollable, and a status label appears beside the slide counter in the footer:

- **`Scroll down`**: Displayed when there is more slide content below the view.
- **`Scroll up`**: Displayed when scrolling up and slide content remains above the view.
- **`End`**: Displayed when you have reached the end of the slide content.

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
    -- Display slide counter indicator at the bottom-left of the slide (e.g. "1/12  Scroll down")
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
    ["j"] = function() Slides.scroll_down(1) end,
    ["k"] = function() Slides.scroll_up(1) end,
    ["<Down>"] = function() Slides.scroll_down(1) end,
    ["<Up>"] = function() Slides.scroll_up(1) end,
    ["<C-d>"] = function() Slides.scroll_down(5) end,
    ["<C-u>"] = function() Slides.scroll_up(5) end,
    ["<C-f>"] = function() Slides.scroll_page_down() end,
    ["<C-b>"] = function() Slides.scroll_page_up() end,
    ["<PageDown>"] = function() Slides.scroll_page_down() end,
    ["<PageUp>"] = function() Slides.scroll_page_up() end,
    ["d"] = function() Slides.scroll_down(5) end,
    ["u"] = function() Slides.scroll_up(5) end,
    ["gg"] = function() Slides.scroll_to_top() end,
    ["G"] = function() Slides.scroll_to_bottom() end,
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
