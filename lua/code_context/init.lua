-- File: code-context.nvim/lua/code_context/init.lua

local M = {}

M.config = {}

function M.setup(opts)
	M.config = vim.tbl_extend("force", M.config, opts or {})
end

-- Function to display output in a floating window
local function show_in_floating_win(lines)
	-- Use vim.schedule to safely call API functions from an async context
	vim.schedule(function()
		local buf = vim.api.nvim_create_buf(false, true) -- create a new scratch buffer
		vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.api.nvim_buf_set_name(buf, "[code-context-tree]")
		vim.api.nvim_buf_set_option(buf, "filetype", "text") -- optional: for basic syntax

		-- Calculate window dimensions to be 80% of the editor size
		local width = math.floor(vim.o.columns * 0.8)
		local height = math.floor(vim.o.lines * 0.8)

		-- Calculate position to center the window
		local row = math.floor((vim.o.lines - height) / 2)
		local col = math.floor((vim.o.columns - width) / 2)

		local win_opts = {
			relative = "editor",
			width = width,
			height = height,
			col = col,
			row = row,
			style = "minimal",
			border = "rounded",
		}

		local win = vim.api.nvim_open_win(buf, true, win_opts)

		-- Add a keymap to close the floating window with 'q'
		vim.api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>close<CR>", { noremap = true, silent = true })
	end)
end

function M.run_command(opts)
	local command = { "code_context" }
	local is_tree_mode = false -- Flag to detect --tree argument

	-- Check for --tree argument and build the command
	for _, arg in ipairs(opts.fargs or {}) do
		table.insert(command, arg)
		if arg == "--tree" then
			is_tree_mode = true
		end
	end

	local output_lines = {}
	local stderr_lines = {}

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
					table.insert(stderr_lines, line)
				end
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code ~= 0 then
				if #stderr_lines > 0 then
					local error_message = table.concat(stderr_lines, "\n")
					vim.notify("Error from code_context:\n" .. error_message, vim.log.levels.ERROR)
				else
					vim.notify("code_context exited with code " .. exit_code, vim.log.levels.WARN)
				end
				return
			end

			if #output_lines == 0 then
				return
			end

			-- MODIFIED: Conditional logic based on --tree argument
			if is_tree_mode then
				-- If --tree is used, show output in a floating window
				show_in_floating_win(output_lines)
				vim.notify("✅ Tree view displayed.", vim.log.levels.INFO)
			else
				-- Otherwise, copy to clipboard as before
				local output_string = table.concat(output_lines, "\n")
				vim.fn.setreg("+", output_string)
				vim.notify("✅ Context copied to clipboard (" .. #output_lines .. " lines).", vim.log.levels.INFO)
			end
		end,
	})
end

vim.api.nvim_create_user_command("CodeContext", function(opts)
	M.run_command(opts)
end, {
	nargs = "*",
	desc = "Run code_context. Use --tree to show in a floating window.",
	complete = function()
		return { "--preset ", "--tree" }
	end,
})

return M
