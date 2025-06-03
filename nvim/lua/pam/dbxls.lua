--- Check if the given buffer is a databricks notebook
--- @param buffer_handle integer Buffer handle or 0 for current buffer
--- @return boolean
local is_databricks_notebook = function(buffer_handle)
    local lines = vim.api.nvim_buf_get_lines(buffer_handle, 0, 1, true)
    local header = "# Databricks notebook source"
    return string.match(lines[1], header) == header
end

--- Setup dbx-ls
--- @param opts any
--- @return nil
local setup = function(opts)
    _ = opts
    local root_files = { 'databricks.yml', 'databricks.yaml', 'pyproject.toml' }
    local paths = vim.fs.find(root_files, { stop = vim.env.HOME })
    local root_dir = vim.fs.dirname(paths[1])
    vim.api.nvim_create_autocmd("FileType", {
        pattern = { "python", "yaml", "yml" },
        callback = function()
            if vim.bo.filetype == "python" and not is_databricks_notebook(0) then
                return
            end
            local client_id = vim.lsp.start({
                name = "dbx-ls",
                root_dir = root_dir,
                cmd = { vim.env.HOME .. "/.local/bin/dbx-ls" },
            })
            if client_id == nil then
                return
            end

            vim.lsp.buf_attach_client(0, client_id)
        end
    })
end


return {
    setup = setup
}
