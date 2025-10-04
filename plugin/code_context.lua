-- File: code-context.nvim/plugin/code_context.lua

-- Set a loaded guard to prevent this file from being sourced multiple times.
if vim.g.loaded_code_context_nvim == 1 then
	return
end
vim.g.loaded_code_context_nvim = 1

-- The core logic is in the 'lua/code_context' module.
-- Users will interact with it via `require('code_context').setup()` and the :CodeContext command.
