--- Choosing which binary to run, and remembering it.
---
--- Only C-like projects need this. Cargo, zig build and a Lua interpreter all know
--- what to execute; a Makefile does not, and guessing `make run` fails on the many
--- projects that have no such target. So the executables are found, offered, and the
--- choice is kept per project.
---@class lang.binary
local M = {}

--- Where choices are remembered between sessions, keyed by project root.
---@return string
local function store()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "lang-run.json")
end

---@return table<string, string>
local function read()
	local ok, content = pcall(vim.fn.readfile, store())
	if not ok or #content == 0 then
		return {}
	end
	local decoded, data = pcall(vim.json.decode, table.concat(content, "\n"))
	return (decoded and type(data) == "table") and data or {}
end

---@param root string
---@param path string
local function write(root, path)
	local data = read()
	data[root] = path
	pcall(vim.fn.writefile, { vim.json.encode(data) }, store())
end

--- Directories never worth scanning: build inputs, dependencies, version control.
local SKIP = {
	[".git"] = true,
	[".jj"] = true,
	["node_modules"] = true,
	[".direnv"] = true,
	[".cache"] = true,
	["CMakeFiles"] = true,
	["_deps"] = true,
}

--- Extensions that are files a build produced but never the thing you run.
local NOT_BINARY = {
	o = true,
	a = true,
	so = true,
	d = true,
	ko = true,
	cmake = true,
	txt = true,
	json = true,
	log = true,
	sh = true,
	py = true,
	c = true,
	h = true,
	cpp = true,
	hpp = true,
}

--- True when the file looks like a native executable: the bit is set, and the first
--- bytes are ELF. The magic check is what keeps shell scripts and generated cmake
--- helpers out of the list.
---@param path string
---@return boolean
local function is_executable_elf(path)
	local stat = vim.uv.fs_stat(path)
	if not stat or stat.type ~= "file" then
		return false
	end
	-- Owner-executable bit.
	if bit.band(stat.mode, 0x40) == 0 then
		return false
	end

	local fd = vim.uv.fs_open(path, "r", 438)
	if not fd then
		return false
	end
	local header = vim.uv.fs_read(fd, 18, 0)
	vim.uv.fs_close(fd)
	if not header or header:sub(1, 4) ~= "\127ELF" then
		return false
	end
	-- e_type, little-endian at offset 16: 1 is a relocatable object, never runnable.
	return header:byte(17) ~= 1
end

--- Executables under `root`, depth-limited so a large tree stays fast.
---@param root string
---@return string[]
function M.candidates(root)
	local found = {}

	---@param dir string
	---@param depth integer
	local function walk(dir, depth)
		if depth > 3 then
			return
		end
		local handle = vim.uv.fs_scandir(dir)
		if not handle then
			return
		end
		while true do
			local name, kind = vim.uv.fs_scandir_next(handle)
			if not name then
				break
			end
			local path = vim.fs.joinpath(dir, name)
			if kind == "directory" then
				if not SKIP[name] then
					walk(path, depth + 1)
				end
			elseif
				not NOT_BINARY[name:match("%.([%w]+)$") or ""]
				-- `libfoo.so.1.2.3`: the extension check only sees the last suffix.
				and not name:match("%.so[%.%d]*$")
				and is_executable_elf(path)
			then
				table.insert(found, path)
			end
		end
	end

	walk(root, 0)
	table.sort(found)
	return found
end

--- Runs the project's binary, asking which one the first time.
---@param root string
---@param opts? { reselect?: boolean } reselect ignores the remembered choice
---@param on_pick fun(path: string)
function M.select(root, opts, on_pick)
	opts = opts or {}

	local remembered = read()[root]
	if remembered and not opts.reselect and vim.uv.fs_stat(remembered) then
		on_pick(remembered)
		return
	end

	local found = M.candidates(root)
	if #found == 0 then
		Snacks.notify.warn("No executables found under " .. vim.fn.fnamemodify(root, ":~"), { title = "Run" })
		return
	end
	if #found == 1 and not opts.reselect then
		write(root, found[1])
		on_pick(found[1])
		return
	end

	vim.ui.select(found, {
		prompt = "Run which binary?",
		format_item = function(path)
			return vim.fs.relpath(root, path) or path
		end,
	}, function(choice)
		if choice then
			write(root, choice)
			on_pick(choice)
		end
	end)
end

return M
