local logger = {}
logger.info = function(message)
    local path = vim.api.nvim_call_function('stdpath', { "log" }) .. "/log"
    local fp = io.open(path, "a")
    if fp ~= nil then
        fp:write(message)
        fp:write("\n")
        fp:close()
    end
end

--- Check if the given buffer is a databricks notebook
--- @param buffer_handle integer Buffer handle or 0 for current buffer
--- @return boolean
local is_databricks_notebook = function(buffer_handle)
    local lines = vim.api.nvim_buf_get_lines(buffer_handle, 0, 1, true)
    local header = "# Databricks notebook source"
    return string.match(lines[1], header) == header
end

--- @enum NotebookKind
local NotebookKind = {
    Markdown = 1,
    Code = 2
}

--- @class NotebookCell
--- @field kind NotebookKind The kind of cell, e.g. "code", "markdown"
--- @field document string The document uri of the cell
--- @field language string The language of the cell (python, sql, r, scala)
--- @field metadata table Additional metadata about the cell

--- @class NotebookDocument
--- @field uri string of the document, e.g. file:///Users/pam/workspace/project/my-notebook.py
--- @field version integer The version number of this document (it will increase after each change, including undo/redo).
--- @field notebookType string The type of notebook, e.g. "databricks-notebook"
--- @field metadata any
--- @field cells NotebookCell[]

--- Parse a Databricks notebook into cells
--- @param buffer_handle integer Buffer handle
--- @return NotebookCell[]
local parse_notebook_cells = function(buffer_handle)
    local lines = vim.api.nvim_buf_get_lines(buffer_handle, 0, -1, true)
    local cells = {}
    local current_cell = nil
    local i = 1

    -- Skip the header line
    if lines[1] == "# Databricks notebook source" then
        i = 2
    end

    -- Start the first cell (no COMMAND marker before it)
    local first_non_empty_index = i
    while first_non_empty_index <= #lines and (lines[first_non_empty_index] == "" or lines[first_non_empty_index]:match("^%s*$")) do
        first_non_empty_index = first_non_empty_index + 1
    end

    -- Determine language of first cell
    local first_language = "python"
    if first_non_empty_index <= #lines then
        local magic_match = lines[first_non_empty_index]:match("^# MAGIC %%?(%w+)")
        if magic_match then
            first_language = magic_match
        end
    end

    current_cell = {
        language = first_language,
        value = {},
        metadata = {}
    }

    -- Process all lines
    while i <= #lines do
        local line = lines[i]

        -- Check for cell separator (# COMMAND ----------)
        if line:match("^# COMMAND ----------$") then
            -- Add current cell to cells
            if current_cell and #current_cell.value > 0 then
                table.insert(cells, current_cell)
            end

            -- Start a new cell, but wait to determine language
            current_cell = {
                language = "python", -- Default language
                value = {},
                metadata = {}
            }

            -- Find first non-empty line after the marker
            local next_index = i + 1
            while next_index <= #lines and (lines[next_index] == "" or lines[next_index]:match("^%s*$")) do
                next_index = next_index + 1
            end

            -- Determine language based on first non-empty line
            if next_index <= #lines then
                local magic_match = lines[next_index]:match("^# MAGIC %%?(%w+)")
                if magic_match then
                    current_cell.language = magic_match
                end
            end
        else
            -- Add line to current cell
            table.insert(current_cell.value, line)
        end

        i = i + 1
    end

    -- Add the last cell if it has content
    if current_cell and #current_cell.value > 0 then
        table.insert(cells, current_cell)
    end

    return cells
end

--- Create a new NotebookDocument
--- @return NotebookDocument
local NotebookDocument = function()
    return {
        uri = "",
        version = 0,
        notebookType = "databricks-notebook",
        metadata = {},
        cells = {},
    }
end

--- Setup dbx-ls
--- @param opts any
--- @return nil
local setup = function(opts)
    vim.api.nvim_create_autocmd("FileType", {
        pattern = { "python" },
        callback = function()
            if is_databricks_notebook(0) then
                local client_id = vim.lsp.start({
                    name = "dbx-ls",
                    cmd = { vim.env.HOME .. "/workspace/dbx-ls/zig-out/bin/dbx-ls" }
                })
                if client_id == nil then
                    return
                end

                vim.lsp.buf_attach_client(0, client_id)

                -- a               client = vim.lsp.get_client_by_id(client_id)
                --
                --                 -- Initialize notebook document
                --                 local nb = NotebookDocument()
                --                 nb.uri = string.format("file://%s", vim.api.nvim_buf_get_name(0))
                --                 nb.cells = parse_notebook_cells(0)
                --
                --                 -- Send initial open notification
                --                 client.notify("notebookDocument/didOpen", {
                --                     notebookDocument = nb
                --                 })
                --
                --                 -- Track changes
                --                 vim.api.nvim_buf_attach(0, false, {
                --                     on_lines = function(
                --                         _the_literal_string_lines,
                --                         buffer_handle,
                --                         changedtick,
                --                         first_line,
                --                         last_line,
                --                         new_last_line
                --                     )
                --                         -- Update notebook version
                --                         nb.version = nb.version + 1
                --                         nb.cells = parse_notebook_cells(buffer_handle)
                --                         client.notify("notebookDocument/didChange", {
                --                             notebookDocument = {
                --                                 uri = nb.uri,
                --                                 version = nb.version
                --                             },
                --                             change = {
                --                                 cells = nb.cells
                --                             }
                --                         })
                --                     end,
                --                 })
            end
        end
    })
end


return {
    setup = setup
}
