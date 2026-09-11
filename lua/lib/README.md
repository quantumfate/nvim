# lib

Generic helpers. No plugin may be required from here except lazy's own config.

| File             | Holds                                                     |
| ---------------- | --------------------------------------------------------- |
| `root.lua`       | project root detection (LSP → markers → cwd), cached      |
| `modules.lua`    | `is_loaded`, `on_load`, `require_on_index`                |
| `ui.lua`         | save/restore window + cursor                              |
| `icons.lua`      | the glyph table behind the `icons` global                 |
| `async_shim.lua` | routes `require("async")` to the copy each plugin expects |

Anything that knows about a specific plugin belongs in `lua/features/`.
