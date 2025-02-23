local M = {}

local function get_main_file_name()
  local justfile_path = vim.fn.getcwd() .. "/.justfile"
  local file = io.open(justfile_path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  -- Buscar la línea que define el archivo principal
  local main_file = content:match('main_file%s*:=%s*"([^"]+)"')
  return main_file
end

--- Function to execute a "just" command with optional progress reporting
---@param command string: The "just" command to execute
function M.xCOMPILEx(command)
  local use_fidget = false
  local fidget

  if pcall(function()
    fidget = require("fidget")
  end) then
    use_fidget = true
  end

  local cmd = "just " .. command
  local file_name = get_main_file_name() or vim.fn.expand("%:t")
  local handle

  if use_fidget then
    handle = fidget.progress.handle.create({
      title = "Just: " .. command,
      message = "Compiling " .. file_name .. "...",
      lsp_client = { name = "xJUSTEXx" },
      percentage = 0,
    })
  else
    vim.notify("Starting compilation: " .. command, vim.log.levels.INFO)
  end

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data and #data > 0 then
        local message = "Compiling " .. file_name .. "..."
        if use_fidget then
          handle:report({ message = message })
        else
          vim.notify(message, vim.log.levels.INFO)
        end
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 then
        local message = "Compiling " .. file_name .. "..."
        if use_fidget then
          handle:report({ message = message, percentage = 50 })
        else
          vim.notify(message, vim.log.levels.WARN)
        end
      end
    end,
    on_exit = function(_, code)
      if code == 0 then
        local message = "Compilation finished successfully!"
        if use_fidget then
          handle:report({ message = message })
          handle:finish()
        else
          vim.notify(message, vim.log.levels.INFO)
        end
      else
        local message = "Compilation failed! Exit code: " .. code
        if use_fidget then
          handle:report({ message = message })
          handle:finish()
        else
          vim.notify(message, vim.log.levels.ERROR)
        end
      end
    end,
  })
end

return M
