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

# Regression tests. They drive a real editor, so each spec runs in its own nvim.
test:
	nvim --headless -n -i NONE -c 'luafile tests/run.lua'

# One spec: `just test-one workspace` or `just test-one tests/workspace_spec.lua`
test-one SPEC:
	TEST_SPECS='{{SPEC}}' nvim --headless -n -i NONE -c 'luafile tests/run.lua'

# Static analysis
lint:
	luacheck .
	yamllint .

# Project checks as JSON lines; non-zero when any finding is an error
check-project DIR='.':
	nvim --headless -n -i NONE -l lua/features/workspace/headless.lua '{{DIR}}'

# CI/pre-commit gate: formatting + tests + project checks (lint is advisory)
check: fmt-check test toolchain-check check-project

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
