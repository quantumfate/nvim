#!/usr/bin/env bash
set -euo pipefail

log_info() { printf '\033[0;34m[INFO]\033[0m %s\n' "$1"; }
log_ok() { printf '\033[0;32m\xe2\x9c\x94\033[0m %s\n' "$1"; }
log_warn() { printf '\033[0;33m\xe2\x9a\xa0\033[0m %s\n' "$1"; }

have() { command -v "$1" >/dev/null 2>&1; }

log_info "Wiring repository into your environment..."

# Git hooks via pre-commit.
if have pre-commit; then
  pre-commit install --hook-type pre-commit --hook-type commit-msg -f
  log_ok "Git hooks installed"
else
  log_warn "pre-commit not found - provided by: just provision / just dev"
fi

# Conventional-commit message template.
if [[ -f ".gitmessage" ]]; then
  git config commit.template .gitmessage
  log_ok "Commit template enabled"
fi

# Enable direnv so the nix shell and tool PATHs load on cd.
if have direnv && [[ -f .envrc ]]; then
  direnv allow
  log_ok "direnv enabled (.envrc)"
fi

log_ok "Repository wired."
log_info "Install the toolchain:  just provision   (packages + plugins, ansible)"
log_info "                    or:  just dev         (project, nix shell)"
log_info "Run checks:             just check"
