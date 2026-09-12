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
	local view =
		output.show({ title = M.title, lines = lines, filetype = "c", mode = "float", source = buf, link = false })
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

--- Marker the generated Go test prints before each record, so `go test -v` chatter
--- around it can be told apart.
local GO_MARK = "@nvim-layout"

--- A test that prints `name`'s layout as the compiler laid it out.
---
--- A test file rather than a program importing the package: an unexported type (most
--- structs) is only nameable from inside its own package. reflect's offsets come from
--- the compiler that built the test, so they are the layout the program gets.
---@param package string
---@param name string
---@return string
function M.go_test_source(package, name)
	return ([[
package %s

import (
	"fmt"
	"reflect"
	"testing"
)

func TestNvimLayout(t *testing.T) {
	ty := reflect.TypeOf((*%s)(nil)).Elem()
	if ty.Kind() != reflect.Struct {
		fmt.Printf("%s notstruct %%s\n", ty.Kind())
		return
	}
	fmt.Printf("%s struct %%s %%d %%d\n", ty.Name(), ty.Size(), ty.Align())
	for i := 0; i < ty.NumField(); i++ {
		f := ty.Field(i)
		fmt.Printf("%s field %%s %%d %%d %%s\n", f.Name, f.Offset, f.Type.Size(), f.Type.String())
	}
}
]]):format(package, name, GO_MARK, GO_MARK, GO_MARK)
end

local CACHELINE = 64

--- pahole-style text from the generated test's output: members with offset and size,
--- holes and cache line crossings marked the way pahole marks them, so the same
--- highlighting applies. Nil when the output holds no layout.
---@param lines string[]
---@return string[]?
function M.go_render(lines)
	local struct, fields = nil, {}
	for _, line in ipairs(lines) do
		local rest = line:match("^" .. vim.pesc(GO_MARK) .. " (.*)$")
		if rest then
			local kind = rest:match("^notstruct (%S+)")
			if kind then
				return { ("/* not a struct: %s */"):format(kind) }
			end
			local name, size, align = rest:match("^struct (%S+) (%d+) (%d+)$")
			if name then
				struct = { name = name, size = tonumber(size), align = tonumber(align) }
			end
			local fname, offset, fsize, ftype = rest:match("^field (%S+) (%d+) (%d+) (.+)$")
			if fname then
				table.insert(fields, { name = fname, offset = tonumber(offset), size = tonumber(fsize), type = ftype })
			end
		end
	end
	if not struct then
		return nil
	end

	local out = { ("struct %s {"):format(struct.name) }
	local sum, holes, hole_bytes, cacheline = 0, 0, 0, 0
	local cursor = 0
	for _, f in ipairs(fields) do
		if f.offset > cursor then
			holes, hole_bytes = holes + 1, hole_bytes + f.offset - cursor
			table.insert(out, "")
			table.insert(out, ("\t/* XXX %d bytes hole, try to pack */"):format(f.offset - cursor))
			table.insert(out, "")
		end
		if math.floor(f.offset / CACHELINE) > cacheline then
			cacheline = math.floor(f.offset / CACHELINE)
			table.insert(
				out,
				("\t/* --- cacheline %d boundary (%d bytes) --- */"):format(cacheline, cacheline * CACHELINE)
			)
		end
		table.insert(out, ("\t%-24s %-20s /* %5d %5d */"):format(f.type, f.name .. ";", f.offset, f.size))
		sum = sum + f.size
		cursor = f.offset + f.size
	end

	local padding = struct.size - cursor
	if padding > 0 then
		table.insert(out, "")
		table.insert(out, ("\t/* XXX %d bytes padding */"):format(padding))
	end
	table.insert(out, "")
	table.insert(
		out,
		("\t/* size: %d, cachelines: %d, members: %d, align: %d */"):format(
			struct.size,
			math.max(1, math.ceil(struct.size / CACHELINE)),
			#fields,
			struct.align
		)
	)
	table.insert(out, ("\t/* sum members: %d, holes: %d, sum holes: %d */"):format(sum, holes, hole_bytes))
	table.insert(out, "};")
	return out
end

--- Go layout, which pahole cannot give: the linker keeps DWARF only for types the
--- runtime needs.
---
--- The test file goes in through `-overlay`, so the compiler sees it in the package
--- directory while nothing is written there. `go test` builds offline from the module
--- cache like any other build.
---@param buf integer
---@param name string
local function go_layout(buf, name)
	local package
	for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		package = line:match("^package%s+([%w_]+)")
		if package then
			break
		end
	end
	if not package then
		Snacks.notify.warn("No package clause in this file", { title = "Layout" })
		return
	end

	local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
	local tmp = vim.fn.tempname()
	vim.fn.mkdir(tmp, "p")
	local src, overlay = tmp .. "/layout_test.go", tmp .. "/overlay.json"
	vim.fn.writefile(vim.split(M.go_test_source(package, name), "\n"), src)
	vim.fn.writefile({ vim.json.encode({ Replace = { [dir .. "/zz_nvim_layout_test.go"] = src } }) }, overlay)
	local cmd = { "go", "test", "-v", "-vet=off", "-count=1", "-overlay", overlay, "-run", "^TestNvimLayout$", "." }
	util.chain(M.title, { { cmd = cmd, cwd = dir } }, function(results)
		vim.fn.delete(tmp, "rf")
		local res = results[1]
		local lines = res.code == 0 and M.go_render(util.lines(res))
		if not lines then
			output.show({ title = M.title, lines = util.lines(res), mode = "float", source = buf, link = false })
			return
		end
		show(buf, name, lines)
	end)
end

--- Layout of the type under the cursor.
---
--- C and C++ compile just this file with the project's recorded flags into a
--- throwaway object, so it works before the project links. Go asks its own compiler
--- through a generated test. Everything else reads the built binary, which is where
--- Rust and Zig keep their DWARF.
---@param buf integer
function M.show(buf)
	local ft = vim.bo[buf].filetype
	if ft ~= "go" and not output.require_exe("pahole") then
		return
	end
	local name = M.type_name(buf)
	if not name then
		Snacks.notify.warn("No type under the cursor", { title = "Layout" })
		return
	end

	if ft == "go" then
		go_layout(buf, name)
		return
	end

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
