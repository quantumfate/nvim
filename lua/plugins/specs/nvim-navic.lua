local icons = {
    File          = icons.kind.File,
    Module        = icons.kind.Module,
    Namespace     = icons.kind.Namespace,
    Package       = icons.kind.Package,
    Class         = icons.kind.Class,
    Method        = icons.kind.Method,
    Property      = icons.kind.Property,
    Field         = icons.kind.Field,
    Constructor   = icons.kind.Constructor,
    Enum          = icons.kind.Enum,
    Interface     = icons.kind.Interface,
    Function      = icons.kind.Function,
    Variable      = icons.kind.Variable,
    Constant      = icons.kind.Constant,
    String        = icons.kind.String,
    Number        = icons.kind.Number,
    Boolean       = icons.kind.Boolean,
    Array         = icons.kind.Array,
    Object        = icons.kind.Object,
    Key           = icons.kind.Key,
    Null          = icons.kind.Null,
    EnumMember    = icons.kind.EnumMember,
    Struct        = icons.kind.Struct,
    Event         = icons.kind.Event,
    Operator      = icons.kind.Operator,
    TypeParameter = icons.kind.TypeParameter,
    enabled       = true,
}

return {
    "SmiteshP/nvim-navic",
    dependencies = {
        "neovim/nvim-lspconfig"
    },
    event = "User FileOpened",
    opts = {
        icons = setmetatable({}, {
            __index = function(_, k)
                if type(icons[k]) == "string" then
                    return icons[k] .. " "
                end
                return icons[k]
            end
        }),
        lsp = {
            auto_attach = true,
            preference = nil,
        },
        highlight = true,
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
