-- snacks.notifier spec: renders LSP progress as a single spinner notification per client.

return {
	"folke/snacks.nvim",
	---@type snacks.Config
	opts = {
		notifier = {}, -- defaults
	},
	--- Aggregates LspProgress events into per-client notifications.
	---@return nil
	init = function()
		-- Per-client progress messages; keyed by client id, entries auto-created on access.
		local progress = vim.defaulttable()
		vim.api.nvim_create_autocmd("LspProgress", {
			---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
			callback = function(ev)
				local client = vim.lsp.get_client_by_id(ev.data.client_id)
				local value = ev.data.params.value --[[@as {percentage?: number, title?: string, message?: string, kind: "begin" | "report" | "end"}]]
				if not client or type(value) ~= "table" then
					return
				end
				local p = progress[client.id]

				-- Upsert this token's entry (append if new), formatting a "[ nn%] title **message**" line.
				for i = 1, #p + 1 do
					if i == #p + 1 or p[i].token == ev.data.params.token then
						p[i] = {
							token = ev.data.params.token,
							msg = ("[%3d%%] %s%s"):format(
								value.kind == "end" and 100 or value.percentage or 100,
								value.title or "",
								value.message and (" **%s**"):format(value.message) or ""
							),
							done = value.kind == "end",
						}
						break
					end
				end

				-- Collect messages to show, and drop finished entries from the retained list.
				local msg = {} ---@type string[]
				progress[client.id] = vim.tbl_filter(function(v)
					return table.insert(msg, v.msg) or not v.done
				end, p)

				local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
				vim.notify(table.concat(msg, "\n"), vim.log.levels.INFO, {
					id = "lsp_progress",
					title = client.name,
					opts = function(notif)
						notif.icon = #progress[client.id] == 0 and " "
							or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
					end,
				})
			end,
		})
	end,
	keys = {
		{
			"<leader>Nl",
			function()
				Snacks.notifier.show_history()
			end,
			desc = "Noice Last Message",
		},
		{
			"<leader>Np",
			function()
				Snacks.picker.notifications()
			end,
			desc = "Notification History",
		},
	},
}
