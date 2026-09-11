--- Runs every spec and exits non-zero on failure, so CI and `just test` can use it.
---
---     nvim --headless -c "luafile tests/run.lua"
local t = require("tests.harness")

-- Tests write files and never want them reformatted. Formatting inside BufWritePre also
-- segfaults nvim in buf_write after some earlier test state (stylua via conform; not
-- reproducible outside a long headless run), which took the whole suite down with it.
vim.g.disable_autoformat = true

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
