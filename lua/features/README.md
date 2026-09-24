# features

Behaviour this config implements itself. `lua/plugins/` holds the lazy specs; the
code they call lives here.

| Module                                                      | Does                                                             |
| ----------------------------------------------------------- | ---------------------------------------------------------------- |
| [`refactor/`](./refactor/README.md)                         | signature, rename, extract, inline, safe delete                  |
| [`lang/`](./lang/README.md)                                 | one keymap set per language: build, asm, IR, expand              |
| [`crash/`](./crash/README.md)                               | core dumps and kernel oops, with jumpable frames                 |
| [`sys/`](./sys/README.md)                                   | struct layout, ELF, disassembly, kernel tree, QEMU               |
| [`workspace/`](./workspace/README.md)                       | two panes, borrowed views, the one-view dock                     |
| [`ui/`](./ui/README.md)                                     | slot engine, mutually exclusive sidebar, modes, layout snapshots |
| `lsp/`                                                      | capability-gated keymaps, per-server config                      |
| `lualine/`                                                  | statusline components and their colours                          |
| `ts_scope.lua`                                              | duplicate the textobject under the cursor                        |
| `ts_select.lua`                                             | treesitter-driven selection                                      |
| [`whichkey.lua`](./whichkey.lua)                            | which-key rail placement: bottom rail hugging the cursor's half  |
| `multicursor.lua`                                           | motion-spawned cursors over multicursor.nvim (`gz` dialect)      |
| `treesitter.lua`                                            | parser and query helpers                                         |
| `mini.lua`                                                  | shared mini.\* setup and which-key hints                         |
| `win_swap.lua`                                              | swap with a neighbouring split, skipping panels                  |
| `bufferline.lua` `harpoon.lua` `navbuddy.lua` `chezmoi.lua` | per-plugin glue                                                  |

`refactor/` is the largest of these and documents itself; start at its README.
