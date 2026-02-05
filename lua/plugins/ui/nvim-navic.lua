return {
    "SmiteshP/nvim-navic",
    dependencies = {
        "neovim/nvim-lspconfig",
        'nvim-mini/mini.nvim',
    },
    event = "User FileOpened",
    opts = {
        icons = setmetatable({ enabled = true }, {
            __index = function(t, k)
                if type(k) ~= "string" then
                    return nil
                end
                local icons_module = require("mini.icons")
                local key_lower = k:lower()
                local status_ok, icon = pcall(icons_module.get, "lsp", key_lower)
                if status_ok and icon then
                    local result = icon .. " "
                    rawset(t, k, result)
                    return result
                end
                return nil
            end
        }),
        lsp = {
            auto_attach = true,
            preference = nil,
        },
        highlight = false,
        separator = " > ",
        depth_limit = 0,
        depth_limit_indicator = "..",
        safe_output = true,
        lazy_update_context = false,
        click = false,
        format_text = function(text)
            return text
        end,
    }
}
