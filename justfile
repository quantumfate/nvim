# Task runner. Run `just` to list recipes.
# Recipes are generated from the detected toolchain; edit freely.

default:
	@just --list

# Reformat the tree in place
fmt:
	stylua .
	prettier --write '**/*.md'

# Verify formatting without writing
fmt-check:
	stylua --check .
	prettier --check '**/*.md'

# Static analysis
lint:
	luacheck .
	yamllint .

# CI/pre-commit gate: formatting + tests (lint is advisory)
check: fmt-check toolchain-check

# Bootstrap the local dev environment (hooks, toolchain, PATH)
setup:
	./scripts/setup.sh

# Install the external toolchain and link the config (ansible, needs sudo for pacman)
provision:
	cd ansible && ansible-playbook playbook.yml --ask-become-pass

# Regenerate the role's package vars from lua/toolchain/registry.lua
toolchain-export:
	nvim --headless -c "lua require('toolchain.export').all(vim.fn.getcwd())" -c "qa!"

# Fail if the generated vars drifted from the registry
toolchain-check: toolchain-export
	git diff --exit-code ansible/roles/nvim/vars/tools.generated.yml AUR-dependencies.txt

# Provision twice; the second run must report no changes
provision-idempotence:
	cd ansible && ansible-playbook playbook.yml
	cd ansible && ansible-playbook playbook.yml | tee /dev/stderr | grep -qE 'changed=0.*failed=0'

# Report what the editor found on PATH
toolchain-status:
	nvim --headless -c "lua require('toolchain.store').refresh({}, function(d) print(vim.inspect(d.summary)) vim.cmd('qa!') end)"

# Enter the reproducible nix dev shell
dev:
	nix develop
