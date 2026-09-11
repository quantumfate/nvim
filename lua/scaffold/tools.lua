--- Per-ecosystem *project* wiring: how to format, lint, test and build a repo, and
--- which packages a devShell or playbook needs to do it. Every generated artefact
--- (justfile, flake, ansible playbook, .envrc, CI) derives from here, so a new
--- language is one row in `M.eco`.
---
--- Deliberately NOT the same table as lua/toolchain/registry.lua, which answers a
--- different question: the registry is this machine's editor toolchain (which LSP,
--- formatter and debug adapter to install and probe for, by Arch package name), while
--- this is a generated project's toolchain, in cross-distro and nix vocabulary. The
--- `bootstrap` fields read alike but are not: the registry installs `nlua` and
--- `bacon-ls` for nvim, this runs `npm install` in the project being scaffolded.
---
--- `bin_paths` is the one fact both need, and it is owned by the registry.
---@class scaffold.tools
local M = {}

---@class scaffold.ToolSpec
---@field extra? table<string, string[]> Named recipes beyond the standard four
---@field fmt? string[] Commands that reformat the tree in place
---@field fmt_check? string[] Commands that verify formatting without writing
---@field lint? string[] Static-analysis commands
---@field test? string[] Test commands
---@field build? string[] Build commands
---@field nix? string[] nixpkgs attribute names providing the above tools
---@field sys? string[] System (Arch/pacman) package names providing the same tools
---@field bin_paths? string[] Project-local bin dirs, e.g. "node_modules/.bin". Per-user
--- dirs like "$HOME/.cargo/bin" live in the toolchain registry and are merged in by M.bin_paths
---@field bootstrap? string[] Setup commands for the scaffolded project (npm install,
--- ansible-galaxy install), run by setup.sh and ansible. Not the registry's bootstrap,
--- which provisions this machine's editor tooling

--- Per-ecosystem toolchain. Commands stay non-interactive so they run from a task
--- runner or CI; `git ls-files` limits file-list tools to tracked files.
---@type table<string, scaffold.ToolSpec>
M.eco = {
	lua = {
		fmt = { "stylua ." },
		fmt_check = { "stylua --check ." },
		lint = { "luacheck ." },
		-- luacheck ships declaratively in nix; the sys path installs it via bootstrap.
		nix = { "stylua", "luajit", "lua-language-server", "luarocks", "luaPackages.luacheck" },
		sys = { "stylua", "lua-language-server", "luarocks" },
		bootstrap = { "command -v luarocks >/dev/null && luarocks install --local luacheck >/dev/null 2>&1 || true" },
	},
	python = {
		fmt = { "ruff format ." },
		fmt_check = { "ruff format --check ." },
		lint = { "ruff check ." },
		test = { "pytest" },
		nix = { "ruff", "python3" },
		sys = { "ruff", "python" },
		bin_paths = { "$HOME/.local/bin" },
	},
	node = {
		fmt = { "prettier --write ." },
		fmt_check = { "prettier --check ." },
		test = { "npm test" },
		build = { "npm run build" },
		nix = { "nodejs", "prettier" },
		sys = { "nodejs", "npm", "prettier" },
		-- Project-local; the registry owns the per-user dirs.
		bin_paths = { "node_modules/.bin", "$HOME/.npm-global/bin" },
		bootstrap = { "[ -f package.json ] && npm install >/dev/null 2>&1 || true" },
	},
	rust = {
		fmt = { "cargo fmt" },
		fmt_check = { "cargo fmt --check" },
		lint = { "cargo clippy --all-targets -- -D warnings" },
		test = { "cargo test" },
		build = { "cargo build" },
		nix = { "cargo", "rustc", "rustfmt", "clippy", "rust-analyzer" },
		sys = { "rust", "rust-analyzer" },
		bootstrap = { "command -v rustup >/dev/null && rustup component add rustfmt clippy >/dev/null 2>&1 || true" },
	},
	go = {
		fmt = { "gofmt -w ." },
		fmt_check = { '@test -z "$(gofmt -l .)" || (gofmt -l . && exit 1)' },
		lint = { "go vet ./..." },
		test = { "go test ./..." },
		build = { "go build ./..." },
		nix = { "go", "gopls" },
		sys = { "go", "gopls" },
		bootstrap = { "command -v go >/dev/null && go install golang.org/x/tools/gopls@latest >/dev/null 2>&1 || true" },
	},
	c = {
		fmt = { "git ls-files '*.c' '*.h' '*.cpp' '*.hpp' '*.cc' | xargs -r clang-format -i" },
		fmt_check = { "git ls-files '*.c' '*.h' '*.cpp' '*.hpp' '*.cc' | xargs -r clang-format --dry-run --Werror" },
		-- clang-tidy reads compile_commands.json, so `just compile-db` has to have run.
		lint = { "git ls-files '*.c' '*.cpp' '*.cc' | xargs -r clang-tidy --quiet" },
		-- By build system, the way compile-db decides: `make` in a cmake project fails
		-- with "no makefile found".
		build = {
			"@if [ -f CMakeLists.txt ]; then cmake -S . -B build && cmake --build build -j$(nproc); \\",
			"\telif [ -f meson.build ]; then [ -d build ] || meson setup build; meson compile -C build; \\",
			"\telse make -j$(nproc); fi",
		},
		test = {
			"@if [ -f CMakeLists.txt ]; then ctest --test-dir build --output-on-failure; \\",
			"\telif [ -f meson.build ]; then meson test -C build; \\",
			"\telse make test; fi",
		},
		nix = { "clang-tools", "cmake", "bear", "gdb" },
		sys = { "clang", "cmake", "bear", "gdb" },
		-- The editor reads compile_commands.json to preprocess and disassemble with the
		-- project's real flags. Without it, `<leader>ve` and `<leader>va` fall back to
		-- defaults and quietly show you a different program than the one that ships.
		extra = {
			["compile-db"] = {
				"@if [ -f CMakeLists.txt ]; then cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON && ln -sf build/compile_commands.json .; \\",
				"\telif [ -f meson.build ]; then { [ -d build ] && meson setup --reconfigure build || meson setup build; } && ln -sf build/compile_commands.json .; \\",
				"\telse bear -- make -B; fi",
			},
		},
	},

	zig = {
		fmt = { "zig fmt ." },
		fmt_check = { "zig fmt --check ." },
		-- `ast-check` is the parse-only gate; the compiler itself is the real linter.
		lint = { "git ls-files '*.zig' | xargs -r -n1 zig ast-check" },
		test = { "zig build test" },
		build = { "zig build" },
		nix = { "zig", "zls" },
		sys = { "zig", "zls" },
	},
	shell = {
		fmt = { "shfmt -w -i 4 ." },
		fmt_check = { "shfmt -d -i 4 ." },
		lint = { "git ls-files '*.sh' '*.bash' | xargs -r shellcheck" },
		nix = { "shfmt", "shellcheck" },
		sys = { "shfmt", "shellcheck" },
	},
	yaml = {
		lint = { "yamllint ." },
		nix = { "yamllint" },
		sys = { "yamllint" },
	},
	ansible = {
		-- --fix rewrites in place, so it is the formatter; the plain run is the check.
		fmt = { "ansible-lint --fix --offline" },
		lint = { "ansible-lint --offline" },
		-- Cheap structural gate: parses every play without touching a host.
		test = { "ansible-playbook --syntax-check playbook.yml" },
		nix = { "ansible", "ansible-lint" },
		sys = { "ansible", "ansible-lint" },
		bin_paths = { "$HOME/.local/bin" },
		bootstrap = { "[ -f requirements.yml ] && ansible-galaxy install -r requirements.yml >/dev/null 2>&1 || true" },
	},
	markdown = {
		fmt = { "prettier --write '**/*.md'" },
		fmt_check = { "prettier --check '**/*.md'" },
		nix = { "prettier" },
		sys = { "prettier" },
	},
	nix = {
		fmt = { "nixpkgs-fmt ." },
		fmt_check = { "nixpkgs-fmt --check ." },
		nix = { "nixpkgs-fmt" },
		sys = { "nixpkgs-fmt" },
	},
}

--- Packages every project gets, keyed by provisioner (nix attrs vs system names).
---@type table<"nix"|"sys", string[]>
M.base = {
	nix = { "git", "just", "pre-commit" },
	sys = { "git", "just", "pre-commit" },
}

--- Per-OS-family renames of the Arch `sys` names, since package names differ across
--- distros. Value: string (rename), string[] (expand), or false (drop).
---@type table<string, table<string, string|string[]|false>>
M.sys_alias = {
	Debian = { python = "python3", rust = { "rustc", "cargo" }, go = "golang", clang = "clang-format" },
	RedHat = { python = "python3", rust = { "rust", "cargo" }, go = "golang", clang = "clang-tools-extra" },
}

--- OS families the playbook carries name lists for; Archlinux is the alias-free base.
---@type string[]
M.sys_families = { "Archlinux", "Debian", "RedHat" }

--- Order-preserving append that skips duplicates, so generated files stay stable.
---@param list string[]
---@param items string[]
local function extend_unique(list, items)
	local seen = {}
	for _, v in ipairs(list) do
		seen[v] = true
	end
	for _, v in ipairs(items) do
		if not seen[v] then
			seen[v] = true
			table.insert(list, v)
		end
	end
end

--- Preferred order for the built-in ecosystems; unknown ones append alphabetically.
---@type string[]
local BASE_ORDER = { "lua", "python", "node", "rust", "go", "c", "shell", "yaml", "ansible", "markdown", "nix" }

--- Deterministic order over every ecosystem in M.eco. Every aggregator iterates this,
--- so a new M.eco row reaches all generators.
---@return string[]
function M.ordered()
	local out, seen = {}, {}
	for _, eco in ipairs(BASE_ORDER) do
		if M.eco[eco] then
			seen[eco] = true
			table.insert(out, eco)
		end
	end
	local extra = {}
	for eco in pairs(M.eco) do
		if not seen[eco] then
			table.insert(extra, eco)
		end
	end
	table.sort(extra)
	for _, eco in ipairs(extra) do
		table.insert(out, eco)
	end
	return out
end

--- Deduplicated commands for one action across every detected ecosystem.
---@param detection scaffold.Detection
---@param action "fmt"|"fmt_check"|"lint"|"test"|"build"
---@return string[]
function M.commands(detection, action)
	local out = {}
	for _, eco in ipairs(M.ordered()) do
		if detection.ecosystems[eco] then
			local spec = M.eco[eco]
			if spec and spec[action] then
				extend_unique(out, spec[action])
			end
		end
	end
	return out
end

--- Named recipes an ecosystem contributes beyond the standard four, as name -> lines.
---@param detection scaffold.Detection
---@return table<string, string[]>
function M.extras(detection)
	local out = {}
	for _, eco in ipairs(M.ordered()) do
		if detection.ecosystems[eco] then
			for name, cmds in pairs((M.eco[eco] or {}).extra or {}) do
				out[name] = cmds
			end
		end
	end
	return out
end

--- Per-user tool bin dirs that must be on PATH for user-installed tools to resolve.
--- Consumed by .envrc and the ansible playbook.
---@param detection scaffold.Detection
---@return string[]
function M.bin_paths(detection)
	local ecos = {}
	for _, eco in ipairs(M.ordered()) do
		if detection.ecosystems[eco] then
			table.insert(ecos, eco)
		end
	end

	-- The per-user install dirs ($HOME/.cargo/bin and friends) are the registry's;
	-- only the project-local ones below belong to a scaffolded repo.
	local out = require("toolchain.registry").bin_paths(ecos)
	for _, eco in ipairs(ecos) do
		extend_unique(out, (M.eco[eco] or {}).bin_paths or {})
	end
	return out
end

--- User-level bootstrap commands per detected ecosystem, labelled by eco for the
--- ansible playbook.
---@param detection scaffold.Detection
---@return { eco: string, cmds: string[] }[]
function M.bootstrap(detection)
	local out = {}
	for _, eco in ipairs(M.ordered()) do
		local spec = M.eco[eco]
		if detection.ecosystems[eco] and spec and spec.bootstrap and #spec.bootstrap > 0 then
			table.insert(out, { eco = eco, cmds = spec.bootstrap })
		end
	end
	return out
end

--- Deduplicated packages for every detected ecosystem plus the base, for one provisioner.
---@param detection scaffold.Detection
---@param kind "nix"|"sys" Which package-name set to collect
---@return string[]
function M.packages(detection, kind)
	local out = {}
	extend_unique(out, M.base[kind])
	for _, eco in ipairs(M.ordered()) do
		local spec = M.eco[eco]
		if detection.ecosystems[eco] and spec and spec[kind] then
			extend_unique(out, spec[kind])
		end
	end
	return out
end

--- System package names per OS family, applying M.sys_alias to the Arch base. Feeds
--- the playbook's per-family vars.
---@param detection scaffold.Detection
---@return table<string, string[]> by_family Package names keyed by OS family
function M.sys_packages_by_family(detection)
	local base = M.packages(detection, "sys")
	local out = {}
	for _, family in ipairs(M.sys_families) do
		local alias = M.sys_alias[family] or {}
		local list, seen = {}, {}
		for _, pkg in ipairs(base) do
			local repl = alias[pkg]
			local names
			if repl == nil then
				names = { pkg }
			elseif repl == false then
				names = {}
			elseif type(repl) == "table" then
				names = repl
			else
				names = { repl }
			end
			for _, name in ipairs(names) do
				if not seen[name] then
					seen[name] = true
					table.insert(list, name)
				end
			end
		end
		out[family] = list
	end
	return out
end

--- Executables the wiring will invoke, for the doctor's PATH check.
---@param detection scaffold.Detection
---@return string[]
function M.required_binaries(detection)
	local bins = { "just", "pre-commit" }
	local actions = { "fmt", "fmt_check", "lint", "test", "build" }
	local seen = { just = true, ["pre-commit"] = true }
	for _, action in ipairs(actions) do
		for _, cmd in ipairs(M.commands(detection, action)) do
			-- First bare word of the command, ignoring shell/pipe noise.
			local bin = cmd:match("^@?([%w._-]+)")
			if bin and not seen[bin] and bin ~= "git" and bin ~= "test" then
				seen[bin] = true
				table.insert(bins, bin)
			end
		end
	end
	return bins
end

return M
