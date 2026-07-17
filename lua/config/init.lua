_G.icons = require("util.icons")

require("config.settings")
require("config.autocmds")

-- Project scaffolder: :ProjectScaffold generates best-practice config for the
-- current project, tailored to its detected ecosystems. See lua/scaffold/.
require("scaffold").setup()
