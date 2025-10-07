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
	local command = { "code_context" }
	for _, arg in ipairs(opts.fargs or {}) do
		table.insert(command, arg)
	end

	local output_lines = {}

	vim.fn.jobstart(command, {
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
		-- MODIFIED SECTION: This callback now handles copying the output.
		on_exit = function(_, exit_code)
			if exit_code ~= 0 then
				vim.notify("code_context exited with code " .. exit_code, vim.log.levels.WARN)
				return
			end

			if #output_lines == 0 then
				return -- Do nothing if there's no output
			end

			-- 1. Combine all output lines into a single string.
			local output_string = table.concat(output_lines, "\n")

			-- 2. Set the system clipboard register ('+').
			vim.fn.setreg("+", output_string)

			-- 3. Notify the user of success.
			vim.notify("✅ Context copied to clipboard (" .. #output_lines .. " lines).", vim.log.levels.INFO)
		end,
	})
end

-- Create the user command that calls the core function.
vim.api.nvim_create_user_command("CodeContext", function(opts)
	M.run_command(opts)
end, {
	nargs = "*",
	-- Updated description to remove --copy
	desc = "Run code_context. E.g., :CodeContext --preset python",
	-- Updated completion to remove --copy
	complete = function()
		return { "--preset ", "--tree" }
	end,
})

return M
