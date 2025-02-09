local M = {}

local config = require("xJUSTEXx.config")

local function create_directory_selection_window(choices, callback)
  local width = vim.api.nvim_get_option_value("columns", {})
  local height = vim.api.nvim_get_option_value("lines", {})

  local win_width = math.ceil(width * 0.4)
  local win_height = math.max(2, #choices)
  local row = math.ceil((height - win_height) / 2)
  local col = math.ceil((width - win_width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = "Select Directory",
    title_pos = "center",
  })

  for i, choice in ipairs(choices) do
    vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { string.format("%d: %s", i, choice) })
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
    noremap = true,
    callback = function()
      local line = vim.fn.line(".")
      if line >= 1 and line <= #choices then
        vim.api.nvim_win_close(win, true)
        callback(choices[line])
      end
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
    noremap = true,
    callback = function()
      vim.api.nvim_win_close(win, true)
    end,
  })

  return buf, win
end

local function create_article_name_prompt(_, callback)
  local width = vim.api.nvim_get_option_value("columns", {})
  local height = vim.api.nvim_get_option_value("lines", {})

  local win_width = math.ceil(width * 0.5)
  local win_height = 1
  local row = math.ceil((height - win_height) / 2)
  local col = math.ceil((width - win_width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  vim.api.nvim_set_option_value("buftype", "prompt", { buf = buf })

  vim.fn.prompt_setprompt(buf, "Name of the project: ")

  vim.cmd("startinsert!")

  vim.fn.prompt_setcallback(buf, function(input)
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })

    callback(input)
  end)

  return buf, win
end

local function create_template_selection_window(templates, callback)
  local choices = vim.tbl_keys(templates)
  local width = vim.api.nvim_get_option_value("columns", {})
  local height = vim.api.nvim_get_option_value("lines", {})

  local win_width = math.ceil(width * 0.4)
  local win_height = math.max(2, #choices)
  local row = math.ceil((height - win_height) / 2)
  local col = math.ceil((width - win_width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = "Select Template",
    title_pos = "center",
  })

  for i, choice in ipairs(choices) do
    vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { string.format("%d: %s", i, templates[choice].name) })
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
    noremap = true,
    callback = function()
      local line = vim.fn.line(".")
      if line >= 1 and line <= #choices then
        vim.api.nvim_win_close(win, true)
        callback(choices[line])
      end
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
    noremap = true,
    callback = function()
      vim.api.nvim_win_close(win, true)
    end,
  })

  return buf, win
end

local function is_valid_project_name(name)
  return not name:match('[/\\:%*%?"<>|]')
end

local function setup_project(project_name, project_dir, template_content)
  project_name = project_name:gsub("%s+", "_")

  if not is_valid_project_name(project_name) then
    vim.notify("Invalid project name. Please avoid using special characters.", vim.log.levels.ERROR)
    return
  end

  if project_name and project_name ~= "" then
    local project_path = project_dir .. "/" .. project_name

    if vim.fn.isdirectory(project_path) == 1 then
      local choice = vim.fn.input(
        "The project '" .. project_name .. "' already exists. Overwrite? This will delete all existing files. [y/N]: "
      )

      if choice:lower() ~= "y" then
        vim.notify("Project creation cancelled.", vim.log.levels.WARN)
        return
      else
        vim.fn.delete(project_path, "rf")
      end
    end

    vim.fn.mkdir(project_path, "p")

    vim.cmd("cd " .. project_path)

    vim.fn.system("git init")

    local main_tex_path = project_path .. "/" .. project_name .. ".tex"
    vim.fn.writefile(vim.split(template_content, "\n"), main_tex_path)

    vim.cmd("edit " .. main_tex_path)

    local justfile_path = project_path .. "/.justfile"
    local justfile_content = config.set_file_justfile(project_name)
    vim.fn.writefile(vim.split(justfile_content, "\n"), justfile_path)

    vim.notify("Project  setup complete in " .. project_dir, vim.log.levels.INFO)
  else
    vim.notify("Project  creation cancelled", vim.log.levels.INFO)
  end
end

function M.xNEW_PROJECTx()
  local project_dirs = config.options.project_dirs
  local tex_templates = config.options.tex_templates

  if #project_dirs == 0 then
    vim.notify("No project directories defined", vim.log.levels.INFO)
    return
  elseif #project_dirs == 1 then
    create_template_selection_window(tex_templates, function(template_key)
      create_article_name_prompt(project_dirs[1], function(project_name)
        setup_project(project_name, project_dirs[1], tex_templates[template_key].content)
      end)
    end)
  else
    create_directory_selection_window(project_dirs, function(selected_dir)
      create_template_selection_window(tex_templates, function(template_key)
        create_article_name_prompt(selected_dir, function(project_name)
          setup_project(project_name, selected_dir, tex_templates[template_key].content)
        end)
      end)
    end)
  end
end

function M.xTEXDOCx()
  local package = vim.fn.expand("<cword>")

  if package and package ~= "" then
    vim.fn.jobstart("texdoc " .. package, {
      on_exit = function(_, code)
        if code == 0 then
          vim.notify("Documentation opened for: " .. package, vim.log.levels.INFO)
        else
          vim.notify("Failed to open documentation for " .. package, vim.log.levels.ERROR)
        end
      end,
    })
  else
    vim.notify("No word under cursor to open documentation", vim.log.levels.WARN)
  end
end

function M.xPPLATEXx()
  local current_file = vim.fn.expand("%")
  if current_file == "" then
    vim.notify("No file is open", vim.log.levels.WARN)
    return
  end

  local cmd = "pplatex -i " .. vim.fn.shellescape(current_file:gsub("%.tex$", ".log"))

  local handle = io.popen(cmd)
  if handle then
    local result = handle:read("*a")
    handle:close()

    local lines = {}
    for line in result:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end

    local width = vim.api.nvim_get_option_value("columns", {})
    local height = vim.api.nvim_get_option_value("lines", {})

    local win_width = math.ceil(width * 0.8)
    local win_height = math.ceil(height * 0.8)
    local row = math.ceil((height - win_height) / 2)
    local col = math.ceil((width - win_width) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = win_width,
      height = win_height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
      title = "JustexLog",
      title_pos = "center",
    })

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(result, "\n"))
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

    vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
      noremap = true,
      callback = function()
        vim.api.nvim_win_close(win, true)
      end,
    })
  else
    vim.notify("Failed to run pplatex", vim.log.levels.ERROR)
  end
end

return M
