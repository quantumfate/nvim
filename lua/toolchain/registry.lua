--- Every external tool this config drives, grouped by ecosystem. Source of truth for
--- the ansible role's package list, the JSON store, `:checkhealth toolchain`, and —
--- via `M.by_ft` — conform's formatters_by_ft and nvim-lint's linters_by_ft. Wiring a
--- tool to a language is an `ft` field here, never an edit to a plugin spec.
---
--- Scope: this machine's editor toolchain, by Arch package name. A scaffolded
--- *project's* toolchain (justfile recipes, nix devShell, cross-distro packages) is
--- lua/scaffold/tools.lua, which is a different question, not a second copy of this.
---@class toolchain.registry
local M = {}

---@alias toolchain.Kind "lsp"|"fmt"|"lint"|"dap"|"tool"

---@class toolchain.Tool
---@field name string Name this config refers to the tool by (lspconfig server, conform/nvim-lint name)
---@field bin string Executable to look for on PATH
---@field path? string Absolute path to check instead of PATH, for tools that are not
---@field pkg? string Arch/AUR package providing it; defaults to `bin`. false when unpackaged
---@field version_args? string[]|false Argv that prints a version; defaults to
---@field optional? boolean Absence is not reported as missing
---@field alt? boolean This tool is an alternative to the others sharing its filetype,
--- not another stage. `{ prettierd, prettier }` is one formatter with a fallback and
--- only one should run; `{ ruff_organize_imports, ruff_format }` is a pipeline and
--- both must. Consumers that run every entry in a list (nvim-lint) take only the
--- first of an alt group; conform gets `stop_after_first` instead.
---@field ft? string[] Filetypes this tool serves. conform's formatters_by_ft and
--- nvim-lint's linters_by_ft are derived from these, so a formatter is wired to a
--- language by adding it here, not by editing the plugin spec. Order within an
--- ecosystem is preference order: conform runs the first one that is installed.

---@class toolchain.Eco
---@field sys? string[] Extra packages with no single binary (runtimes, headers, meta packages)
---@field lsp? toolchain.Tool[]
---@field fmt? toolchain.Tool[]
---@field lint? toolchain.Tool[]
---@field dap? toolchain.Tool[]
---@field tool? toolchain.Tool[] Editor-integration tools that are not one of the four kinds
---@field bin_paths? string[] Per-user bin dirs the tools land in, shell-expandable
---@field bootstrap? toolchain.Bootstrap[] Post-install steps the package manager cannot do
---@field update? toolchain.Step[] Upgrade form of the bootstrap steps, run by :ToolchainUpdate

---@class toolchain.Step
---@field name string Identifier used in logs and notifications
---@field cmd string Shell command; $HOME and $XDG_DATA_HOME are expanded

---@class toolchain.Bootstrap
---@field name string Identifier used in logs and failure notifications
---@field cmd string Shell command; must be idempotent, it runs on every provision
---@field creates? string Path whose existence means the step already ran, $HOME/$XDG_DATA_HOME allowed
---@field changed_if? string Substring of stdout that means the step actually did something.

--- Filetype groups shared by several tools, named so the lists below stay readable.
---@type string[]
local JS_FT = { "javascript", "typescript", "javascriptreact", "typescriptreact" }
---@type string[]
local ESLINT_FT = vim.list_extend(vim.deepcopy(JS_FT), { "vue", "svelte" })
---@type string[]
local PRETTIER_FT = vim.list_extend(vim.deepcopy(ESLINT_FT), {
	"json",
	"jsonc",
	"yaml",
	"markdown",
	"html",
	"css",
	"scss",
})

---@type toolchain.Kind[]
M.kinds = { "lsp", "fmt", "lint", "dap", "tool" }

---@class toolchain.VersionPair
---@field eco string Ecosystem both tools belong to
---@field tools string[] Registry tool names whose versions must agree
---@field level "major"|"minor" How many version components must match
---@field why string Shown by :checkhealth when they disagree

--- Tools that are only correct at a matching version. Nothing enforces this at
--- install time, so `:checkhealth toolchain` compares what the store probed.
---@type toolchain.VersionPair[]
M.version_pairs = {
	{
		eco = "zig",
		tools = { "zig", "zls" },
		level = "minor",
		why = "zls is built against one compiler release; a mismatch breaks parsing and completion",
	},
}

---@type table<string, toolchain.Eco>
M.eco = {
	core = {
		sys = { "neovim", "git", "base-devel", "tree-sitter-cli", "curl", "wget" },
		tool = {
			{ name = "ripgrep", bin = "rg", pkg = "ripgrep" },
			{ name = "fd", bin = "fd" },
			{ name = "fzf", bin = "fzf" },
			{ name = "lazygit", bin = "lazygit" },
			{ name = "chezmoi", bin = "chezmoi" },
			{ name = "tmux", bin = "tmux", version_args = { "-V" } },
			{ name = "wl-clipboard", bin = "wl-copy", pkg = "wl-clipboard" },
			{ name = "pre-commit", bin = "pre-commit" },
			{ name = "just", bin = "just" },
			{ name = "codespell", bin = "codespell" },
			{ name = "devpod", bin = "devpod-cli", pkg = "devpod-bin", optional = true, version_args = { "version" } },
		},
	},

	lua = {
		sys = { "lua51", "luarocks" },
		lsp = { { name = "lua_ls", bin = "lua-language-server", pkg = "lua-language-server" } },
		fmt = { { name = "stylua", bin = "stylua", ft = { "lua" } } },
		lint = { -- Run by the scaffolder and CI, not by nvim-lint: lua_ls already reports these.
			{ name = "luacheck", bin = "luacheck", pkg = false, optional = true, ft = {} },
		},
		dap = {
			-- nlua is a lua interpreter shim: --version opens it as a file.
			{ name = "nlua", bin = "nlua", pkg = false, version_args = false },
			{
				-- A node entry point rather than a binary: dap.lua runs it through node.
				name = "local-lua",
				bin = "node",
				path = "$XDG_DATA_HOME/nvim/dap/local-lua-debugger-vscode/extension/debugAdapter.js",
				pkg = false,
			},
		},
		bin_paths = { "$HOME/.luarocks/bin" },
		-- Upgrade form of the bootstrap steps, which are install-once.
		update = {
			{ name = "nlua", cmd = "luarocks install --local --lua-version 5.1 nlua" },
			{ name = "luacheck", cmd = "luarocks install --local --lua-version 5.1 luacheck" },
			{
				name = "local-lua-debugger",
				-- reset, not pull: the build writes into the checkout, so it is never clean.
				cmd = 'dst="$XDG_DATA_HOME/nvim/dap/local-lua-debugger-vscode" && '
					.. 'git -C "$dst" fetch --depth 1 origin HEAD && '
					.. 'git -C "$dst" reset --hard FETCH_HEAD && '
					.. 'npm --prefix "$dst" install && npm --prefix "$dst" run build',
			},
		},
		bootstrap = {
			{
				name = "luarocks-nlua",
				cmd = "luarocks install --local --lua-version 5.1 nlua",
				creates = "$HOME/.luarocks/bin/nlua",
			},
			{
				-- No distro package; dap.lua looks for the build in the data dir.
				name = "local-lua-debugger",
				cmd = 'dst="$XDG_DATA_HOME/nvim/dap/local-lua-debugger-vscode" && '
					.. 'git clone --depth 1 https://github.com/tomblind/local-lua-debugger-vscode "$dst" && '
					.. 'npm --prefix "$dst" install && npm --prefix "$dst" run build',
				creates = "$XDG_DATA_HOME/nvim/dap/local-lua-debugger-vscode/extension/debugAdapter.js",
			},
			{
				name = "luarocks-luacheck",
				cmd = "luarocks install --local --lua-version 5.1 luacheck",
				creates = "$HOME/.luarocks/bin/luacheck",
			},
		},
	},

	python = {
		sys = { "python", "uv" },
		lsp = {
			{ name = "basedpyright", bin = "basedpyright" },
			-- `ruff server` owns lint diagnostics and import fixes; basedpyright only types.
			{ name = "ruff", bin = "ruff" },
		},
		fmt = {
			{ name = "ruff_organize_imports", bin = "ruff", pkg = "ruff", ft = { "python" } },
			{ name = "ruff_format", bin = "ruff", pkg = "ruff", ft = { "python" } },
		},
		dap = { { name = "debugpy", bin = "python", pkg = "python-debugpy" } },
	},

	node = {
		sys = { "nodejs", "npm", "pnpm" },
		lsp = {
			{ name = "ts_ls", bin = "typescript-language-server", pkg = "typescript-language-server" },
			{ name = "svelte", bin = "svelteserver", pkg = "svelte-language-server" },
			{ name = "tailwindcss", bin = "tailwindcss-language-server", pkg = "tailwindcss-language-server" },
			{ name = "vue_ls", bin = "vue-language-server", pkg = "vue-language-server" },
			-- One package ships the html, css and eslint servers.
			{ name = "html", bin = "vscode-html-language-server", pkg = "vscode-langservers-extracted" },
			{ name = "cssls", bin = "vscode-css-language-server", pkg = "vscode-langservers-extracted" },
		},
		fmt = {
			-- deno_fmt first: conform takes the first formatter that is installed, and
			-- this one is gated on a deno.json in the project root (see conform.lua), so
			-- it only wins inside a deno project and falls through everywhere else.
			{ name = "deno_fmt", alt = true, bin = "deno", pkg = "deno", ft = JS_FT },
			{ name = "prettierd", alt = true, bin = "prettierd", ft = PRETTIER_FT },
			{ name = "prettier", alt = true, bin = "prettier", ft = PRETTIER_FT },
		},
		lint = {
			{ name = "eslint_d", alt = true, bin = "eslint_d", ft = ESLINT_FT },
			{ name = "eslint", alt = true, bin = "eslint", ft = ESLINT_FT },
		},
		-- Probing this one creates a socket named after the argument.
		dap = {
			{ name = "js-debug", bin = "js-debug-dap", pkg = "vscode-js-debug-bin", version_args = false },
		},
	},

	rust = {
		sys = { "rustup" },
		lsp = {
			{ name = "rust_analyzer", bin = "rust-analyzer", pkg = "rust-analyzer" },
			{ name = "bacon_ls", bin = "bacon-ls", pkg = false },
		},
		fmt = { { name = "rustfmt", bin = "rustfmt", pkg = false, ft = { "rust" } } },
		lint = {
			{ name = "clippy", bin = "cargo-clippy", pkg = false },
			{ name = "bacon", bin = "bacon" },
		},
		-- codelldb has no version flag; the store falls back to the package version.
		dap = { { name = "codelldb", bin = "codelldb", pkg = "codelldb-bin", version_args = false } },
		bin_paths = { "$HOME/.cargo/bin" },
		update = {
			{ name = "rustup", cmd = "rustup update" },
			{ name = "bacon-ls", cmd = "cargo install --locked --force bacon-ls" },
		},
		bootstrap = {
			{
				name = "rustup-toolchain",
				cmd = "rustup show active-toolchain >/dev/null 2>&1 || rustup default stable",
				changed_if = "default toolchain set",
			},
			{
				name = "rustup-components",
				cmd = "rustup component add rustfmt clippy",
				changed_if = "installing component",
			},
			{ name = "cargo-bacon-ls", cmd = "cargo install --locked bacon-ls", creates = "$HOME/.cargo/bin/bacon-ls" },
		},
	},

	go = {
		sys = { "go" },
		lsp = { { name = "gopls", bin = "gopls" } },
		fmt = {
			{ name = "goimports", bin = "goimports", pkg = "go-tools", ft = { "go" } },
			{ name = "gofmt", bin = "gofmt", pkg = "go", ft = { "go" } },
		},
		dap = { { name = "delve", bin = "dlv", pkg = "delve" } },
		bin_paths = { "$HOME/go/bin" },
	},

	c = {
		lsp = { { name = "clangd", bin = "clangd", pkg = "clang" } },
		fmt = { { name = "clang_format", bin = "clang-format", pkg = "clang", ft = { "c", "cpp", "objc", "cuda" } } },
		-- clang-tidy is run by the scaffolder's `just lint`, not by nvim-lint: clangd
		-- already runs it with --clang-tidy, and a second pass would double every
		-- finding.
		lint = { { name = "clang_tidy", bin = "clang-tidy", pkg = "clang", ft = {} } },
		tool = {
			-- Generates compile_commands.json for projects with no cmake or meson, which
			-- is what makes the C language actions read the project's real flags. A
			-- kernel tree has its own `make compile_commands.json`, so this is optional.
			{ name = "bear", bin = "bear" },
			-- meson emits compile_commands.json itself, and `just compile-db` prefers it
			-- over bear when the project uses it.
			{ name = "meson", bin = "meson", optional = true },
			{ name = "ninja", bin = "ninja", optional = true },
			-- Reading a core dump without it gets symbol names and no source lines.
			{ name = "gdb", bin = "gdb" },
			-- Kernel oops decoding: symbol table plus offset to a file and line.
			{ name = "addr2line", bin = "addr2line", pkg = "binutils" },
		},
	},

	shell = {
		lsp = { { name = "bashls", bin = "bash-language-server", pkg = "bash-language-server" } },
		fmt = {
			{ name = "shfmt", bin = "shfmt", ft = { "sh", "bash" } },
			{ name = "fish_indent", bin = "fish_indent", pkg = "fish", ft = { "fish" } },
		},
		lint = { { name = "shellcheck", bin = "shellcheck", ft = {} } },
	},

	zig = {
		sys = { "zig" },
		-- `zig --version` is not a thing; the subcommand is bare.
		tool = { { name = "zig", bin = "zig", version_args = { "version" } } },
		-- The repo `zls` lags the compiler; zls-bin tracks the tagged release. Its
		-- major.minor must equal `zig version` — see M.version_pairs.
		lsp = { { name = "zls", bin = "zls", pkg = "zls-bin" } },
		fmt = { -- .zon files carry filetype "zig" but a different grammar; conform.lua picks
			-- between zigfmt and zonfmt by extension, so neither declares an ft here.
			{ name = "zigfmt", bin = "zig", pkg = "zig", version_args = { "version" }, ft = {} },
		},
		-- codelldb debugs any ELF binary; zig projects need it as much as rust ones.
		dap = { { name = "codelldb", bin = "codelldb", pkg = "codelldb-bin", version_args = false } },
	},

	json = {
		-- Same package as the html/css servers; it owns the json binary too.
		lsp = { { name = "jsonls", bin = "vscode-json-language-server", pkg = "vscode-langservers-extracted" } },
	},

	toml = {
		lsp = { { name = "taplo", bin = "taplo", pkg = "taplo-cli" } },
		fmt = { { name = "taplo", bin = "taplo", pkg = "taplo-cli", ft = { "toml" } } },
	},

	yaml = {
		lsp = { { name = "yamlls", bin = "yaml-language-server", pkg = "yaml-language-server" } },
		lint = { { name = "yamllint", bin = "yamllint", ft = { "yaml" } } },
	},

	ansible = {
		sys = { "ansible" },
		lsp = { { name = "ansiblels", bin = "ansible-language-server", pkg = "ansible-language-server" } },
		fmt = { { name = "prettierd", alt = true, bin = "prettierd", ft = { "yaml.ansible" } } },
		lint = { { name = "ansible_lint", bin = "ansible-lint", pkg = "ansible-lint", ft = { "yaml.ansible" } } },
	},

	markdown = {
		lsp = { { name = "marksman", bin = "marksman" } },
		lint = { { name = "markdownlint", bin = "markdownlint", pkg = "markdownlint-cli", ft = { "markdown" } } },
	},

	docker = {
		lsp = { { name = "dockerls", bin = "docker-langserver", pkg = "dockerfile-language-server" } },
		lint = { { name = "hadolint", bin = "hadolint", pkg = "hadolint-bin", ft = { "dockerfile" } } },
	},

	qml = {
		lsp = { { name = "qmlls", bin = "qmlls6", pkg = "qt6-tools" } },
	},
}

---@type string[]
local BASE_ORDER = {
	"core",
	"lua",
	"python",
	"node",
	"rust",
	"go",
	"c",
	"shell",
	"zig",
	"json",
	"toml",
	"yaml",
	"ansible",
	"markdown",
	"docker",
	"qml",
}

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
	vim.list_extend(out, extra)
	return out
end

---@param eco_name? string Restrict to one ecosystem
---@return { eco: string, kind: toolchain.Kind, tool: toolchain.Tool }[]
function M.tools(eco_name)
	local out = {}
	for _, eco in ipairs(eco_name and { eco_name } or M.ordered()) do
		for _, kind in ipairs(M.kinds) do
			for _, tool in ipairs(M.eco[eco][kind] or {}) do
				table.insert(out, { eco = eco, kind = kind, tool = tool })
			end
		end
	end
	return out
end

---@param eco_names? string[] Defaults to every ecosystem
---@return { eco: string, step: toolchain.Step }[]
function M.update_steps(eco_names)
	local out = {}
	for _, eco_name in ipairs(eco_names or M.ordered()) do
		for _, step in ipairs((M.eco[eco_name] or {}).update or {}) do
			table.insert(out, { eco = eco_name, step = step })
		end
	end
	return out
end

---@return string[]
function M.updatable()
	local out = {}
	for _, eco_name in ipairs(M.ordered()) do
		if (M.eco[eco_name].update or {})[1] then
			table.insert(out, eco_name)
		end
	end
	return out
end

---@param tool toolchain.Tool
---@return string?
function M.package_of(tool)
	if tool.pkg == false then
		return nil
	end
	return tool.pkg or tool.bin
end

--- Filetype -> tool names of one kind, in registry order.
---
--- This is what makes the registry the single source of truth rather than a second
--- copy of one: conform's `formatters_by_ft` and nvim-lint's `linters_by_ft` are
--- built from it, so wiring a formatter to a language is one `ft` field here and
--- nothing in the plugin spec. Order is preference order — conform runs the first
--- entry that is actually installed.
---@param kind toolchain.Kind
---@param opts? { first_alt_only?: boolean } Keep only the first tool of each alt
--- group, for consumers that run every entry in a list rather than the first that works
---@return table<string, string[]>
function M.by_ft(kind, opts)
	local first_alt_only = opts and opts.first_alt_only
	local out, seen_alt = {}, {}
	for _, entry in ipairs(M.tools()) do
		local tool = entry.tool
		if entry.kind == kind then
			for _, ft in ipairs(tool.ft or {}) do
				local skip = first_alt_only and tool.alt and seen_alt[ft]
				if not skip then
					out[ft] = out[ft] or {}
					table.insert(out[ft], tool.name)
					seen_alt[ft] = seen_alt[ft] or tool.alt
				end
			end
		end
	end
	return out
end

--- Filetypes whose tools of this kind are alternatives rather than pipeline stages.
---@param kind toolchain.Kind
---@return table<string, boolean>
function M.alt_fts(kind)
	local out = {}
	for _, entry in ipairs(M.tools()) do
		if entry.kind == kind and entry.tool.alt then
			for _, ft in ipairs(entry.tool.ft or {}) do
				out[ft] = true
			end
		end
	end
	return out
end

--- Every registered tool name of one kind.
---@param kind toolchain.Kind
---@return string[]
function M.names(kind)
	local out = {}
	for _, entry in ipairs(M.tools()) do
		if entry.kind == kind then
			table.insert(out, entry.tool.name)
		end
	end
	return out
end

--- Per-user bin directories the listed ecosystems install into, shell-expandable.
---@param eco_names? string[] Defaults to every ecosystem
---@return string[]
function M.bin_paths(eco_names)
	local out, seen = {}, {}
	for _, eco_name in ipairs(eco_names or M.ordered()) do
		for _, path in ipairs((M.eco[eco_name] or {}).bin_paths or {}) do
			if not seen[path] then
				seen[path] = true
				table.insert(out, path)
			end
		end
	end
	return out
end

--- Post-install steps the package manager cannot do, for the listed ecosystems.
---@param eco_names? string[] Defaults to every ecosystem
---@return { eco: string, step: toolchain.Bootstrap }[]
function M.bootstrap_steps(eco_names)
	local out = {}
	for _, eco_name in ipairs(eco_names or M.ordered()) do
		for _, step in ipairs((M.eco[eco_name] or {}).bootstrap or {}) do
			table.insert(out, { eco = eco_name, step = step })
		end
	end
	return out
end

---@param eco_name string
---@return string[]
function M.packages_of(eco_name)
	local out, seen = {}, {}
	local function add(pkg)
		if pkg and not seen[pkg] then
			seen[pkg] = true
			table.insert(out, pkg)
		end
	end
	for _, pkg in ipairs(M.eco[eco_name].sys or {}) do
		add(pkg)
	end
	for _, entry in ipairs(M.tools(eco_name)) do
		add(M.package_of(entry.tool))
	end
	return out
end

return M
