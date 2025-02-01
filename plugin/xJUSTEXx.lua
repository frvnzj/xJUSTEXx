local xJUSTEXx = require("xJUSTEXx")

local function complete_justex()
  local options = {}
  local justfile = vim.fn.getcwd() .. "/.justfile"

  if vim.fn.filereadable(justfile) == 1 then
    for line in io.lines(justfile) do
      local option = line:match("^([%w_]+):")
      if option then
        table.insert(options, option)
      end
    end
  end

  return options
end

vim.api.nvim_create_user_command("ProJustex", function()
  xJUSTEXx.xTEXx()
end, {})

vim.api.nvim_create_user_command("Justex", function(opts)
  xJUSTEXx.xJUSTEXx(opts.args)
end, {
  nargs = 1,
  complete = complete_justex,
})
