local M = {}
local uv = vim.loop

---Recursively print a structure pretty formatted with a separator
---@param structure any the structure to be recursed
---@param limit any the maximum depth for the recursion
---@param separator any the string to pretty format the structure
---@return integer|unknown limit limit - 1
function M.r_inspect_settings(structure, limit, separator)
    limit = limit or 100         -- default item limit
    separator = separator or "." -- indent string
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
            limit =
                M.r_inspect_settings(v, limit, separator .. "." .. tostring(k))
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

--- Checks whether a given path exists and is a file.
--@param path (string) path to check
--@returns (bool)
function M.is_file(path)
    local stat = uv.fs_stat(path)
    return stat and stat.type == "file" or false
end

--- Checks whether a given path exists and is a directory
--@param path (string) path to check
--@returns (bool)
function M.is_directory(path)
    local stat = uv.fs_stat(path)
    return stat and stat.type == "directory" or false
end

---Write data to a file
---@param path string can be full or relative to `cwd`
---@param txt string|table text to be written, uses `vim.inspect` internally for tables
---@param flag string used to determine access mode, common flags: "w" for `overwrite` or "a" for `append`
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

function M.join_paths(...)
    local path_sep = uv.os_uname().version:match("Windows") and "\\" or "/"
    local result = table.concat({ ... }, path_sep)
    return result
end

---Copies a file or directory recursively
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

            M.fs_copy(
                M.join_paths(source, name),
                M.join_paths(destination, name)
            )
        end
    end
end

--- Get the root directory of the current project
--- Looks for .git, then falls back to LSP root, then cwd
---@return string
function M.get_root()
    local path = vim.api.nvim_buf_get_name(0)
    if path == "" then
        return vim.fn.getcwd()
    end

    -- Try to find .git directory
    local root = vim.fs.find({ ".git", "Makefile", "package.json", "Cargo.toml", "go.mod" }, {
        path = path,
        upward = true,
    })[1]

    if root then
        return vim.fn.fnamemodify(root, ":h")
    end

    -- Try LSP root
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    for _, client in ipairs(clients) do
        if client.config.root_dir then
            return client.config.root_dir
        end
    end

    -- Fallback to cwd
    return vim.fn.getcwd()
end

return M
