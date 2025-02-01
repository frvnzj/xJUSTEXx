local M = {}

local content = require("xJUSTEXx.opts")

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", content.default_content, opts or {})
end

function M.set_file_justfile(project_name)
  return string.format(M.options.justfile_content, project_name)
end

return M
