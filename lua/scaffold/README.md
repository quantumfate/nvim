# scaffold

Generates project config for the open repo, tailored to the ecosystems it detects.
Non-destructive unless `--force`.

| Command                     | Does                                                  |
| --------------------------- | ----------------------------------------------------- |
| `:ProjectScaffold [scope…]` | generate. A scope forces an eco or filters a category |
| `:ProjectDoctor`            | read-only health, hygiene and secret report           |
| `:ProjectSanitize`          | fix whitespace, newlines, tracked junk, script perms  |

| File            | Holds                                                  |
| --------------- | ------------------------------------------------------ |
| `init.lua`      | command registration only; the rest loads on first use |
| `generate.lua`  | the file table, plan/apply, doctor, sanitize           |
| `tools.lua`     | per-eco project commands and package names             |
| `templates.lua` | the file bodies                                        |
| `detect.lua`    | which ecosystems and build systems a root uses         |

## Not the toolchain registry

|             | `scaffold/tools.lua`                    | [`toolchain/registry.lua`](../toolchain/README.md) |
| ----------- | --------------------------------------- | -------------------------------------------------- |
| Question    | how does a _repo_ build itself          | what does _this machine_ need installed            |
| Vocabulary  | cross-distro, nix                       | Arch packages                                      |
| `bootstrap` | `npm install` in the scaffolded project | `nlua`, `bacon-ls` for nvim                        |

`bin_paths` is the one shared fact, and the registry owns it.
