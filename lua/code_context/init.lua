local M = {}

M.config = {}

function M.setup(opts)
	M.config = vim.tbl_extend("force", M.config, opts or {})
end

function M.run_command(opts)
	local command = { "code_context" }
	for _, arg in ipairs(opts.fargs or {}) do
		table.insert(command, arg)
	end

	local output_lines = {}
	local stderr_lines = {} -- New table to collect error lines

	vim.fn.jobstart(command, {
		cwd = vim.fn.getcwd(),
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if not data then
				return
			end
			for _, line in ipairs(data) do
				-- We still notify immediately for progress-like lines
				if string.match(line, "^[✅🔄❌🧹]") then
					vim.notify(line, vim.log.levels.INFO)
				end
				if line ~= "" then
					table.insert(output_lines, line)
				end
			end
		end,
		-- MODIFIED: on_stderr now collects lines instead of notifying immediately
		on_stderr = function(_, data)
			if not data then
				return
			end
			for _, line in ipairs(data) do
				if line ~= "" then
					table.insert(stderr_lines, line)
				end
			end
		end,
		-- MODIFIED: on_exit now displays the single, consolidated error message
		on_exit = function(_, exit_code)
			-- Handle errors first
			if exit_code ~= 0 then
				if #stderr_lines > 0 then
					-- Join all collected error lines into one message
					local error_message = table.concat(stderr_lines, "\n")
					vim.notify("Error from code_context:\n" .. error_message, vim.log.levels.ERROR)
				else
					-- Fallback message if stderr was empty but it still failed
					vim.notify("code_context exited with code " .. exit_code, vim.log.levels.WARN)
				end
				return -- Stop execution here
			end

			-- Success logic (unchanged)
			if #output_lines == 0 then
				return -- Do nothing if there's no output
			end

			local output_string = table.concat(output_lines, "\n")
			vim.fn.setreg("+", output_string)
			vim.notify("✅ Context copied to clipboard (" .. #output_lines .. " lines).", vim.log.levels.INFO)
		end,
	})
end

-- Create the user command that calls the core function (unchanged)
vim.api.nvim_create_user_command("CodeContext", function(opts)
	M.run_command(opts)
end, {
	nargs = "*",
	desc = "Run code_context. E.g., :CodeContext --preset python",
	complete = function()
		return { "--preset ", "--tree" }
	end,
})

return M
