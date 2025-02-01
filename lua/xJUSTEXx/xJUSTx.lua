local M = {}

function M.just(command)
  local use_fidget = false
  local fidget

  if pcall(function()
    fidget = require("fidget")
  end) then
    use_fidget = true
  end

  if use_fidget then
    local handle = fidget.progress.handle.create({
      title = "Just: " .. command,
      message = "Compiling " .. vim.fn.expand("%") .. "...",
      lsp_client = { name = "xJUSTEXx" },
      percentage = 0,
    })

    local cmd = "just " .. command
    vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data then
          handle:report({ message = "Compiling " .. vim.fn.expand("%") .. "..." })
        end
      end,
      on_stderr = function(_, data)
        if data then
          handle:report({ message = "Compiling " .. vim.fn.expand("%") .. "...", percentage = 50 })
        end
      end,
      on_exit = function(_, code)
        if code == 0 then
          handle:finish()
        else
          handle:report({ message = "Failed" })
          handle:finish()
        end
      end,
    })
  else
    vim.notify("Starting compilation: " .. command, vim.log.levels.INFO)

    local cmd = "just " .. command
    vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data then
          vim.notify("Compiling " .. vim.fn.expand("%") .. "...", vim.log.levels.INFO)
        end
      end,
      on_stderr = function(_, data)
        if data then
          vim.notify("Compiling " .. vim.fn.expand("%") .. "... 50% done", vim.log.levels.WARN)
        end
      end,
      on_exit = function(_, code)
        if code == 0 then
          vim.notify("Compilation finished successfully!", vim.log.levels.INFO)
        else
          vim.notify("Compilation failed!", vim.log.levels.ERROR)
        end
      end,
    })
  end
end

return M
