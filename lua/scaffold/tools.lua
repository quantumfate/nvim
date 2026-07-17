--- Single source of truth mapping each ecosystem to its tools. Every generated
--- artefact (justfile, flake, ansible playbook, .envrc, CI) derives from here, so a
--- new language is one row in `M.eco`.
---@class scaffold.tools
local M = {}

---@class scaffold.ToolSpec
---@field fmt? string[] Commands that reformat the tree in place
---@field fmt_check? string[] Commands that verify formatting without writing
---@field lint? string[] Static-analysis commands
---@field test? string[] Test commands
---@field build? string[] Build commands
---@field nix? string[] nixpkgs attribute names providing the above tools
---@field sys? string[] System (Arch/pacman) package names providing the same tools
---@field bin_paths? string[] Per-user tool bin dirs to add to PATH (shell-expandable), e.g. "$HOME/.cargo/bin"
---@field bootstrap? string[] User-level setup commands (install rocks/components), run by setup.sh and ansible

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
		bin_paths = { "$HOME/.luarocks/bin" },
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
		bin_paths = { "node_modules/.bin", "$HOME/.npm-global/bin" },
		bootstrap = { "[ -f package.json ] && npm install >/dev/null 2>&1 || true" },
	},
	rust = {
		fmt = { "cargo fmt" },
		fmt_check = { "cargo fmt --check" },
		lint = { "cargo clippy -- -D warnings" },
		test = { "cargo test" },
		build = { "cargo build" },
		nix = { "cargo", "rustc", "rustfmt", "clippy" },
		sys = { "rust" },
		bin_paths = { "$HOME/.cargo/bin" },
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
		bin_paths = { "$HOME/go/bin" },
		bootstrap = { "command -v go >/dev/null && go install golang.org/x/tools/gopls@latest >/dev/null 2>&1 || true" },
	},
	c = {
		fmt = { "git ls-files '*.c' '*.h' '*.cpp' '*.hpp' '*.cc' | xargs -r clang-format -i" },
		fmt_check = { "git ls-files '*.c' '*.h' '*.cpp' '*.hpp' '*.cc' | xargs -r clang-format --dry-run --Werror" },
		nix = { "clang-tools", "cmake" },
		sys = { "clang", "cmake" },
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
		lint = { "ansible-lint" },
		nix = { "ansible", "ansible-lint" },
		sys = { "ansible", "ansible-lint" },
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

--- Per-user tool bin dirs that must be on PATH for user-installed tools to resolve.
--- Consumed by .envrc and the ansible playbook.
---@param detection scaffold.Detection
---@return string[]
function M.bin_paths(detection)
	local out = {}
	for _, eco in ipairs(M.ordered()) do
		local spec = M.eco[eco]
		if detection.ecosystems[eco] and spec and spec.bin_paths then
			extend_unique(out, spec.bin_paths)
		end
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
