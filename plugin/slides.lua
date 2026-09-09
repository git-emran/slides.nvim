-- plugin/slides.lua
if vim.g.loaded_slides_nvim then
  return
end
vim.g.loaded_slides_nvim = true

require("slides")._register_command()
