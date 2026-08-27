--- Single source of truth for the external toolchain: every LSP server, formatter,
--- linter and debug adapter this config drives, grouped by ecosystem the same way
--- `scaffold.tools` groups project tooling. Everything downstream derives from here —
--- the ansible role's package list (`toolchain.export`), the JSON store quickshell
--- reads (`toolchain.store`), and `:checkhealth`.
---
--- Nothing installs tools from inside neovim: the ansible role owns installation via
--- pacman/AUR, this table owns the data model, and the store reports what is actually
--- on PATH. Adding a language is one row here.
---@class toolchain.registry
local M = {}

---@alias toolchain.Kind "lsp"|"fmt"|"lint"|"dap"|"tool"

---@class toolchain.Tool
---@field name string Name this config refers to the tool by (lspconfig server, conform/nvim-lint name)
---@field bin string Executable to look for on PATH
---@field path? string Absolute path to check instead of PATH, for tools that are not
--- executables — a node entry point, a shared library. $HOME/$XDG_DATA_HOME allowed
---@field pkg? string Arch/AUR package providing it; defaults to `bin`. false when unpackaged
---@field version_args? string[] Argv that prints a version; defaults to { "--version" }
---@field optional? boolean Absence is not reported as missing

---@class toolchain.Eco
---@field sys? string[] Extra packages with no single binary (runtimes, headers, meta packages)
---@field lsp? toolchain.Tool[]
---@field fmt? toolchain.Tool[]
---@field lint? toolchain.Tool[]
---@field dap? toolchain.Tool[]
---@field tool? toolchain.Tool[] Editor-integration tools that are not one of the four kinds
---@field bin_paths? string[] Per-user bin dirs the tools land in, shell-expandable
---@field bootstrap? toolchain.Bootstrap[] Post-install steps the package manager cannot do

---@class toolchain.Bootstrap
---@field name string Identifier used in logs and failure notifications
---@field cmd string Shell command; must be idempotent, it runs on every provision
---@field creates? string Path whose existence means the step already ran, $HOME/$XDG_DATA_HOME allowed
---@field changed_if? string Substring of stdout that means the step actually did something.
--- Steps with neither `creates` nor `changed_if` always report as changed

--- Kinds in the order they are reported.
---@type toolchain.Kind[]
M.kinds = { "lsp", "fmt", "lint", "dap", "tool" }

--- Per-ecosystem toolchain. `pkg` is an Arch repo or AUR package name — both install
--- through yay in one transaction, so they are not distinguished here.
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
			{ name = "tmux", bin = "tmux" },
			{ name = "wl-clipboard", bin = "wl-copy", pkg = "wl-clipboard" },
			{ name = "pre-commit", bin = "pre-commit" },
			{ name = "just", bin = "just" },
			{ name = "codespell", bin = "codespell" },
			{ name = "devpod", bin = "devpod-cli", pkg = "devpod-bin", optional = true },
		},
	},

	lua = {
		sys = { "lua51", "luarocks" },
		lsp = { { name = "lua_ls", bin = "lua-language-server", pkg = "lua-language-server" } },
		fmt = { { name = "stylua", bin = "stylua" } },
		lint = { { name = "luacheck", bin = "luacheck", pkg = false, optional = true } },
		dap = {
			{ name = "nlua", bin = "nlua", pkg = false },
			{
				-- A node entry point rather than a binary: dap.lua runs it through node.
				name = "local-lua",
				bin = "node",
				path = "$XDG_DATA_HOME/nvim/dap/local-lua-debugger-vscode/extension/debugAdapter.js",
				pkg = false,
			},
		},
		bin_paths = { "$HOME/.luarocks/bin" },
		bootstrap = {
			{
				name = "luarocks-nlua",
				cmd = "luarocks install --local --lua-version 5.1 nlua",
				creates = "$HOME/.luarocks/bin/nlua",
			},
			{
				-- No distro package: the extension is built from source into the data dir,
				-- where dap.lua looks for it.
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
		lsp = { { name = "basedpyright", bin = "basedpyright" } },
		fmt = {
			{ name = "ruff_format", bin = "ruff", pkg = "ruff" },
			{ name = "black", bin = "black", pkg = "python-black" },
		},
		lint = { { name = "ruff", bin = "ruff" } },
		dap = { { name = "debugpy", bin = "python", pkg = "python-debugpy" } },
	},

	node = {
		sys = { "nodejs", "npm", "pnpm" },
		lsp = {
			{ name = "ts_ls", bin = "typescript-language-server", pkg = "typescript-language-server" },
			{ name = "svelte", bin = "svelteserver", pkg = "svelte-language-server" },
			{ name = "tailwindcss", bin = "tailwindcss-language-server", pkg = "tailwindcss-language-server" },
			{ name = "vuels", bin = "vue-language-server", pkg = "vue-language-server" },
		},
		fmt = {
			{ name = "prettierd", bin = "prettierd" },
			{ name = "prettier", bin = "prettier" },
			{ name = "deno_fmt", bin = "deno", pkg = "deno" },
		},
		lint = {
			{ name = "eslint_d", bin = "eslint_d" },
			{ name = "eslint", bin = "eslint" },
		},
		dap = { { name = "js-debug", bin = "js-debug-dap", pkg = "vscode-js-debug-bin" } },
	},

	rust = {
		sys = { "rustup" },
		lsp = {
			{ name = "rust_analyzer", bin = "rust-analyzer", pkg = "rust-analyzer" },
			{ name = "bacon_ls", bin = "bacon-ls", pkg = false },
		},
		fmt = { { name = "rustfmt", bin = "rustfmt", pkg = false } },
		lint = {
			{ name = "clippy", bin = "cargo-clippy", pkg = false },
			{ name = "bacon", bin = "bacon" },
		},
		dap = { { name = "codelldb", bin = "codelldb", pkg = "codelldb-bin" } },
		bin_paths = { "$HOME/.cargo/bin" },
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
			{ name = "gofmt", bin = "gofmt", pkg = "go" },
			{ name = "goimports", bin = "goimports", pkg = "go-tools" },
		},
		dap = { { name = "delve", bin = "dlv", pkg = "delve" } },
		bin_paths = { "$HOME/go/bin" },
	},

	c = {
		lsp = { { name = "clangd", bin = "clangd", pkg = "clang" } },
		fmt = { { name = "clang_format", bin = "clang-format", pkg = "clang" } },
		lint = { { name = "cpplint", bin = "cpplint", pkg = "python-cpplint" } },
	},

	shell = {
		lsp = { { name = "bashls", bin = "bash-language-server", pkg = "bash-language-server" } },
		fmt = {
			{ name = "shfmt", bin = "shfmt" },
			{ name = "fish_indent", bin = "fish_indent", pkg = "fish" },
		},
		lint = { { name = "shellcheck", bin = "shellcheck" } },
	},

	zig = {
		lsp = { { name = "zls", bin = "zls" } },
		fmt = { { name = "zigfmt", bin = "zig", pkg = "zig" } },
	},

	json = {
		lsp = { { name = "jsonls", bin = "vscode-json-language-server", pkg = "vscode-json-languageserver" } },
	},

	toml = {
		lsp = { { name = "taplo", bin = "taplo", pkg = "taplo-cli" } },
	},

	yaml = {
		lsp = { { name = "yamlls", bin = "yaml-language-server", pkg = "yaml-language-server" } },
		lint = { { name = "yamllint", bin = "yamllint" } },
	},

	ansible = {
		sys = { "ansible" },
		lsp = { { name = "ansiblels", bin = "ansible-language-server", pkg = "ansible-language-server" } },
		lint = { { name = "ansible_lint", bin = "ansible-lint", pkg = "ansible-lint" } },
	},

	markdown = {
		lsp = { { name = "marksman", bin = "marksman" } },
		lint = { { name = "markdownlint", bin = "markdownlint", pkg = "markdownlint-cli" } },
	},

	docker = {
		lint = { { name = "hadolint", bin = "hadolint", pkg = "hadolint-bin" } },
	},

	qml = {
		lsp = { { name = "qmlls", bin = "qmlls6", pkg = "qt6-tools" } },
	},
}

--- Report order; unknown ecosystems append alphabetically so a new row still shows up.
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

--- Deterministic ecosystem order. Every aggregator iterates this.
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

--- Every tool, tagged with the ecosystem and kind it came from.
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

--- Package name for a tool, or nil when nothing packages it (`pkg = false`).
---@param tool toolchain.Tool
---@return string?
function M.package_of(tool)
	if tool.pkg == false then
		return nil
	end
	return tool.pkg or tool.bin
end

--- Every package the ecosystem needs, `sys` entries included, in registry order.
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
