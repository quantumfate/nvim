--- Runs every spec and exits non-zero on failure, so CI and `just test` can use it.
---
---     nvim --headless -c "luafile tests/run.lua"
local t = require("tests.harness")

for _, path in ipairs(vim.fn.glob("tests/*_spec.lua", false, true)) do
	local ok, err = pcall(dofile, path)
	if not ok then
		table.insert(t.results, { name = path .. " (failed to load)", ok = false, err = tostring(err) })
	end
end

local code = t.report()

-- `:cquit` sets the exit status; `:qa!` always exits 0, which makes a failing suite
-- look green to anything checking the code.
if code == 0 then
	vim.cmd("qa!")
else
	vim.cmd("cquit " .. code)
end
