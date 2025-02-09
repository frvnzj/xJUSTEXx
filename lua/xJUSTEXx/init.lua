local M = {}

local config = require("xJUSTEXx.config")
local xJUSTx = require("xJUSTEXx.xJUSTx")
local xJUSTEXx = require("xJUSTEXx.xJUSTEXx")

function M.setup(opts)
  config.setup(opts)
end

M.xNEW_PROJECTx = xJUSTEXx.xNEW_PROJECTx
M.xCOMPILEx = xJUSTx.xCOMPILEx
M.xTEXDOCx = xJUSTEXx.xTEXDOCx
M.xPPLATEXx = xJUSTEXx.xPPLATEXx

return M
