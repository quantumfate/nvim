--- Filetype detection this config adds on top of nvim's own.
---
--- The Ansible half is the bulk of it: Ansible has no file extension of its own, so
--- everything is inferred from directory layout, and anything that layout misses is
--- caught by sniffing the buffer.

vim.filetype.add({
	extension = {
		zir = "zir",
		--- Jinja templates have no filetype of their own. Detect the rendered file's type
		--- from the name with `.j2` stripped (nginx.conf.j2 -> conf) so templates are
		--- highlighted at all; fall back to a jinja-aware dialect when the stem says nothing.
		---@param path string
		---@return string
		j2 = function(path)
			return vim.filetype.match({ filename = (path:gsub("%.j2$", "")) }) or "htmldjango"
		end,
	},
	filename = {
		["playbook.yml"] = "yaml.ansible",
		["playbook.yaml"] = "yaml.ansible",
		["site.yml"] = "yaml.ansible",
		["site.yaml"] = "yaml.ansible",
		["ansible.cfg"] = "dosini",
	},
	pattern = {
		["[jt]sconfig.*.json"] = "jsonc",
		-- Standard Ansible role/playbook layout.
		[".*/defaults/.*%.ya?ml"] = "yaml.ansible",
		[".*/host_vars/.*%.ya?ml"] = "yaml.ansible",
		[".*/group_vars/.*%.ya?ml"] = "yaml.ansible",
		[".*/group_vars/.*/.*%.ya?ml"] = "yaml.ansible",
		[".*/playbook.*%.ya?ml"] = "yaml.ansible",
		[".*/playbooks/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/tasks/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/handlers/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/defaults/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/vars/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/meta/.*%.ya?ml"] = "yaml.ansible",
		[".*/tasks/.*%.ya?ml"] = "yaml.ansible",
		[".*/handlers/.*%.ya?ml"] = "yaml.ansible",
		[".*/molecule/.*%.ya?ml"] = "yaml.ansible",
		[".*/inventory/.*%.ya?ml"] = "yaml.ansible",
		[".*galaxy.*%.ya?ml"] = "yaml.ansible",
	},
})

--- Keys that only appear at the top level of a playbook or task file.
---@type table<string, true>
local PLAYBOOK_KEYS = {
	hosts = true,
	roles = true,
	tasks = true,
	handlers = true,
	become = true,
	gather_facts = true,
	pre_tasks = true,
	post_tasks = true,
}

--- Markers that identify the root of an Ansible project. `roles/` and `inventory/`
--- are deliberately absent: those names show up in unrelated repos too.
local ROOT_MARKERS = { "ansible.cfg", ".ansible-lint", "galaxy.yml", "site.yml", "requirements.yml" }

--- Cached per directory: this runs for every plain-YAML buffer, and an upward walk
--- each time is wasteful when a project's files share a handful of directories.
---@type table<string, boolean>
local root_cache = {}

--- Whether `path` sits inside a tree that looks like an Ansible project.
---@param path string Absolute file path
---@return boolean
local function in_ansible_project(path)
	local dir = vim.fs.dirname(path)
	if root_cache[dir] == nil then
		local found = vim.fs.find(ROOT_MARKERS, { upward = true, path = dir, stop = vim.uv.os_homedir() })[1]
		root_cache[dir] = found ~= nil
	end
	return root_cache[dir]
end

--- True when the first 40 lines carry at least two distinct playbook-only keys.
---@param buf integer
---@return boolean
local function looks_like_playbook(buf)
	local ok, lines = pcall(vim.api.nvim_buf_get_lines, buf, 0, 40, false)
	if not ok then
		return false
	end
	local seen, hits = {}, 0
	for _, line in ipairs(lines) do
		local key = line:match("^%s*%-?%s*([%a_][%w_]*):")
		if key and PLAYBOOK_KEYS[key] and not seen[key] then
			seen[key] = true
			hits = hits + 1
		end
	end
	return hits >= 2
end

-- nvim only consults string-valued patterns, never content functions, for buffered
-- files. So loose playbooks that miss the layout patterns above are claimed here by
-- reading the buffer; untouched YAML is left as plain "yaml".
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("ansible_filetype", { clear = true }),
	pattern = "yaml",
	desc = "Promote plain YAML to yaml.ansible when it belongs to Ansible",
	callback = function(ev)
		if vim.bo[ev.buf].filetype ~= "yaml" then
			return
		end
		local path = vim.api.nvim_buf_get_name(ev.buf)
		-- The project-root walk is the expensive half, so the cheap buffer sniff runs first.
		if looks_like_playbook(ev.buf) or (path ~= "" and in_ansible_project(path)) then
			vim.bo[ev.buf].filetype = "yaml.ansible"
		end
	end,
})
