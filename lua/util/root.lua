--- Project root detection via LSP workspace folders, file patterns, and cwd fallback.
--- Adapted from LazyVim's util/root.lua. Callable: `require("util.root")()` == `.get()`.
---@class util.root
---@overload fun(): string
local M = setmetatable({}, {
	__call = function(m, ...)
		return m.get(...)
	end,
})

---@class util.Root
---@field paths string[] Array of detected root paths
---@field spec util.RootSpec The spec that matched

---@alias util.RootFn fun(buf: number): (string|string[])

---@alias util.RootSpec string|string[]|util.RootFn

--- Default detection spec, tried in order; first match wins.
---@type util.RootSpec[]
M.spec = { "lsp", { ".git", "lua" }, "cwd" }

--- Detected root per buffer, cleared by setup()'s autocmds.
---@type table<number, string>
M.cache = {}

--- Detection strategies keyed by name; each takes a buffer and returns paths.
M.detectors = {}

----------------------------------------------------------------------------------
-- Detector Functions
----------------------------------------------------------------------------------

--- Fallback detector: the cwd, always succeeding, wrapped in a table.
---@return string[] paths
function M.detectors.cwd()
	return { vim.uv.cwd() }
end

--- Collects LSP root dirs (workspace folders + root_dir) that contain the buffer's file.
--- Skips clients named in vim.g.root_lsp_ignore.
---@param buf number
---@return string[] roots
function M.detectors.lsp(buf)
	local bufpath = M.bufpath(buf)
	if not bufpath then
		return {}
	end

	local roots = {} ---@type string[]

	local clients = vim.lsp.get_clients({ bufnr = buf })
	clients = vim.tbl_filter(function(client)
		return not vim.tbl_contains(vim.g.root_lsp_ignore or {}, client.name)
	end, clients) --[[@as vim.lsp.Client[] ]]

	for _, client in pairs(clients) do
		local workspace = client.config.workspace_folders
		for _, ws in pairs(workspace or {}) do
			roots[#roots + 1] = vim.uri_to_fname(ws.uri)
		end
		if client.root_dir then
			roots[#roots + 1] = client.root_dir
		end
	end

	return vim.tbl_filter(function(path)
		path = M.norm(path)
		return path and bufpath:find(path, 1, true) == 1
	end, roots)
end

--- Walks upward from the buffer's file for any pattern (exact or "*.ext" suffix),
--- returning the matched directory. Falls back to cwd for unnamed buffers.
---@param buf number
---@param patterns string|string[]
---@return string[] roots
function M.detectors.pattern(buf, patterns)
	patterns = type(patterns) == "string" and { patterns } or patterns
	local path = M.bufpath(buf) or vim.uv.cwd()

	local pattern = vim.fs.find(function(name)
		for _, p in ipairs(patterns) do
			if name == p then
				return true
			end
			if p:sub(1, 1) == "*" and name:find(vim.pesc(p:sub(2)) .. "$") then
				return true
			end
		end
		return false
	end, { path = path, upward = true })[1]

	return pattern and { vim.fs.dirname(pattern) } or {}
end

----------------------------------------------------------------------------------
-- Path Helper Functions
----------------------------------------------------------------------------------

--- Real (symlink-resolved) path of the buffer's file, or nil if unnamed.
---@param buf number
---@return string|nil path
function M.bufpath(buf)
	return M.realpath(vim.api.nvim_buf_get_name(assert(buf)))
end

--- Normalized cwd, or empty string on failure.
---@return string cwd
function M.cwd()
	return M.realpath(vim.uv.cwd()) or ""
end

--- Resolves a path to its canonical form; skips symlink resolution on Windows.
---@param path string|nil
---@return string|nil realpath nil if input was nil/empty
function M.realpath(path)
	if path == "" or path == nil then
		return nil
	end
	path = vim.fn.has("win32") == 0 and vim.uv.fs_realpath(path) or path
	return M.norm(path)
end

--- Normalizes a path via vim.fs.normalize (separators, . and .. components).
---@param path string|nil
---@return string|nil normalized
function M.norm(path)
	if path == nil then
		return nil
	end
	return vim.fs.normalize(path)
end

--- True when running on Windows.
---@return boolean is_win
function M.is_win()
	return vim.fn.has("win32") == 1
end

----------------------------------------------------------------------------------
-- Resolution Functions
----------------------------------------------------------------------------------

--- Resolves a spec (detector name, pattern list, or function) into a detector fn.
--- Unknown string specs fall through to pattern matching.
---@param spec util.RootSpec
---@return util.RootFn detector
function M.resolve(spec)
	if M.detectors[spec] then
		return M.detectors[spec]
	elseif type(spec) == "function" then
		return spec
	end
	return function(buf)
		return M.detectors.pattern(buf, spec)
	end
end

--- Runs each spec's detector, returning matches with deduped, longest-first paths.
--- Stops at the first match unless opts.all is true.
---@param opts? { buf?: number, spec?: util.RootSpec[], all?: boolean }
---@return util.Root[] roots
function M.detect(opts)
	opts = opts or {}
	-- vim.g.root_spec overrides M.spec (set in init.lua).
	opts.spec = opts.spec or type(vim.g.root_spec) == "table" and vim.g.root_spec or M.spec
	opts.buf = (opts.buf == nil or opts.buf == 0) and vim.api.nvim_get_current_buf() or opts.buf

	local ret = {} ---@type util.Root[]

	for _, spec in ipairs(opts.spec) do
		local paths = M.resolve(spec)(opts.buf)
		paths = paths or {}
		paths = type(paths) == "table" and paths or { paths }

		local roots = {} ---@type string[]
		for _, p in ipairs(paths) do
			local pp = M.realpath(p)
			if pp and not vim.tbl_contains(roots, pp) then
				roots[#roots + 1] = pp
			end
		end

		table.sort(roots, function(a, b)
			return #a > #b
		end)

		if #roots > 0 then
			ret[#ret + 1] = { spec = spec, paths = roots }
			if opts.all == false then
				break
			end
		end
	end

	return ret
end

----------------------------------------------------------------------------------
-- Main API Functions
----------------------------------------------------------------------------------

--- Main entry point: best-matching project root for a buffer, cached, cwd fallback.
---@param opts? { buf?: number, normalize?: boolean }
---@return string root
function M.get(opts)
	opts = opts or {}
	local buf = opts.buf or vim.api.nvim_get_current_buf()

	local ret = M.cache[buf]
	if not ret then
		local roots = M.detect({ all = false, buf = buf })
		ret = roots[1] and roots[1].paths[1] or vim.uv.cwd()
		M.cache[buf] = ret
	end

	if opts and opts.normalize then
		return ret
	end
	return M.is_win() and ret:gsub("/", "\\") or ret
end

--- Git repo root: nearest .git above the detected root, else the project root.
---@return string git_root
function M.git()
	local root = M.get()
	local git_root = vim.fs.find(".git", { path = root, upward = true })[1]
	local ret = git_root and vim.fn.fnamemodify(git_root, ":h") or root
	return ret
end

--- Notifies all detected roots ([x] = selected) and the active spec; returns the primary root.
---@return string root
function M.info()
	-- vim.g.root_spec overrides M.spec (set in init.lua).
	local spec = type(vim.g.root_spec) == "table" and vim.g.root_spec or M.spec

	local roots = M.detect({ all = true })
	local lines = {} ---@type string[]
	local first = true

	for _, root in ipairs(roots) do
		for _, path in ipairs(root.paths) do
			lines[#lines + 1] = ("- [%s] `%s` **(%s)**"):format(
				first and "x" or " ",
				path,
				type(root.spec) == "table" and table.concat(root.spec, ", ") or root.spec
			)
			first = false
		end
	end

	lines[#lines + 1] = "```lua"
	lines[#lines + 1] = "vim.g.root_spec = " .. vim.inspect(spec)
	lines[#lines + 1] = "```"

	vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Root Detection" })

	return roots[1] and roots[1].paths[1] or vim.uv.cwd()
end

--- One-time init: registers :RootInfo and cache-clearing autocmds.
--- BufEnter is included to handle neo-tree's set_root behavior.
function M.setup()
	vim.api.nvim_create_user_command("RootInfo", function()
		M.info()
	end, { desc = "Show root detection info for current buffer" })

	vim.api.nvim_create_autocmd({ "LspAttach", "BufWritePost", "DirChanged", "BufEnter" }, {
		group = vim.api.nvim_create_augroup("util_root_cache", { clear = true }),
		callback = function(event)
			M.cache[event.buf] = nil
		end,
	})
end

return M
