-- Standalone test runner for slides.nvim
local cwd = vim.fn.getcwd()
package.path = cwd .. "/lua/?.lua;" .. cwd .. "/lua/?/init.lua;" .. cwd .. "/?.lua;" .. package.path

local helper = require("tests.test_helper")

print("\27[1;36mRunning slides.nvim test suite...\27[0m")

-- Run specs
require("tests.parser_spec")
require("tests.view_spec")
require("tests.slides_spec")

local success = helper.summary()

if success then
  vim.cmd("qall!")
else
  vim.cmd("cquit 1")
end
