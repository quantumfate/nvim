---@class lualine_highlights
---@field CatppuccinRosewater fun(string: string):string
---@field CatppuccinFlamingo fun(string: string):string
---@field CatppuccinPink fun(string: string):string
---@field CatppuccinMauve fun(string: string):string
---@field CatppuccinRed fun(string: string):string
---@field CatppuccinMaroon fun(string: string):string
---@field CatppuccinPeach fun(string: string):string
---@field CatppuccinYellow fun(string: string):string
---@field CatppuccinGreen fun(string: string):string
---@field CatppuccinTeal fun(string: string):string
---@field CatppuccinSky fun(string: string):string
---@field CatppuccinSapphire fun(string: string):string
---@field CatppuccinBlue fun(string: string):string
---@field CatppuccinLavender fun(string: string):string
---@field CatppuccinText fun(string: string):string
---@field CatppuccinSubtext1 fun(string: string):string
---@field CatppuccinSubtext0 fun(string: string):string
---@field CatppuccinOverlay2 fun(string: string):string
---@field CatppuccinOverlay1 fun(string: string):string
---@field CatppuccinOverlay0 fun(string: string):string
---@field CatppuccinSurface2 fun(string: string):string
---@field CatppuccinSurface1 fun(string: string):string
---@field CatppuccinSurface0 fun(string: string):string
---@field CatppuccinBase fun(string: string):string
---@field CatppuccinMantle fun(string: string):string
---@field CatppuccinCrust fun(string: string):string
local lualine_highlights = {
    CatppuccinRosewater = function(string)
        return "%#CatppuccinRosewater#" .. string
    end,
    CatppuccinFlamingo = function(string)
        return "%#CatppuccinFlamingo#" .. string
    end,
    CatppuccinPink = function(string)
        return "%#CatppuccinPink#" .. string
    end,
    CatppuccinMauve = function(string)
        return "%#CatppuccinMauve#" .. string
    end,
    CatppuccinRed = function(string)
        return "%#CatppuccinRed#" .. string
    end,
    CatppuccinMaroon = function(string)
        return "%#CatppuccinMaroon#" .. string
    end,
    CatppuccinPeach = function(string)
        return "%#CatppuccinPeach#" .. string
    end,
    CatppuccinYellow = function(string)
        return "%#CatppuccinYellow#" .. string
    end,
    CatppuccinGreen = function(string)
        return "%#CatppuccinGreen#" .. string
    end,
    CatppuccinTeal = function(string)
        return "%#CatppuccinTeal#" .. string
    end,
    CatppuccinSky = function(string)
        return "%#CatppuccinSky#" .. string
    end,
    CatppuccinSapphire = function(string)
        return "%#CatppuccinSapphire#" .. string
    end,
    CatppuccinBlue = function(string)
        return "%#CatppuccinBlue#" .. string
    end,
    CatppuccinLavender = function(string)
        return "%#CatppuccinLavender#" .. string
    end,
    CatppuccinText = function(string)
        return "%#CatppuccinText#" .. string
    end,
    CatppuccinSubtext1 = function(string)
        return "%#CatppuccinSubtext1#" .. string
    end,
    CatppuccinSubtext0 = function(string)
        return "%#CatppuccinSubtext0#" .. string
    end,
    CatppuccinOverlay2 = function(string)
        return "%#CatppuccinOverlay2#" .. string
    end,
    CatppuccinOverlay1 = function(string)
        return "%#CatppuccinOverlay1#" .. string
    end,
    CatppuccinOverlay0 = function(string)
        return "%#CatppuccinOverlay0#" .. string
    end,
    CatppuccinSurface2 = function(string)
        return "%#CatppuccinSurface2#" .. string
    end,
    CatppuccinSurface1 = function(string)
        return "%#CatppuccinSurface1#" .. string
    end,
    CatppuccinSurface0 = function(string)
        return "%#CatppuccinSurface0#" .. string
    end,
    CatppuccinBase = function(string)
        return "%#CatppuccinBase#" .. string
    end,
    CatppuccinMantle = function(string)
        return "%#CatppuccinMantle#" .. string
    end,
    CatppuccinCrust = function(string)
        return "%#CatppuccinCrust#" .. string
    end,
}
return lualine_highlights