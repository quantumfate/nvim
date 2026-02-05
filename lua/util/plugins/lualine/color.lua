local C = require("catppuccin.palettes").get_palette("macchiato")
local O = require("catppuccin").options
local transparent_bg = O.transparent_background and "NONE" or C.mantle

return {
    normal = {
        a = { bg = C.mauve, fg = C.mantle, gui = "bold" },
        b = { bg = C.surface0, fg = C.mauve },
        c = { bg = transparent_bg, fg = C.pink },
    },

    insert = {
        a = { bg = C.green, fg = C.base, gui = "bold" },
        b = { bg = C.surface0, fg = C.green },
    },

    terminal = {
        a = { bg = C.green, fg = C.base, gui = "bold" },
        b = { bg = C.surface0, fg = C.green },
    },

    command = {
        a = { bg = C.peach, fg = C.base, gui = "bold" },
        b = { bg = C.surface0, fg = C.peach },
    },
    visual = {
        a = { bg = C.blue, fg = C.base, gui = "bold" },
        b = { bg = C.surface0, fg = C.blue },
    },
    replace = {
        a = { bg = C.red, fg = C.base, gui = "bold" },
        b = { bg = C.surface0, fg = C.red },
    },
    inactive = {
        a = { bg = transparent_bg, fg = C.blue },
        b = { bg = transparent_bg, fg = C.surface1, gui = "bold" },
        c = { bg = transparent_bg, fg = C.overlay0 },
    },
}
