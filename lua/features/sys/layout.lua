--- Struct layout: offsets, sizes, holes and cache lines, from the compiler's own
--- debug info.
---
--- Padding is invisible in source and expensive at runtime: a `char` before a `long`
--- costs seven bytes per instance, and a hot struct that spills into a second cache
--- line costs a miss per access. pahole reads the DWARF and says so, member by member.
---@class sys.layout
local M = {}

M.title = "struct layout"

local output = require("features.lang.output")
local util = require("features.sys.util")

--- Aggregate type nodes whose `name` field is the type name.
---@type table<string, true>
local AGGREGATES = {
	struct_specifier = true,
	union_specifier = true,
	class_specifier = true,
	struct_item = true,
	union_item = true,
	type_spec = true,
}

--- The type the cursor is on or inside: `struct packet` at a use, the struct body
--- being edited, or a typedef name.
---@param buf integer
---@return string?
function M.type_name(buf)
	local node = vim.treesitter.get_node({ bufnr = buf })
	while node do
		local kind = node:type()
		if kind == "type_identifier" then
			return vim.treesitter.get_node_text(node, buf)
		end
		if AGGREGATES[kind] and node:field("name")[1] then
			return vim.treesitter.get_node_text(node:field("name")[1], buf)
		end
		if kind == "type_definition" and node:field("declarator")[1] then
			return vim.treesitter.get_node_text(node:field("declarator")[1], buf)
		end
		node = node:parent()
	end
	local word = vim.fn.expand("<cword>")
	return word ~= "" and word or nil
end

--- Shows pahole's view of `name`, highlighting holes.
---@param buf integer
---@param name string
---@param lines string[]
local function show(buf, name, lines)
	local empty = #lines == 0 or (#lines == 1 and (lines[1] == "" or lines[1]:match("not found")))
	if empty then
		local why = {
			go = "Go's linker keeps DWARF only for types the runtime needs, so most structs are not there for pahole.",
			rust = "Build with debug info (the dev profile) and check the type is used.",
			zig = "Build in Debug mode and check the type is used.",
		}
		Snacks.notify.warn(
			("No layout for `%s`. %s"):format(
				name,
				why[vim.bo[buf].filetype] or "Is it defined (not just declared) in this translation unit?"
			),
			{ title = "Layout" }
		)
		return
	end
	local view = output.show({ title = M.title, lines = lines, filetype = "c", mode = "float", source = buf, link = false })
	local ns = vim.api.nvim_create_namespace("sys_layout")
	for row, line in ipairs(lines) do
		local group = line:find("XXX", 1, true) and "DiagnosticWarn"
			or line:find("cacheline", 1, true) and line:find("boundary", 1, true) and "DiagnosticInfo"
			or nil
		if group then
			vim.api.nvim_buf_set_extmark(view.buf, ns, row - 1, 0, { line_hl_group = group })
		end
	end
end

--- Layout of the type under the cursor.
---
--- C and C++ compile just this file with the project's recorded flags into a
--- throwaway object, so it works before the project links. Everything else reads the
--- built binary, which is where Rust, Zig and Go keep their DWARF.
---@param buf integer
function M.show(buf)
	if not output.require_exe("pahole") then
		return
	end
	local name = M.type_name(buf)
	if not name then
		Snacks.notify.warn("No type under the cursor", { title = "Layout" })
		return
	end
	local ft = vim.bo[buf].filetype

	if ft == "c" or ft == "cpp" then
		local obj = output.tempfile(".o")
		local path = vim.api.nvim_buf_get_name(buf)
		-- Unused types are dropped from DWARF by default, and a struct you are still
		-- designing is usually unused.
		local extra = { "-g", "-fno-eliminate-unused-debug-types", "-c", "-o", obj }
		if path:match("%.h$") or path:match("%.hpp$") or path:match("%.hh$") then
			vim.list_extend(extra, { "-x", ft == "cpp" and "c++" or "c" })
		end
		local cmd, dir = require("features.lang.c").invocation(buf, extra)
		util.chain(M.title, { { cmd = cmd, cwd = dir }, { cmd = { "pahole", "-C", name, obj } } }, function(results)
			pcall(vim.fn.delete, obj)
			local last = results[#results]
			if last.code ~= 0 then
				output.show({ title = M.title, lines = util.lines(last), mode = "float", source = buf, link = false })
				return
			end
			show(buf, name, util.lines(last))
		end)
		return
	end

	require("features.sys.util").binary(buf, function(bin)
		util.chain(M.title, { { cmd = { "pahole", "-C", name, bin } } }, function(results)
			show(buf, name, util.lines(results[#results]))
		end)
	end)
end

return M
