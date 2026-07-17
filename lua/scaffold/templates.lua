--- Best-practice config file templates for the scaffold module
--- Every string here is consumed by a tool already wired into this Neovim config
--- (conform formatters, nvim-lint linters, or the LSP servers in mason.lua) so a
--- generated file is immediately live without extra setup.
---@class scaffold.templates
local M = {}

local tools = require("scaffold.tools")

--- Conventional-commit message template, wired via `git config commit.template`
--- by the generated setup script. Mirrors the lance.nvim convention.
M.gitmessage = [[
type(scope): short description

# Types: feat, fix, refactor, perf, style, test, build, ops, docs, chore, revert
# Rules: lowercase type, scope optional, description <= 100 chars
# Body (optional): what & why, wrap at 72 cols
]]

--- Baseline editor settings shared by every project. Mirrors the shfmt `-i 4`
--- override in conform.lua and the tab-indented Makefile/Go conventions.
M.editorconfig = [[
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.py]
indent_size = 4

[*.{sh,bash}]
indent_size = 4

[*.go]
indent_style = tab
indent_size = 4

[{Makefile,makefile,GNUmakefile}]
indent_style = tab
]]

--- yamllint config. Relaxes the default 80-char line limit (the source of the
--- warnings in ansible tasks) to a warning at 120 and eases ansible-friendly rules.
--- Consumed by the `yamllint` linter in nvim-lint.lua.
M.yamllint = [[
---
extends: default

rules:
  line-length:
    max: 120
    level: warning
  document-start: disable
  truthy:
    check-keys: false
  comments:
    min-spaces-from-content: 1
]]

--- stylua config for Lua projects. Consumed by the `stylua` formatter.
M.stylua = [[
column_width = 120
line_endings = "Unix"
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
]]

--- prettier config. Consumed by the `prettierd`/`prettier` formatters for
--- js/ts/json/css/markdown/yaml.
M.prettierrc = [[
{
  "printWidth": 100,
  "singleQuote": false,
  "semi": true,
  "trailingComma": "all"
}
]]

--- markdownlint config. Consumed by the `markdownlint` linter. Disables the two
--- rules that fight ordinary prose (line length, inline HTML).
M.markdownlint = [[
default: true
MD013: false
MD033: false
MD041: false
]]

--- ruff config for Python projects that have no pyproject.toml to hang it off.
--- Consumed by the `ruff`/`ruff_format` tooling and basedpyright.
M.ruff = [[
line-length = 100
target-version = "py311"

[lint]
select = ["E", "F", "I", "UP", "B", "SIM"]
]]

--- clang-format for C/C++ projects. Consumed by the `clang-format` formatter and
--- respected by clangd.
M.clang_format = [[
---
BasedOnStyle: LLVM
IndentWidth: 4
ColumnLimit: 100
AllowShortFunctionsOnASingleLine: Empty
]]

--- rustfmt config. Consumed by the `rustfmt` formatter / rust-analyzer.
M.rustfmt = [[
max_width = 100
edition = "2021"
]]

--- Per-ecosystem .gitignore fragments, composed on demand by `M.gitignore`.
---@type table<string, string>
local IGNORE = {
	os = "# OS / editor\n.DS_Store\n*.swp\n*.swo\n.direnv/\n",
	lua = "# Lua\nluac.out\n*.luac\n",
	python = "# Python\n__pycache__/\n*.py[cod]\n.venv/\nvenv/\n.pytest_cache/\n.ruff_cache/\n.mypy_cache/\ndist/\nbuild/\n*.egg-info/\n",
	node = "# Node\nnode_modules/\ndist/\n.next/\n*.log\n.cache/\n",
	rust = "# Rust\n/target/\n",
	go = "# Go\n/bin/\nvendor/\n",
	c = "# C / C++\n*.o\n*.obj\n*.a\n*.so\n/build/\n",
	nix = "# Nix\nresult\nresult-*\n",
	ansible = "# Ansible\n*.retry\n.vault_pass\n",
}

--- Builds a .gitignore covering OS/editor junk plus every detected ecosystem.
---@param detection scaffold.Detection
---@return string
function M.gitignore(detection)
	local parts = { IGNORE.os }
	-- Deterministic ordering keeps generated files diff-stable across runs.
	local order = { "lua", "python", "node", "rust", "go", "c", "nix", "ansible" }
	for _, eco in ipairs(order) do
		if detection.ecosystems[eco] and IGNORE[eco] then
			table.insert(parts, IGNORE[eco])
		end
	end
	return table.concat(parts, "\n")
end

--- Builds a justfile: the deterministic wiring hub. fmt/fmt-check/lint/test/build
--- recipes aggregate every detected ecosystem's commands (from scaffold.tools),
--- and `check` chains them so pre-commit and CI share one entry point. The three
--- environment recipes (`setup` local, `provision` ansible/system, `dev` nix) make
--- every provisioning path reachable through the same interface.
---@param detection scaffold.Detection
---@return string
function M.justfile(detection)
	local lines = {
		"# Task runner. Run `just` to list recipes.",
		"# Recipes are generated from the detected toolchain; edit freely.",
		"",
		"default:",
		"\t@just --list",
		"",
	}

	--- Emits a recipe from a list of commands, skipping it entirely when empty so
	--- the justfile never carries dead targets.
	---@param name string
	---@param cmds string[]
	---@param comment? string
	local function recipe(name, cmds, comment)
		if #cmds == 0 then
			return
		end
		if comment then
			table.insert(lines, "# " .. comment)
		end
		table.insert(lines, name .. ":")
		for _, cmd in ipairs(cmds) do
			table.insert(lines, "\t" .. cmd)
		end
		table.insert(lines, "")
	end

	recipe("fmt", tools.commands(detection, "fmt"), "Reformat the tree in place")
	recipe("fmt-check", tools.commands(detection, "fmt_check"), "Verify formatting without writing")
	recipe("lint", tools.commands(detection, "lint"), "Static analysis")
	recipe("test", tools.commands(detection, "test"))
	recipe("build", tools.commands(detection, "build"))

	-- Aggregate gate reused by pre-commit and CI. Only reference recipes we emitted.
	local gate = {}
	if #tools.commands(detection, "fmt_check") > 0 then
		table.insert(gate, "fmt-check")
	end
	if #tools.commands(detection, "lint") > 0 then
		table.insert(gate, "lint")
	end
	if #tools.commands(detection, "test") > 0 then
		table.insert(gate, "test")
	end
	if #gate > 0 then
		table.insert(lines, "# Full verification gate (used by pre-commit and CI)")
		table.insert(lines, "check: " .. table.concat(gate, " "))
		table.insert(lines, "")
	end

	table.insert(lines, "# Bootstrap the local dev environment (hooks, toolchain, PATH)")
	table.insert(lines, "setup:")
	table.insert(lines, "\t./scripts/setup.sh")
	table.insert(lines, "")
	table.insert(lines, "# Install the system toolchain via ansible (needs sudo)")
	table.insert(lines, "provision:")
	table.insert(lines, "\tansible-playbook scripts/provision.yml --ask-become-pass")
	table.insert(lines, "")
	-- Nix entry point: the reproducible flake devShell.
	table.insert(lines, "# Enter the reproducible nix dev shell")
	table.insert(lines, "dev:")
	table.insert(lines, "\tnix develop")
	table.insert(lines, "")

	return table.concat(lines, "\n")
end

--- Builds a .pre-commit-config.yaml. Generic hygiene hooks plus conventional
--- commits, with local hooks that run `just fmt-check`/`just lint` so formatting
--- policy lives in exactly one place (the justfile / scaffold.tools).
---@param detection scaffold.Detection
---@return string
function M.precommit(detection)
	local L = {
		"---",
		"repos:",
		"  - repo: https://github.com/pre-commit/pre-commit-hooks",
		"    rev: v5.0.0",
		"    hooks:",
		"      - id: trailing-whitespace",
		"      - id: end-of-file-fixer",
		"      - id: check-merge-conflict",
		"      - id: mixed-line-ending",
		"      - id: check-added-large-files",
	}
	if detection.ecosystems.yaml then
		table.insert(L, "      - id: check-yaml")
	end
	if detection.ecosystems.node then
		table.insert(L, "      - id: check-json")
	end

	-- Conventional commit-message enforcement.
	vim.list_extend(L, {
		"  - repo: https://github.com/compilerla/conventional-pre-commit",
		"    rev: v4.0.0",
		"    hooks:",
		"      - id: conventional-pre-commit",
		"        stages: [commit-msg]",
	})

	-- Local hooks route formatting/lint through the justfile so there is a single
	-- source of truth. Emitted only when there is something to check.
	local has_fmt = #tools.commands(detection, "fmt_check") > 0
	local has_lint = #tools.commands(detection, "lint") > 0
	if has_fmt or has_lint then
		table.insert(L, "  - repo: local")
		table.insert(L, "    hooks:")
		if has_fmt then
			vim.list_extend(L, {
				"      - id: just-fmt-check",
				"        name: just fmt-check",
				"        entry: just fmt-check",
				"        language: system",
				"        pass_filenames: false",
			})
		end
		if has_lint then
			vim.list_extend(L, {
				"      - id: just-lint",
				"        name: just lint",
				"        entry: just lint",
				"        language: system",
				"        pass_filenames: false",
			})
		end
	end

	return table.concat(L, "\n")
end

--- Builds the Nix flake devShell: the standard, reproducible project toolchain.
--- `nix develop` (or direnv `use flake`) yields an environment pinned by flake.lock,
--- declaratively providing every detected ecosystem's tools. The shellHook installs
--- the shared pre-commit hooks so entering the shell wires the repo too. Packages
--- come from scaffold.tools.packages(_, "nix").
---@param detection scaffold.Detection
---@return string
function M.flake(detection)
	local pkgs = tools.packages(detection, "nix")
	local pkg_lines = {}
	for _, p in ipairs(pkgs) do
		table.insert(pkg_lines, "            " .. p)
	end
	return table.concat({
		"{",
		'  description = "Development environment";',
		"",
		"  inputs = {",
		'    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";',
		'    flake-utils.url = "github:numtide/flake-utils";',
		"  };",
		"",
		"  outputs = { self, nixpkgs, flake-utils }:",
		"    flake-utils.lib.eachDefaultSystem (system:",
		"      let pkgs = import nixpkgs { inherit system; };",
		"      in {",
		"        devShells.default = pkgs.mkShell {",
		"          packages = with pkgs; [",
		table.concat(pkg_lines, "\n"),
		"          ];",
		"          # Wire the repo into git on shell entry.",
		"          shellHook = ''",
		"            command -v pre-commit >/dev/null && \\",
		"              pre-commit install --hook-type pre-commit --hook-type commit-msg 2>/dev/null || true",
		"          '';",
		"        };",
		"      });",
		"}",
	}, "\n")
end

--- Builds an ansible playbook that installs the system toolchain. `ansible.builtin.package`
--- auto-selects the host package manager (pacman/apt/dnf/...), and per-OS-family
--- name lists (from scaffold.tools) are selected at runtime via ansible_facts, so a
--- single playbook provisions any distro. Mirrors the nix devShell.
---@param detection scaffold.Detection
---@return string
function M.provision(detection)
	local by_family = tools.sys_packages_by_family(detection)
	local L = {
		"---",
		"# System toolchain provisioning. Run: just provision",
		"# ansible.builtin.package auto-selects the host package manager; names are",
		"# chosen per OS family below. Add a family key to extend to other distros.",
		"- name: Provision development toolchain",
		"  hosts: localhost",
		"  connection: local",
		"  become: true",
		"  vars:",
		"    toolchain_packages:",
	}
	for _, family in ipairs(tools.sys_families) do
		table.insert(L, "      " .. family .. ":")
		for _, p in ipairs(by_family[family]) do
			table.insert(L, "        - " .. p)
		end
	end
	vim.list_extend(L, {
		"  tasks:",
		"    - name: Install toolchain packages",
		"      ansible.builtin.package:",
		"        name: \"{{ toolchain_packages[ansible_facts['os_family']]",
		"          | default(toolchain_packages['Archlinux']) }}\"",
		"        state: present",
	})

	-- Per-ecosystem user-level bootstrap (rocks/components/deps), run as the
	-- invoking user, not root, so files land in their home.
	local boots = tools.bootstrap(detection)
	for _, b in ipairs(boots) do
		vim.list_extend(L, {
			("    - name: Bootstrap %s toolchain"):format(b.eco),
			"      become: false",
			"      ansible.builtin.shell: |",
		})
		for _, cmd in ipairs(b.cmds) do
			table.insert(L, "        " .. cmd)
		end
		table.insert(L, "      changed_when: false")
	end

	-- Wire per-user tool bin dirs onto PATH via the login profile, so binaries
	-- installed above (and by the package manager) are usable in new shells.
	local paths = tools.bin_paths(detection)
	if #paths > 0 then
		vim.list_extend(L, {
			"    - name: Wire tool paths into ~/.profile",
			"      become: false",
			"      ansible.builtin.lineinfile:",
			'        path: "{{ ansible_env.HOME }}/.profile"',
			"        create: true",
			'        line: "{{ item }}"',
			"      loop:",
		})
		for _, p in ipairs(paths) do
			-- Emit as a POSIX export; single-quote so YAML keeps it literal.
			table.insert(L, ("        - 'export PATH=\"%s:$PATH\"'"):format(p))
		end
	end

	return table.concat(L, "\n")
end

--- Renovate config for automated dependency updates. Mirrors the lance.nvim setup.
M.renovate = [[
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended", ":dependencyDashboard", ":semanticCommits"],
  "labels": ["dependencies"],
  "prConcurrentLimit": 5
}
]]

--- Minimal Keep-a-Changelog stub.
M.changelog = [[
# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
]]

--- GitHub issue-form templates, adapted from the lance.nvim patterns.
M.issue_bug = [[
name: Bug report
description: Report a problem
labels: [bug]
body:
  - type: textarea
    id: what-happened
    attributes:
      label: What happened?
      description: A clear description of the bug, plus steps to reproduce.
    validations:
      required: true
  - type: textarea
    id: expected
    attributes:
      label: Expected behaviour
    validations:
      required: true
  - type: input
    id: version
    attributes:
      label: Version / environment
    validations:
      required: false
]]

M.issue_feature = [[
name: Feature request
description: Suggest an idea
labels: [enhancement]
body:
  - type: textarea
    id: problem
    attributes:
      label: Problem
      description: What problem would this feature solve?
    validations:
      required: true
  - type: textarea
    id: solution
    attributes:
      label: Proposed solution
    validations:
      required: false
]]

--- Builds scripts/setup.sh: the thin local bootstrap. It only wires the repo into
--- the developer's git (hooks + commit template) and enables direnv, then hands
--- off toolchain provisioning to the environments that own it:
---   * system-wide  -> just provision   (ansible)
---   * project/nix  -> just dev          (nix develop, flake devShell)
--- Keeping the toolchain out of this script means there is exactly one declarative
--- place per environment, not an imperative copy here. Adapted from lance.nvim.
---@param detection scaffold.Detection
---@return string
function M.setup_sh(detection)
	local _ = detection
	return table.concat({
		"#!/usr/bin/env bash",
		"set -euo pipefail",
		"",
		"log_info() { printf '\\033[0;34m[INFO]\\033[0m %s\\n' \"$1\"; }",
		"log_ok() { printf '\\033[0;32m\\xe2\\x9c\\x94\\033[0m %s\\n' \"$1\"; }",
		"log_warn() { printf '\\033[0;33m\\xe2\\x9a\\xa0\\033[0m %s\\n' \"$1\"; }",
		"",
		'have() { command -v "$1" >/dev/null 2>&1; }',
		"",
		'log_info "Wiring repository into your environment..."',
		"",
		"# Git hooks via pre-commit.",
		"if have pre-commit; then",
		"  pre-commit install --hook-type pre-commit --hook-type commit-msg -f",
		'  log_ok "Git hooks installed"',
		"else",
		'  log_warn "pre-commit not found - provided by: just provision / just dev"',
		"fi",
		"",
		"# Conventional-commit message template.",
		'if [[ -f ".gitmessage" ]]; then',
		"  git config commit.template .gitmessage",
		'  log_ok "Commit template enabled"',
		"fi",
		"",
		"# Enable direnv so the nix shell and tool PATHs load on cd.",
		"if have direnv && [[ -f .envrc ]]; then",
		"  direnv allow",
		'  log_ok "direnv enabled (.envrc)"',
		"fi",
		"",
		'log_ok "Repository wired."',
		'log_info "Install the toolchain:  just provision   (system, ansible)"',
		'log_info "                    or:  just dev         (project, nix shell)"',
		'log_info "Run checks:             just check"',
	}, "\n")
end

--- Builds a direnv .envrc: the cross-machine glue. On a nix machine it loads the
--- flake devShell (nix-direnv `use flake`), giving the full pinned toolchain on
--- `cd`; on non-nix machines it just adds the per-user tool bin dirs so
--- ansible-installed binaries resolve. The nix guard keeps the same file valid
--- everywhere.
---@param detection scaffold.Detection
---@return string
function M.envrc(detection)
	local L = {
		"# direnv: frictionless per-project environment.",
		"# On nix machines this loads the pinned flake devShell (needs nix-direnv).",
		"if has nix && [[ -f flake.nix ]]; then",
		"  use flake",
		"fi",
	}
	local paths = tools.bin_paths(detection)
	if #paths > 0 then
		table.insert(L, "")
		table.insert(L, "# Per-user tool bin directories (system / ansible machines).")
		for _, p in ipairs(paths) do
			-- PATH_add expands $HOME and handles relative dirs; quote for safety.
			table.insert(L, ('PATH_add "%s"'):format(p))
		end
	end
	return table.concat(L, "\n")
end

--- CI workflow running `just check` inside the flake devShell, so CI and local
--- environments are identical (same flake.lock).
---@param detection scaffold.Detection
---@return string
function M.ci(detection)
	local _ = detection
	return table.concat({
		"---",
		"name: CI",
		"on:",
		"  push:",
		"    branches: [main, master]",
		"  pull_request:",
		"jobs:",
		"  check:",
		"    runs-on: ubuntu-latest",
		"    steps:",
		"      - uses: actions/checkout@v4",
		"      - uses: cachix/install-nix-action@v30",
		"        with:",
		"          extra_nix_config: |",
		"            experimental-features = nix-command flakes",
		"      - run: nix develop --command just check",
	}, "\n")
end

return M
