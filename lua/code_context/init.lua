-- File: code-context.nvim/lua/code_context/init.lua

local M = {}

-- Default configuration (empty for now, but ready for future options)
M.config = {}

-- Users can call this function from their config to set options.
function M.setup(opts)
	M.config = vim.tbl_extend("force", M.config, opts or {})
end

-- The core function that runs the external command asynchronously.
function M.run_command(opts)
	local args_str = opts.args or ""
	local args_tbl = vim.split(args_str, "%s+")

	local command = { "code_context" }
	for _, arg in ipairs(args_tbl) do
		table.insert(command, arg)
	end

	local output_lines = {}
	vim.notify("🚀 Running code_context...", vim.log.levels.INFO)

	vim.fn.jobstart(command, {
		-- Change this line to run from the current file's directory
		-- cwd = vim.fn.expand("%:p:h"),
		cwd = vim.fn.getcwd(),
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if not data then
				return
			end
			for _, line in ipairs(data) do
				if string.match(line, "^[✅🔄❌🧹]") then
					vim.notify(line, vim.log.levels.INFO)
				end
				if line ~= "" then
					table.insert(output_lines, line)
				end
			end
		end,
		on_stderr = function(_, data)
			if not data then
				return
			end
			for _, line in ipairs(data) do
				if line ~= "" then
					vim.notify("Error: " .. line, vim.log.levels.ERROR)
				end
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code ~= 0 then
				vim.notify("code_context exited with code " .. exit_code, vim.log.levels.WARN)
				return
			end

			if #output_lines == 0 then
				return
			end

			local last_line = output_lines[#output_lines]
			if string.match(last_line, "✅ Context copied to clipboard.") then
				return
			else
				vim.cmd("new")
				vim.api.nvim_buf_set_option(0, "bufhidden", "wipe")
				vim.api.nvim_buf_set_option(0, "buftype", "nofile")
				vim.api.nvim_buf_set_option(0, "swapfile", false)
				vim.api.nvim_buf_set_lines(0, 0, -1, false, output_lines)
				vim.api.nvim_buf_set_name(0, "[code-context]")
				vim.notify("✅ code_context output displayed in new buffer.", vim.log.levels.INFO)
			end
		end,
	})
end

-- Create the user command that calls the core function.
vim.api.nvim_create_user_command("CodeContext", function(opts)
	M.run_command(opts)
end, {
	nargs = "*",
	desc = "Run code_context. E.g., :CodeContext --preset python --copy",
	complete = function()
		return { "--preset ", "--repo ", "--tree", "--copy" }
	end,
})

return M
