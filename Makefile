.PHONY: test

test:
	nvim --headless --clean -u NONE -c "luafile tests/runner.lua"
