--- Filesystem helpers: file/dir checks, recursive copy, path joining, and inspection.
---@class util.fs
local M = {}
local uv = vim.loop ---@type uv external: libuv event loop bindings

--- Pretty-prints a nested structure as `qvim.<path> = value` lines, depth-limited.
---@param structure any
---@param limit integer|nil Max recursion depth (default 100)
---@param separator string|nil Path separator for keys (default ".")
---@return integer remaining_limit
function M.r_inspect_settings(structure, limit, separator)
	limit = limit or 100
	separator = separator or "."
	if limit < 1 then
		print("ERROR: Item limit reached.")
		return limit - 1
	end
	if structure == nil then
		io.write("-- O", separator:sub(2), " = nil\n")
		return limit - 1
	end
	local ts = type(structure)

	if ts == "table" then
		for k, v in pairs(structure) do
			-- replace non alpha keys with ["key"]
			if tostring(k):match("[^%a_]") then
				k = '["' .. tostring(k) .. '"]'
			end
			limit = M.r_inspect_settings(v, limit, separator .. "." .. tostring(k))
			if limit < 0 then
				break
			end
		end
		return limit
	end

	if ts == "string" then
		-- escape sequences
		structure = string.format("%q", structure)
	end
	separator = separator:gsub("%.%[", "%[")
	if type(structure) == "function" then
		-- don't print functions
		io.write("-- qvim", separator:sub(2), " = function ()\n")
	else
		io.write("qvim", separator:sub(2), " = ", tostring(structure), "\n")
	end
	return limit - 1
end

--- True if the path exists and is a regular file.
---@param path string
---@return boolean is_file
function M.is_file(path)
	local stat = uv.fs_stat(path)
	return stat and stat.type == "file" or false
end

--- True if the path exists and is a directory.
---@param path string
---@return boolean is_directory
function M.is_directory(path)
	local stat = uv.fs_stat(path)
	return stat and stat.type == "directory" or false
end

--- Writes data to a file asynchronously; tables are serialized via vim.inspect.
---@param path string Full or cwd-relative path
---@param txt string|table
---@param flag string Access mode: "w" overwrite, "a" append
function M.write_file(path, txt, flag)
	local data = type(txt) == "string" and txt or vim.inspect(txt)
	uv.fs_open(path, flag, 438, function(open_err, fd)
		assert(not open_err, open_err)
		uv.fs_write(fd, data, -1, function(write_err)
			assert(not write_err, write_err)
			uv.fs_close(fd, function(close_err)
				assert(not close_err, close_err)
			end)
		end)
	end)
end

--- Joins path components with the platform separator (\ on Windows, / elsewhere).
---@param ... string
---@return string joined_path
function M.join_paths(...)
	local path_sep = uv.os_uname().version:match("Windows") and "\\" or "/"
	local result = table.concat({ ... }, path_sep)
	return result
end

--- Recursively copies a file or directory, preserving directory mode.
---@param source string
---@param destination string
function M.fs_copy(source, destination)
	local source_stats = assert(vim.loop.fs_stat(source))

	if source_stats.type == "file" then
		assert(vim.loop.fs_copyfile(source, destination))
		return
	elseif source_stats.type == "directory" then
		local handle = assert(vim.loop.fs_scandir(source))

		assert(vim.loop.fs_mkdir(destination, source_stats.mode))

		while true do
			local name = vim.loop.fs_scandir_next(handle)
			if not name then
				break
			end

			M.fs_copy(M.join_paths(source, name), M.join_paths(destination, name))
		end
	end
end

return M
