--- Core config loader: publishes shared globals, then options, autocmds, and scaffolder.

--- Global icon table shared across statusline, diagnostics, and plugin configs.
_G.icons = require("util.icons") ---@type icons external: global read throughout config

require("config.settings")
require("config.autocmds")

-- The external toolchain data model and its JSON store. See lua/toolchain/.
require("toolchain").setup()

-- :ProjectScaffold generates best-practice config for the current project. See lua/scaffold/.
require("scaffold").setup()
