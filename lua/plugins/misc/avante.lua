return {
	"yetone/avante.nvim",
	-- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
	-- ⚠️ must add this setting! ! !
	build = "make",
	event = "VeryLazy",
	version = false, -- Never set this value to "*"! Never!
	init = function()
		vim.opt.laststatus = 3
	end,
	opts = {
		-- add any opts here
		-- this file can contain specific instructions for your project
		instructions_file = "avante.md",
		-- for example
		provider = "claude",
		providers = {
			claude = {
				endpoint = "https://api.anthropic.com",
				model = "claude-sonnet-4-20250514",
				timeout = 30000, -- Timeout in milliseconds
				extra_request_body = {
					temperature = 0.75,
					max_tokens = 20480,
				},
			},
		},
		file_selector = {
			provider = "snacks",
			-- Options override for custom providers
			-- provider_opts = {},
		},
		selector = {
			provider = "snacks",
			-- provider_opts = {},
			-- exclude_auto_select = {}, -- List of items to exclude from auto selection
		},
		acp_providers = {
			["claude-code"] = {
				command = "npx",
				args = { "@zed-industries/claude-code-acp" },
				env = {
					NODE_NO_WARNINGS = "1",
					ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY"),
					CLAUDE_CODE_OAUTH_TOKEN = os.getenv("CLAUDE_CODE_OAUTH_TOKEN"),
				},
			},
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
		{ "<leader>apc", function()
			require("avante.config").override({ provider = "claude" })
			vim.notify("Switched to Claude provider", vim.log.levels.INFO)
		end, desc = "Avante: Switch to Claude" },

		{ "<leader>apo", function()
			require("avante.config").override({ provider = "openai" })
			vim.notify("Switched to OpenAI provider", vim.log.levels.INFO)
		end, desc = "Avante: Switch to OpenAI" },

		{ "<leader>apg", function()
			require("avante.config").override({ provider = "gemini" })
			vim.notify("Switched to Gemini provider", vim.log.levels.INFO)
		end, desc = "Avante: Switch to Gemini" },

		-- Quick actions
		{ "<leader>aq", "<cmd>AvanteAsk<cr>", desc = "Avante: Quick Ask" },
		{ "<leader>as", function()
			-- Save current context and ask
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			local content = table.concat(lines, "\n")
			vim.fn.setreg('"', content)
			vim.cmd("AvanteAsk")
		end, desc = "Avante: Save context and ask" },

		-- File operations
		{ "<leader>afi", function()
			-- Create avante instructions file if it doesn't exist
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
		end, desc = "Avante: Edit instructions file" },

		-- Diff operations
		{ "<leader>ado", "<cmd>AvanteShowDiff<cr>", desc = "Avante: Show diff" },
		{ "<leader>ada", "<cmd>AvanteApplyDiff<cr>", desc = "Avante: Apply diff" },
		{ "<leader>adr", "<cmd>AvanteRejectDiff<cr>", desc = "Avante: Reject diff" },

		-- History and sessions
		{ "<leader>ah", "<cmd>AvanteHistory<cr>", desc = "Avante: Show history" },
		{ "<leader>acl", "<cmd>AvanteClear<cr>", desc = "Avante: Clear chat" },

		-- Advanced features
		{ "<leader>aex", function()
			-- Export current conversation
			local timestamp = os.date("%Y%m%d_%H%M%S")
			local filename = "avante_export_" .. timestamp .. ".md"
			vim.cmd("AvanteExport " .. filename)
			vim.notify("Exported to " .. filename, vim.log.levels.INFO)
		end, desc = "Avante: Export conversation" },

		-- Quick templates
		{ "<leader>atr", function()
			vim.cmd("AvanteAsk")
			vim.api.nvim_feedkeys("Review this code for potential issues and suggest improvements:", "n", false)
		end, desc = "Avante: Code review template" },

		{ "<leader>ato", function()
			vim.cmd("AvanteAsk")
			vim.api.nvim_feedkeys("Optimize this code for better performance:", "n", false)
		end, desc = "Avante: Optimization template" },

		{ "<leader>atd", function()
			vim.cmd("AvanteAsk")
			vim.api.nvim_feedkeys("Add comprehensive documentation to this code:", "n", false)
		end, desc = "Avante: Documentation template" },

		{ "<leader>att", function()
			vim.cmd("AvanteAsk")
			vim.api.nvim_feedkeys("Write unit tests for this code:", "n", false)
		end, desc = "Avante: Test template" },

		-- Debug and troubleshooting
		{ "<leader>adb", function()
			local config = require("avante.config")
			print(vim.inspect(config))
		end, desc = "Avante: Show config" },

		{ "<leader>adl", function()
			vim.cmd("messages")
		end, desc = "Avante: Show logs" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"nvim-mini/mini.pick", -- for file_selector provider mini.pick
		"ibhagwan/fzf-lua", -- for file_selector provider fzf
		"folke/snacks.nvim", -- for input provider snacks
		"echasnovski/mini.icons", -- or echasnovski/mini.icons
		{
			-- support for image pasting
			"HakonHarnes/img-clip.nvim",
			event = "VeryLazy",
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
		{
			-- Make sure to set this up properly if you have lazy=true
			"MeanderingProgrammer/render-markdown.nvim",
			opts = {
				file_types = { "markdown", "Avante" },
			},
			ft = { "markdown", "Avante" },
		},
	},
}
