return {
    "nvim-mini/mini.notify",
    event = "VeryLazy",
    config = function(_, opts)
        local notify = require("mini.notify")
        notify.setup()
        vim.notify = notify.make_notify({
            ERROR = { duration = 5000 },
            WARN = { duration = 4000 },
            INFO = { duration = 3000 },
        })
    end
}
