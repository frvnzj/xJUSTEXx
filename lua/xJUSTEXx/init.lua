local M = {}

local config = require("xJUSTEXx.config")
local xJUSTx = require("xJUSTEXx.xJUSTx")

function M.setup(opts)
  config.setup(opts)
end

M.xJUSTEXx = xJUSTx.just

M.xTEXx = require("xJUSTEXx.xJUSTEXx").create_tex_project_article

return M
