local ts_utils = require("nvim-treesitter.ts_utils")

local function TreeSitterIdentify()
	local node = ts_utils.get_node_at_cursor()
	local type = "cursor"
	local correct_node
	while node:parent() ~= nil do
		type = node:type() .. " > " .. type
		node = node:parent()
	end

	print(type)
end

local function FindParentNode(node, target_type)
	local type = "cursor"
	local correct_node
	while node:parent() ~= nil do
		if node:type() == target_type then
			type = node:type() .. " > " .. type
			correct_node = node
			break
		end
		type = node:type() .. " > " .. type
		node = node:parent()
	end

	if correct_node == nil then
		return nil
	end

	return correct_node, type
end

local function get_line_length(row)
	local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
	return line and #line or 0
end

local function is_line_whitespace_after_col(bufnr, row, col)
	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
	if not line then
		return true
	end
	return line:sub(col + 2):match("^%s*$") ~= nil
end

local function is_line_whitespace_until_col(bufnr, row, col)
	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
	if not line then
		return true
	end
	return line:sub(1, col):match("^%s*$") ~= nil
end

local function get_char_at(row, col)
	local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
	if not line then
		return nil
	end
	return line:sub(col + 1, col + 1)
end

local function move_selection_based_on_curlys(start_row, start_col, end_row, end_col)
	local start_char = get_char_at(start_row, start_col)
	if start_char == "{" then
		if is_line_whitespace_after_col(vim.api.nvim_get_current_buf(), start_row, start_col) then
			start_row = start_row + 1
			start_col = 0
		else
			start_col = start_col + 1
		end
	end

	while end_col >= 0 do
		local prev = get_char_at(end_row, end_col)
		if prev:match("^%s*$") then
			end_col = end_col - 1
		else
			break
		end
	end

	local end_char = get_char_at(end_row, end_col)
	if end_char == "}" then
		if is_line_whitespace_until_col(vim.api.nvim_get_current_buf(), end_row, end_col) then
			end_row = end_row - 1
			end_col = get_line_length(end_row)
		else
			end_col = end_col - 1
		end
	end

	return start_row, start_col, end_row, end_col
end

local function SelectText(start_row, start_col, end_row, end_col)
	if is_line_whitespace_until_col(vim.api.nvim_get_current_buf(), start_row, start_col) then
		start_col = 0
	end
	vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
	vim.cmd("normal! v")
	vim.api.nvim_win_set_cursor(0, { end_row + 1, end_col })
end

local function SelectViaNodes(start_node, end_node)
	local start_row, start_col, _, _ = start_node:range()
	local _, _, end_row, end_col = end_node:range()
	SelectText(start_row, start_col, end_row, end_col)
end

local function GetFunctionNodes()
	local node = ts_utils.get_node_at_cursor()
	local start_node, path = FindParentNode(node, "function_declaration") -- Use your language's node name
	local end_node = nil
	if start_node ~= nil then
		return start_node, start_node
	end

	local start_node, path = FindParentNode(node, "method_declaration") -- Use your language's node name
	if start_node ~= nil then
		return start_node, start_node
	end

	local end_node, path = FindParentNode(node, "function_body") -- Use your language's node name
	if end_node ~= nil then
		local start_node = end_node
		local sibling = start_node:prev_sibling()
		if sibling ~= nil then
			local sibling_type = sibling:type()
			if
				sibling_type == "function_declaration"
				or sibling_type == "method_declaration"
				or sibling_type == "method_signature"
			then
				start_node = sibling
			end
		end

		local sibling = start_node:prev_sibling()
		if sibling ~= nil then
			local sibling_type = sibling:type()
			if sibling_type == "annotation" then
				start_node = sibling
			end
		end
		return start_node, end_node
	end

	local end_node, path = FindParentNode(node, "function_expression")
	if end_node ~= nil then
		end_node, path = FindParentNode(end_node, "declaration")
		return end_node, end_node
	end
end

local function GetClassNodes()
	local node = ts_utils.get_node_at_cursor()
	local start_node, path = FindParentNode(node, "class_definition")
	return start_node, start_node
end

local function SelectClassNode()
	local start_node, end_node = GetClassNodes()
	if start_node == nil or end_node == nil then
		return
	end
	SelectViaNodes(start_node, end_node)
end

local function GetInsideClass()
	local node = ts_utils.get_node_at_cursor()
	local start_node, path = FindParentNode(node, "class_body")
	return start_node, start_node
end

local function SelectInsideClassNode()
	local start_node, end_node = GetInsideClass()
	if start_node == nil or end_node == nil then
		return
	end

	local start_row, start_col, _, _ = start_node:range()
	local _, _, end_row, end_col = end_node:range()

    start_row, start_col, end_row, end_col = move_selection_based_on_curlys(start_row, start_col, end_row, end_col)
	SelectText(start_row, start_col, end_row, end_col)
end

local function SelectFunctionNode()
	local start_node, end_node = GetFunctionNodes()
	if start_node == nil or end_node == nil then
		return
	end
	SelectViaNodes(start_node, end_node)
end

local function SelectInsideFunction()
	local node = ts_utils.get_node_at_cursor()
    local start_node = FindParentNode(node, 'function_body')
    print(start_node:type())
    local start_row, start_col, end_row, end_col = move_selection_based_on_curlys(start_node:range())

    local end_node = start_node
	if start_node == nil or end_node == nil then
		return
	end
    SelectText(start_row, start_col, end_row, end_col)
end

vim.keymap.set("n", "vaf", function()
	SelectFunctionNode()
end, { desc = "Visual around function" })
vim.keymap.set("n", "yaf", function()
	SelectFunctionNode()
	vim.cmd("normal! y")
end, { desc = "Yank around function" })
vim.keymap.set("n", "daf", function()
	SelectFunctionNode()
	vim.cmd("normal! d")
end, { desc = "Delete around function" })
vim.keymap.set("n", "caf", function()
	SelectFunctionNode()
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("c<esc>O", true, false, true), "n", false)
end, { desc = "Change around function" })

vim.keymap.set("n", "vac", function()
	SelectClassNode()
end, { desc = "Visual around class" })
vim.keymap.set("n", "yac", function()
	SelectClassNode()
	vim.cmd("normal! y")
end, { desc = "Yank around class" })
vim.keymap.set("n", "dac", function()
	SelectClassNode()
	vim.cmd("normal! d")
end, { desc = "Delete around class" })
vim.keymap.set("n", "cac", function()
	SelectClassNode()
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("c<esc>O", true, false, true), "n", false)
end, { desc = "Change around class" })

vim.keymap.set("n", "vic", function()
	SelectInsideClassNode()
end, { desc = "Visual inside class" })
vim.keymap.set("n", "yic", function()
	SelectInsideClassNode()
	vim.cmd("normal! y")
end, { desc = "Yank inside class" })
vim.keymap.set("n", "dic", function()
	SelectInsideClassNode()
	vim.cmd("normal! d")
end, { desc = "Delete inside class" })
vim.keymap.set("n", "cic", function()
	SelectInsideClassNode()
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("c<esc>O", true, false, true), "n", false)
end, { desc = "Change inside class" })

vim.keymap.set("n", "vif", function()
	SelectInsideFunction()
end, { desc = "Visual inside function" })
vim.keymap.set("n", "yif", function()
	SelectInsideFunction()
	vim.cmd("normal! y")
end, { desc = "Yank inside function" })
vim.keymap.set("n", "dif", function()
	SelectInsideFunction()
	vim.cmd("normal! d")
end, { desc = "Delete inside function" })
vim.keymap.set("n", "cif", function()
	SelectInsideFunction()
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("c<esc>O", true, false, true), "n", false)
end, { desc = "Change inside function" })

vim.keymap.set("n", "<leader>id", function()
	TreeSitterIdentify()
end, { desc = "Identify current node" })

