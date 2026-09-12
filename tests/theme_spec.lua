--- Regression tests for colorscheme switching, role derivation, and custom highlights.
local t = require("tests.harness")
local theme = require("theme")
local roles = require("theme.roles")
local color = require("theme.color")

t.describe("theme switching and highlights", function()
	local SCHEMES = { "catppuccin", "catppuccin-latte", "habamax", "peachpuff", "desert" }

	for _, scheme_name in ipairs(SCHEMES) do
		t.it("switches to " .. scheme_name .. " and sets custom highlights", function()
			t.reset()
			local ok = theme.set(scheme_name, { persist = false })
			t.ok(ok, "failed to switch to " .. scheme_name)
			t.ok(
				vim.g.colors_name == scheme_name
					or (scheme_name == "catppuccin" and vim.startswith(vim.g.colors_name or "", "catppuccin")),
				"unexpected colors_name: " .. tostring(vim.g.colors_name)
			)

			local r = roles.get()
			t.eq(8, #r.ramp, "ramp must have exactly 8 steps")

			-- Custom highlights must be set on top of the scheme.
			local lo = vim.api.nvim_get_hl(0, { name = "LangOutput" })
			t.ok(lo.bg ~= nil, "LangOutput bg missing in " .. scheme_name)

			local lob = vim.api.nvim_get_hl(0, { name = "LangOutputBorder" })
			t.ok(lob.fg ~= nil, "LangOutputBorder fg missing in " .. scheme_name)

			local cff = vim.api.nvim_get_hl(0, { name = "CrashFaultFrame" })
			t.ok(cff.bg ~= nil and cff.fg ~= nil, "CrashFaultFrame missing colors in " .. scheme_name)
			t.eq(true, cff.bold)

			local cf = vim.api.nvim_get_hl(0, { name = "CrashFrame" })
			t.ok(cf.fg ~= nil, "CrashFrame fg missing in " .. scheme_name)

			local rpc = vim.api.nvim_get_hl(0, { name = "RefactorPreviewConflict" })
			t.ok(rpc.fg ~= nil, "RefactorPreviewConflict fg missing in " .. scheme_name)
			t.eq(true, rpc.bold)

			local rpa = vim.api.nvim_get_hl(0, { name = "RefactorPreviewAdded" })
			t.ok(rpa.bg ~= nil, "RefactorPreviewAdded bg missing in " .. scheme_name)

			-- Diagnostics virtual text highlight groups exist.
			local dvte = vim.api.nvim_get_hl(0, { name = "DiagnosticVirtualTextError", link = false })
			t.ok(dvte.fg ~= nil or dvte.ctermfg ~= nil, "DiagnosticVirtualTextError missing in " .. scheme_name)
		end)
	end

	t.it("theme command reports active scheme without error", function()
		t.reset()
		theme.set("catppuccin", { persist = false })
		local messages = {}
		local orig_notify = vim.notify
		vim.notify = function(msg)
			table.insert(messages, msg)
		end
		vim.cmd("Theme")
		vim.notify = orig_notify
		t.ok(#messages > 0, "Theme command printed nothing")
		t.ok(messages[1]:find("catppuccin", 1, true) ~= nil, "active scheme name missing from report: " .. messages[1])
	end)
end)

t.describe("theme monotonic guard", function()
	t.it("guarantees strictly monotonic luminance in dark and light schemes", function()
		for _, name in ipairs({ "habamax", "peachpuff" }) do
			theme.set(name, { persist = false })
			local derived = roles.derive()
			local dark = derived.dark
			for i = 1, #derived.ramp - 1 do
				local lum_curr = color.luminance(derived.ramp[i])
				local lum_next = color.luminance(derived.ramp[i + 1])
				if dark then
					t.ok(
						lum_curr < lum_next,
						("dark scheme %s: ramp[%d] (lum %.3f) >= ramp[%d] (lum %.3f)"):format(
							name,
							i,
							lum_curr,
							i + 1,
							lum_next
						)
					)
				else
					t.ok(
						lum_curr > lum_next,
						("light scheme %s: ramp[%d] (lum %.3f) <= ramp[%d] (lum %.3f)"):format(
							name,
							i,
							lum_curr,
							i + 1,
							lum_next
						)
					)
				end
			end
		end
	end)

	t.it("replaces collapsed CursorLine with interpolated fraction", function()
		t.reset()
		theme.set("habamax", { persist = false })
		-- Artificially set CursorLine bg to identical Normal bg.
		local bg = color.first({ "Normal" }, "bg") or 0x1c1c1c
		vim.api.nvim_set_hl(0, "CursorLine", { bg = bg })
		local derived = roles.derive()
		local lum1 = color.luminance(derived.ramp[1])
		local lum2 = color.luminance(derived.ramp[2])
		t.ok(lum2 > lum1 + 0.01, ("ramp[2] collapsed onto ramp[1]: lum1=%.3f, lum2=%.3f"):format(lum1, lum2))
	end)

	t.it("replaces out-of-order Visual with interpolated fraction", function()
		t.reset()
		theme.set("habamax", { persist = false })
		-- Set Visual bg to extreme white (0xffffff), breaking gradient order.
		vim.api.nvim_set_hl(0, "Visual", { bg = 0xffffff })
		local derived = roles.derive()
		local lum2 = color.luminance(derived.ramp[2])
		local lum3 = color.luminance(derived.ramp[3])
		local lum4 = color.luminance(derived.ramp[4])
		t.ok(
			lum3 > lum2 and lum3 < lum4,
			("ramp[3] was not restored to monotonic order: lum2=%.3f, lum3=%.3f, lum4=%.3f"):format(lum2, lum3, lum4)
		)
	end)
end)
