-- avante.nvim spec (currently disabled): Ollama-backed AI assistant plus its keymaps and which-key groups.

return {
	{
		"yetone/avante.nvim",
		build = "make", -- BUILD_FROM_SOURCE=true to build from source
		enabled = false,
		version = false, -- pin a release; never "*"
		--- Uses a global statusline so avante's UI spans the full width.
		---@return nil
		init = function()
			vim.opt.laststatus = 3
		end,
		opts = {
			instructions_file = "avante.md", -- per-project instructions
			provider = "ollama",
			providers = {
				ollama = {
					model = "qwen2.5-coder:32b",
					--- Reports the provider as ready only when the Ollama endpoint responds.
					---@return boolean
					is_env_set = function()
						return require("avante.providers.ollama").check_endpoint_alive()
					end,
				},
			},
			file_selector = {
				provider = "snacks",
			},
			selector = {
				provider = "snacks",
			},
		},
		keys = {
			-- Main commands
			{ "<leader>aa", "<cmd>AvanteAsk<cr>", desc = "Avante: Ask", mode = { "n", "v" } },
			{ "<leader>ar", "<cmd>AvanteRefresh<cr>", desc = "Avante: Refresh" },
			{ "<leader>ae", "<cmd>AvanteEdit<cr>", desc = "Avante: Edit", mode = { "n", "v" } },

			-- Chat and focus
			{ "<leader>ac", "<cmd>AvanteChat<cr>", desc = "Avante: Chat" },
			{ "<leader>af", "<cmd>AvanteFocus<cr>", desc = "Avante: Focus" },
			{ "<leader>at", "<cmd>AvanteToggle<cr>", desc = "Avante: Toggle" },

			-- Provider switching
			--{
			--	"<leader>apc",
			--	function()
			--		require("avante.config").override({ provider = "claude" })
			--		vim.notify("Switched to Claude provider", vim.log.levels.INFO)
			--	end,
			--	desc = "Avante: Switch to Claude",
			--},

			-- {
			-- 	"<leader>apo",
			-- 	function()
			-- 		require("avante.config").override({ provider = "openai" })
			-- 		vim.notify("Switched to OpenAI provider", vim.log.levels.INFO)
			-- 	end,
			-- 	desc = "Avante: Switch to OpenAI",
			-- },

			-- {
			-- 	"<leader>apg",
			-- 	function()
			-- 		require("avante.config").override({ provider = "gemini" })
			-- 		vim.notify("Switched to Gemini provider", vim.log.levels.INFO)
			-- 	end,
			-- 	desc = "Avante: Switch to Gemini",
			-- },

			-- Quick actions
			{ "<leader>aq", "<cmd>AvanteAsk<cr>", desc = "Avante: Quick Ask" },
			{
				"<leader>as",
				-- Yanks the whole buffer into the unnamed register, then opens an Ask prompt.
				function()
					local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
					vim.fn.setreg('"', table.concat(lines, "\n"))
					vim.cmd("AvanteAsk")
				end,
				desc = "Avante: Save context and ask",
			},

			-- File operations
			{
				"<leader>afi",
				-- Creates avante.md from a template if missing, then opens it.
				function()
					local file = vim.fn.getcwd() .. "/avante.md"
					if vim.fn.filereadable(file) == 0 then
						local default_content = [[# Avante Instructions

## Project Context
This is a [describe your project] project.

## Code Style
- Follow [your style guide]
- Use [your preferred patterns]

## Specific Instructions
- [Add any specific instructions for this project]
]]
						vim.fn.writefile(vim.split(default_content, "\n"), file)
						vim.notify("Created avante.md file", vim.log.levels.INFO)
					end
					vim.cmd("edit " .. file)
				end,
				desc = "Avante: Edit instructions file",
			},

			-- Diff operations
			{ "<leader>ado", "<cmd>AvanteShowDiff<cr>", desc = "Avante: Show diff" },
			{ "<leader>ada", "<cmd>AvanteApplyDiff<cr>", desc = "Avante: Apply diff" },
			{ "<leader>adr", "<cmd>AvanteRejectDiff<cr>", desc = "Avante: Reject diff" },

			-- History and sessions
			{ "<leader>ah", "<cmd>AvanteHistory<cr>", desc = "Avante: Show history" },
			{ "<leader>acl", "<cmd>AvanteClear<cr>", desc = "Avante: Clear chat" },

			-- Advanced features
			{
				"<leader>aex",
				-- Exports the current conversation to a timestamped markdown file.
				function()
					local filename = "avante_export_" .. os.date("%Y%m%d_%H%M%S") .. ".md"
					vim.cmd("AvanteExport " .. filename)
					vim.notify("Exported to " .. filename, vim.log.levels.INFO)
				end,
				desc = "Avante: Export conversation",
			},

			-- Quick templates
			{
				"<leader>atr",
				-- Opens Ask pre-filled with a code-review prompt.
				function()
					vim.cmd("AvanteAsk")
					vim.api.nvim_feedkeys("Review this code for potential issues and suggest improvements:", "n", false)
				end,
				desc = "Avante: Code review template",
			},

			{
				"<leader>ato",
				-- Opens Ask pre-filled with an optimization prompt.
				function()
					vim.cmd("AvanteAsk")
					vim.api.nvim_feedkeys("Optimize this code for better performance:", "n", false)
				end,
				desc = "Avante: Optimization template",
			},

			{
				"<leader>atd",
				-- Opens Ask pre-filled with a documentation prompt.
				function()
					vim.cmd("AvanteAsk")
					vim.api.nvim_feedkeys("Add comprehensive documentation to this code:", "n", false)
				end,
				desc = "Avante: Documentation template",
			},

			{
				"<leader>att",
				-- Opens Ask pre-filled with a unit-test prompt.
				function()
					vim.cmd("AvanteAsk")
					vim.api.nvim_feedkeys("Write unit tests for this code:", "n", false)
				end,
				desc = "Avante: Test template",
			},

			-- Debug and troubleshooting
			{
				"<leader>adb",
				-- Prints the resolved avante config.
				function()
					print(vim.inspect(require("avante.config")))
				end,
				desc = "Avante: Show config",
			},

			{
				"<leader>adl",
				function()
					vim.cmd("messages")
				end,
				desc = "Avante: Show logs",
			},
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"Kaiser-Yang/blink-cmp-avante",
			"nvim-mini/mini.pick", -- for file_selector provider mini.pick
			"ibhagwan/fzf-lua", -- for file_selector provider fzf
			"folke/snacks.nvim", -- for input provider snacks
			"echasnovski/mini.icons", -- or echasnovski/mini.icons
			{
				-- support for image pasting
				"HakonHarnes/img-clip.nvim",
				opts = {
					-- recommended settings
					default = {
						embed_image_as_base64 = false,
						prompt_for_file_name = false,
						drag_and_drop = {
							insert_mode = true,
						},
						-- required for Windows users
						use_absolute_path = true,
					},
				},
			},
		},
	},
	{
		"folke/which-key.nvim",
		opts = {
			spec = {
				{ "<leader>a", group = "avante" },
				{
					"<leader>ad",
					group = "diff",
				},
				{
					"<leader>af",
					group = "file",
				},
				{
					"<leader>at",
					group = "templates",
				},
			},
		},
	},
}
