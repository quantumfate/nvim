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
	output.run({
		cmd = {
			"cargo",
			"rustc",
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
		},
		title = M.titles.assembly,
		filetype = "asm",
		cwd = crate(buf),
		artifact = asm,
		on_lines = output.strip_asm,
	})
end

---@param buf integer
function M.symbol(buf)
	vim.cmd.RustLsp({ "hover", "actions" })
end

return M
