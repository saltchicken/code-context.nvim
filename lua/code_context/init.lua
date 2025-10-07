-- File: code-context.nvim/lua/code_context/init.lua

local M = {}

M.config = {}

function M.setup(opts)
	M.config = vim.tbl_extend("force", M.config, opts or {})
end

-- This helper function to show the window is unchanged
local function show_in_floating_win(lines)
	vim.schedule(function()
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.api.nvim_buf_set_name(buf, "[code-context-output]")
		vim.api.nvim_buf_set_option(buf, "filetype", "text")

		local width = math.floor(vim.o.columns * 0.8)
		local height = math.floor(vim.o.lines * 0.8)
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
		vim.api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>close<CR>", { noremap = true, silent = true })
	end)
end

-- REFACTORED: The core function now takes an 'output_target' parameter
function M.run_command(opts, output_target)
	-- Default to 'clipboard' if no target is specified
	output_target = output_target or "clipboard"

	local command = { "code_context" }
	for _, arg in ipairs(opts.fargs or {}) do
		table.insert(command, arg)
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

			-- This logic now uses the 'output_target' to decide what to do
			if output_target == "float" then
				show_in_floating_win(output_lines)
				vim.notify("✅ Output displayed in floating window.", vim.log.levels.INFO)
			else -- The default is 'clipboard'
				local output_string = table.concat(output_lines, "\n")
				vim.fn.setreg("+", output_string)
				vim.notify("✅ Context copied to clipboard (" .. #output_lines .. " lines).", vim.log.levels.INFO)
			end
		end,
	})
end

-- This command now checks for --tree to decide the output target
vim.api.nvim_create_user_command("CodeContext", function(opts)
	local is_tree_mode = false
	for _, arg in ipairs(opts.fargs or {}) do
		if arg == "--tree" then
			is_tree_mode = true
			break
		end
	end

	if is_tree_mode then
		M.run_command(opts, "float")
	else
		M.run_command(opts, "clipboard")
	end
end, {
	nargs = "*",
	desc = "Run code_context and copy. Use --tree to show in a float.",
	complete = function()
		return { "--preset ", "--tree" }
	end,
})

-- NEW: A dedicated command that always outputs to the floating window
vim.api.nvim_create_user_command("CodeContextFloat", function(opts)
	M.run_command(opts, "float")
end, {
	nargs = "*",
	desc = "Run code_context and display output in a floating window.",
	complete = function()
		-- No need to suggest --tree, since that's the default for this command
		return { "--preset " }
	end,
})

return M
