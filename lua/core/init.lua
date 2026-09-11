--- Core config loader: options, filetypes, autocmds, keymaps, then the local subsystems.

--- Global glyph table shared across statusline, diagnostics, and plugin configs.
--- A lazy proxy: the table is 600+ lines, and nothing reads it during startup.
_G.icons = require("lib.modules").require_on_index("lib.icons") ---@type icons external: global read throughout config

-- Before any plugin: the colorscheme hook has to exist by the time the first
-- scheme loads, or the first paint has no highlights of ours on it.
require("theme").setup()

require("core.options")
require("core.filetype")
require("core.autocmds")
require("core.keymaps")

-- Both subsystems are large and neither is needed to edit a file, so they register
-- their commands here and load their implementation on first use. See lua/toolchain/
-- and lua/scaffold/.
require("toolchain").setup()
require("scaffold").setup()

-- :Refactor / :RefactorUndo. The ops themselves load on first use.
require("features.refactor").setup()

-- One keymap set for every language: <leader>b build, <leader>v view. Adapters load
-- on the first buffer of their filetype. See lua/features/lang/.
require("features.lang").setup()

-- Named window slots, and lending `aux` to transient views. See lua/features/workspace/.
require("features.workspace").setup()

-- :Crashes / :CrashOpen / :CrashDecode. See lua/features/crash/.
require("features.crash").setup()

-- <leader>x: struct layout, ELF, disassembly, stack traces, kernel tree. See lua/features/sys/.
require("features.sys").setup()
