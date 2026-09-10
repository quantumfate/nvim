--- Colour arithmetic for building a ramp out of whatever a colorscheme provides.
---@class theme.color
local M = {}

--- Splits a 24-bit colour into its channels.
---@param rgb integer
---@return integer r, integer g, integer b
local function channels(rgb)
	return bit.rshift(rgb, 16) % 256, bit.rshift(rgb, 8) % 256, rgb % 256
end

--- Mixes two colours. `t` is how far to move from `a` towards `b`.
---@param a integer 24-bit colour
---@param b integer 24-bit colour
---@param t number 0..1
---@return integer mixed
function M.blend(a, b, t)
	local ar, ag, ab = channels(a)
	local br, bg, bb = channels(b)
	local function mix(x, y)
		return math.floor(x + (y - x) * t + 0.5)
	end
	return mix(ar, br) * 65536 + mix(ag, bg) * 256 + mix(ab, bb)
end

--- Perceived brightness, 0..1. Used to tell a dark scheme from a light one.
---@param rgb integer
---@return number luminance
function M.luminance(rgb)
	local r, g, b = channels(rgb)
	return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
end

--- "#rrggbb" for a 24-bit colour, which is what nvim_set_hl wants.
---@param rgb integer
---@return string hex
function M.hex(rgb)
	return ("#%06x"):format(rgb)
end

--- Reads one attribute off a highlight group, following links.
---@param group string
---@param attr "fg"|"bg"
---@return integer|nil rgb nil when the group is undefined or has no such attribute
function M.from_hl(group, attr)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
	if not ok then
		return nil
	end
	return hl[attr]
end

--- First of `groups` that defines `attr`.
---@param groups string[]
---@param attr "fg"|"bg"
---@return integer|nil rgb
function M.first(groups, attr)
	for _, group in ipairs(groups) do
		local value = M.from_hl(group, attr)
		if value then
			return value
		end
	end
	return nil
end

return M
