--- Rust: rustaceanvim's `:RustLsp` subcommands and cargo, on the shared keys.
---
--- rust-analyzer answers most of these better than a CLI could, because it already has
--- the crate graph loaded. The exceptions are assembly and the build loop, which need
--- an actual compile.
---@class lang.rust
local M = {}

--- Titles this adapter renders under, so the keymap can ask whether a view is
--- already on screen. Declared beside the code that uses them: a central table
--- drifts the moment an adapter gains a capability.
---@type table<string, string>
M.titles = {
	assembly = "rust asm",
}

local output = require("features.lang.output")
local root = require("lib.root")

--- Cargo workspace root, or the buffer's own root for a standalone file.
---@param buf integer
---@return string
local function crate(buf)
	return root.detectors.pattern(buf, "Cargo.toml")[1] or root.get({ buf = buf })
end

--- The cargo target a file belongs to. `cargo rustc` refuses extra rustc flags when a
--- package has more than one target ("can only be passed to one target"), so a crate
--- with both lib.rs and main.rs needs to be told which.
---@param buf integer
---@return string[]
function M.target_args(buf)
	local dir = crate(buf)
	local rel = vim.fs.relpath(dir, vim.api.nvim_buf_get_name(buf)) or ""
	local bin = rel:match("^src/bin/([^/]+)%.rs$") or rel:match("^src/bin/([^/]+)/main%.rs$")
	if bin then
		return { "--bin", bin }
	end
	local example = rel:match("^examples/([^/]+)%.rs$") or rel:match("^examples/([^/]+)/main%.rs$")
	if example then
		return { "--example", example }
	end
	local test = rel:match("^tests/([^/]+)%.rs$")
	if test then
		return { "--test", test }
	end
	local has_lib = vim.uv.fs_stat(vim.fs.joinpath(dir, "src", "lib.rs")) ~= nil
	local has_main = vim.uv.fs_stat(vim.fs.joinpath(dir, "src", "main.rs")) ~= nil
	if rel == "src/main.rs" or (has_main and not has_lib) then
		local ok, manifest = pcall(vim.fn.readfile, vim.fs.joinpath(dir, "Cargo.toml"))
		for _, line in ipairs(ok and manifest or {}) do
			local name = line:match('^%s*name%s*=%s*"([^"]+)"')
			if name then
				return { "--bin", name }
			end
		end
		return {}
	end
	return has_lib and { "--lib" } or {}
end

--- Runs a `:RustLsp` subcommand, which is how rustaceanvim exposes rust-analyzer's
--- own extensions.
---@param sub string
---@return fun(buf: integer)
local function rustlsp(sub)
	return function()
		vim.cmd.RustLsp(sub)
	end
end

---@param buf integer
function M.build(buf)
	output.terminal({ "cargo", "build" }, crate(buf), { title = "cargo build" })
end

--- Runnables, not `cargo run`: a workspace has several binaries and examples, and
--- rust-analyzer knows which one the cursor is in.
M.run = rustlsp("runnables")

--- rustaceanvim remembers the last runnable, so this is the same command; the menu it
--- opens is the "choose a different one" affordance.
M.run_other = rustlsp("runnables")

---@param buf integer
function M.test(buf)
	output.terminal({ "cargo", "test" }, crate(buf), { title = "cargo test" })
end

--- `cargo check` skips codegen, which is the whole point of a fast check.
---@param buf integer
function M.check(buf)
	output.terminal({ "cargo", "check", "--all-targets" }, crate(buf), { title = "cargo check" })
end

M.build_file = rustlsp("openCargo")
M.reload = rustlsp("reloadWorkspace")
M.expand = rustlsp("expandMacro")
M.tree = rustlsp("syntaxTree")

--- The enclosing module, which is Rust's answer to "the file this belongs to".
M.related = rustlsp("parentModule")

--- MIR, straight from rustaceanvim. HIR and the rest are behind the same command's
--- prompt, so this lands on the menu rather than picking one.
M.ir = rustlsp("view_ir")

--- Assembly for the current crate.
---
--- `cargo rustc -- --emit asm` rather than a raw `rustc`: the file almost certainly
--- depends on its crate, and only cargo knows the dependency paths and feature flags.
--- Release mode, because debug assembly is mostly stack traffic and tells you very
--- little about what the optimiser did.
---@param buf integer
function M.assembly(buf)
	if not output.require_exe("cargo") then
		return
	end
	local asm = output.tempfile(".s")
	local cmd = vim.list_extend({ "cargo", "rustc" }, M.target_args(buf))
	vim.list_extend(cmd, {
		"--release",
		"-q",
		"--",
		"--emit",
		"asm=" .. asm,
		"-C",
		"llvm-args=-x86-asm-syntax=intel",
		-- `.loc` markers for the cursor link; the profile already sets debug = true
		-- in the playground, but a crate that does not still gets them here.
		"-C",
		"debuginfo=1",
	})
	output.run({
		cmd = cmd,
		title = M.titles.assembly,
		filetype = "asm",
		cwd = crate(buf),
		artifact = asm,
		-- The crate's asm carries core's and alloc's `.loc`s too; only this file's lines link.
		on_lines = function(lines)
			return output.strip_asm(lines, vim.api.nvim_buf_get_name(buf), { only_source_functions = true })
		end,
	})
end

---@param buf integer
function M.symbol(buf)
	vim.cmd.RustLsp({ "hover", "actions" })
end

return M
