local M = {}

M.is_work_laptop = function()
	return vim.uv.os_gethostname() == "notebook-pam"
end

return M
