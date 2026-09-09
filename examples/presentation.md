# Welcome to slides.nvim

A lightweight presentation tool right inside Neovim.

- No external apps needed
- Runs in a clean tab or buffer
- Press `n` or `<CR>` for the next slide

# Key Features

Here is what you can do:

1. Present Markdown, Org-mode, and AsciiDoc
2. Keep your editing layout intact
3. Navigate slides with simple keystrokes:
   - `n`: next slide
   - `p`: previous slide
   - `f`: first slide
   - `l`: last slide
   - `q`: quit presentation

# Code Example

```lua
local slides = require("slides")
slides.setup({
  options = {
    mode = "tab",
  },
})
```

# Thank You!

Press `q` to return to your editor.
