local M = {}

local total_tests = 0
local passed_tests = 0
local failed_tests = 0
local failures = {}

function M.describe(description, fn)
  print("\n\27[1m=== " .. description .. " ===\27[0m")
  local ok, err = pcall(fn)
  if not ok then
    print("\27[31mSuite error: " .. tostring(err) .. "\27[0m")
    table.insert(failures, { test = description, err = err })
    failed_tests = failed_tests + 1
  end
end

function M.it(description, fn)
  total_tests = total_tests + 1
  local ok, err = pcall(fn)
  if ok then
    passed_tests = passed_tests + 1
    print("  \27[32m✓\27[0m " .. description)
  else
    failed_tests = failed_tests + 1
    print("  \27[31m✗\27[0m " .. description)
    print("    \27[31m" .. tostring(err) .. "\27[0m")
    table.insert(failures, { test = description, err = err })
  end
end

function M.assert_equal(actual, expected, msg)
  if actual ~= expected then
    error(
      string.format(
        "%sExpected '%s' (type %s), got '%s' (type %s)",
        msg and (msg .. ": ") or "",
        vim.inspect(expected),
        type(expected),
        vim.inspect(actual),
        type(actual)
      ),
      2
    )
  end
end

function M.assert_deep_equal(actual, expected, msg)
  local actual_str = vim.inspect(actual)
  local expected_str = vim.inspect(expected)
  if actual_str ~= expected_str then
    error(
      string.format(
        "%sMismatch:\nExpected: %s\nActual:   %s",
        msg and (msg .. ": ") or "",
        expected_str,
        actual_str
      ),
      2
    )
  end
end

function M.assert_true(condition, msg)
  if not condition then
    error(msg or "Expected condition to be true, got false/nil", 2)
  end
end

function M.assert_false(condition, msg)
  if condition then
    error(msg or "Expected condition to be false, got true", 2)
  end
end

function M.assert_nil(value, msg)
  if value ~= nil then
    error(
      string.format("%sExpected nil, got '%s'", msg and (msg .. ": ") or "", vim.inspect(value)),
      2
    )
  end
end

function M.assert_not_nil(value, msg)
  if value == nil then
    error(msg or "Expected non-nil value, got nil", 2)
  end
end

function M.summary()
  print("\n\27[1m----------------------------------------\27[0m")
  print(string.format("Total:  %d", total_tests))
  print(string.format("\27[32mPassed: %d\27[0m", passed_tests))
  if failed_tests > 0 then
    print(string.format("\27[31mFailed: %d\27[0m", failed_tests))
    print("\n\27[31mFailures summary:\27[0m")
    for i, f in ipairs(failures) do
      print(string.format("%d) %s:\n   %s", i, f.test, tostring(f.err)))
    end
    return false
  else
    print("\27[32mAll tests passed successfully!\27[0m")
    return true
  end
end

return M
