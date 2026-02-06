-- lua/util/root.lua
-- Project root directory detection utility.
--
-- This module provides functions to detect the root directory of a project
-- using multiple strategies: LSP workspace folders, file pattern matching,
-- and current working directory fallback.
--
-- Adapted from LazyVim's util/root.lua.

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

--- Default root detection specification.
--- Order matters: first match wins.
---@type util.RootSpec[]
M.spec = { "lsp", { ".git", "lua" }, "cwd" }

--- Cache of detected roots per buffer.
---@type table<number, string>
M.cache = {}

--- Detector functions for different root detection strategies.
M.detectors = {}

----------------------------------------------------------------------------------
-- Detector Functions
----------------------------------------------------------------------------------

--- Returns the current working directory as a root candidate.
---
--- This is a fallback detector that always succeeds. It returns the directory
--- where Neovim was started from, wrapped in a table for consistency with
--- other detectors.
---
---@return string[] paths A table containing the current working directory path
---
---@usage
--- local roots = M.detectors.cwd()
--- -- Returns: { "/home/user/projects" }
---
---@note This detector always returns a value and never fails.
---@note Useful as a last-resort fallback in the detection chain.
---@note Returns a table (not a string) for API consistency.
function M.detectors.cwd()
    return { vim.uv.cwd() }
end

--- Detects project roots using LSP workspace folders and root directories.
---
--- Queries all LSP clients attached to the buffer and collects root directories
--- from their workspace folders and root_dir configurations. Filters results
--- to only include paths that are parents of the current buffer's path.
---
---@param buf number The buffer number to check LSP clients for
---@return string[] roots LSP root directories filtered to paths containing the buffer's file
---
---@usage
--- local roots = M.detectors.lsp(vim.api.nvim_get_current_buf())
--- -- Returns: { "/home/user/project" } or {}
---
---@note Ignores LSP servers listed in vim.g.root_lsp_ignore (e.g., {"copilot"}).
---@note Checks both workspace_folders and root_dir from each client.
---@note Only returns roots that are parent directories of the buffer's path.
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

--- Detects project root by searching for specific files or directories.
---
--- Walks up the directory tree from the buffer's file location, looking for
--- any of the specified patterns. Supports exact matches and wildcard patterns
--- (e.g., "*.sln" matches any file ending in .sln).
---
---@param buf number The buffer number to start the search from
---@param patterns string|string[] Pattern(s) to search for (e.g., ".git", "Makefile", "*.sln")
---@return string[] roots A table containing the directory of the matched pattern, or empty table
---
---@usage
--- local roots = M.detectors.pattern(buf, { ".git", "Makefile" })
--- local roots = M.detectors.pattern(buf, "*.sln")
---
---@note Searches upward from the buffer's file location.
---@note Falls back to cwd if buffer has no associated file.
---@note Wildcards only support suffix matching (e.g., "*.ext").
---@note Returns the parent directory of the match, not the match itself.
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

--- Gets the real filesystem path of a buffer's file.
---
--- Retrieves the full path of the file associated with the given buffer
--- and resolves it to its real path (following symlinks).
---
---@param buf number The buffer number
---@return string|nil path The resolved real path, or nil if buffer has no file
---
---@note Returns nil for unnamed buffers or special buffer types.
---@note Resolves symlinks to get the canonical path.
function M.bufpath(buf)
    return M.realpath(vim.api.nvim_buf_get_name(assert(buf)))
end

--- Gets the normalized current working directory.
---
---@return string cwd The normalized current working directory, or empty string on failure
---
---@note Uses vim.uv.cwd() internally.
---@note Returns empty string (not nil) on failure for safety.
function M.cwd()
    return M.realpath(vim.uv.cwd()) or ""
end

--- Resolves a path to its canonical form.
---
--- Converts a path to its real filesystem path by resolving symlinks
--- and normalizing the format.
---
---@param path string|nil The path to resolve
---@return string|nil realpath The resolved real path, or nil if input was empty/nil
---
---@note Returns nil for empty strings or nil input.
---@note On Windows, skips symlink resolution (fs_realpath not reliable).
---@note Normalizes path separators and removes redundant components.
function M.realpath(path)
    if path == "" or path == nil then
        return nil
    end
    path = vim.fn.has("win32") == 0 and vim.uv.fs_realpath(path) or path
    return M.norm(path)
end

--- Normalizes a filesystem path.
---
--- Converts a path to a consistent format by resolving . and .. components,
--- normalizing separators, and removing trailing slashes.
---
---@param path string|nil The path to normalize
---@return string|nil normalized The normalized path, or nil if input was nil
---
---@note Uses vim.fs.normalize() internally.
---@note Handles both Unix and Windows path formats.
function M.norm(path)
    if path == nil then
        return nil
    end
    return vim.fs.normalize(path)
end

--- Checks if the current system is Windows.
---
---@return boolean is_win True if running on Windows, false otherwise
function M.is_win()
    return vim.fn.has("win32") == 1
end

----------------------------------------------------------------------------------
-- Resolution Functions
----------------------------------------------------------------------------------

--- Converts a root spec into a callable detector function.
---
--- Takes a spec entry (which can be a string detector name, a pattern list,
--- or a custom function) and returns a function that performs the detection.
---
---@param spec util.RootSpec The spec entry to resolve ("lsp", "cwd", patterns, or function)
---@return util.RootFn detector A function that takes a buffer number and returns root path(s)
---
---@usage
--- local detector = M.resolve("lsp")
--- local roots = detector(buf)
---
--- local detector = M.resolve({ ".git", "Makefile" })
--- local roots = detector(buf)
---
---@note Unknown string specs are treated as single-element pattern arrays.
---@note The returned function always takes (buf) and returns string[].
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

--- Detects all matching roots for a buffer using the configured spec.
---
--- Iterates through all specs in order, collecting roots from each detector.
--- Can return all matches or stop at the first successful detection.
---
---@param opts? { buf?: number, spec?: util.RootSpec[], all?: boolean } Options table
---@return util.Root[] roots Array of root objects with spec and paths fields
---
---@usage
--- -- Get all matching roots
--- local roots = M.detect({ all = true })
---
--- -- Get first matching root only
--- local roots = M.detect({ all = false, buf = 5 })
---
---@note Paths are deduplicated within each spec result.
---@note Paths are sorted by length (longest/most specific first).
---@note Empty results from detectors are skipped.
function M.detect(opts)
    opts = opts or {}
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

--- Gets the project root directory for a buffer.
---
--- This is the main entry point for root detection. Returns the best matching
--- root directory based on the configured detection spec. Results are cached
--- per buffer for performance.
---
---@param opts? { buf?: number, normalize?: boolean } Options table
---@return string root The detected project root directory, or cwd as fallback
---
---@usage
--- -- Get root for current buffer
--- local root = require("util.root").get()
---
--- -- Get root for specific buffer with normalized path
--- local root = require("util.root").get({ buf = 5, normalize = true })
---
--- -- Use callable syntax (equivalent to .get())
--- local root = require("util.root")()
---
---@note Results are cached per buffer for performance.
---@note Cache is cleared on LspAttach, BufWritePost, DirChanged, BufEnter.
---@note The first successful detection wins (based on spec order).
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

--- Gets the Git repository root for the current project.
---
--- Finds the nearest .git directory starting from the detected project root
--- and returns its parent directory (the actual repository root).
---
---@return string git_root The Git repository root, or project root if no .git found
---
---@usage
--- local git_root = require("util.root").git()
---
---@note Starts search from M.get() result, not from buffer path.
---@note Useful when project root and git root differ (e.g., monorepos).
function M.git()
    local root = M.get()
    local git_root = vim.fs.find(".git", { path = root, upward = true })[1]
    local ret = git_root and vim.fn.fnamemodify(git_root, ":h") or root
    return ret
end

--- Displays detailed information about root detection for current buffer.
---
--- Shows a notification with all detected roots from each spec, indicating
--- which one is currently selected. Useful for debugging root detection issues.
---
---@return string root The primary detected root path (same as M.get())
---
---@usage
--- :RootInfo
--- -- or
--- require("util.root").info()
---
---@note Shows [x] for the selected root, [ ] for alternatives.
---@note Displays the spec that matched each root.
---@note Shows the current vim.g.root_spec configuration.
function M.info()
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

--- Sets up the root detection module.
---
--- Creates autocommands to clear the cache when relevant events occur,
--- and creates a user command for displaying root info.
---
---@usage
--- -- In your config/init.lua
--- require("util.root").setup()
---
---@note Creates the :RootInfo command for debugging.
---@note Clears cache on: LspAttach, BufWritePost, DirChanged, BufEnter.
---@note BufEnter is included to handle neo-tree's set_root behavior.
---@note Should be called once during Neovim initialization.
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
