local M = {}

local curl = require("plenary.curl")

function M.xSEARCH_ISBNx()
  local isbn_input = vim.fn.input("Ingrese ISBN (puede incluir guiones): ")
  if isbn_input == "" then
    return
  end

  local format_isbn = isbn_input:gsub("[^%dX]", "")

  if not (#format_isbn == 10 or #format_isbn == 13) then
    vim.notify("ISBN inválido. Debe tener 10 o 13 dígitos.", vim.log.levels.ERROR)
    return
  end

  local url = string.format("https://openlibrary.org/api/books?bibkeys=ISBN:%s&jscmd=data&format=json", format_isbn)

  local resp = curl.get(url, { timeout = 10000 })
  if resp.status ~= 200 then
    vim.notify("Error al obtener datos de Open Library: " .. resp.status, vim.log.levels.ERROR)
    return
  end

  local ok, data = pcall(vim.fn.json_decode, resp.body)
  if not ok or vim.tbl_isempty(data) then
    vim.notify("No se encontraron datos para el ISBN ingresado", vim.log.levels.WARN)
    return
  end

  local bibtex_entry = ""
  local author, title

  for key, value in pairs(data) do
    local bibkey = key:gsub("ISBN:", "")
    title = value.title or " "
    local subtitle = value.subtitle or " "
    author = (value.authors and value.authors[1] and value.authors[1].name) or " "
    local translator = (value.authors and value.authors[2] and value.authors[2].name) or " "
    local publisher = (value.publishers and value.publishers[1] and value.publishers[1].name) or " "
    local year = " "
    if value.publish_date then
      year = value.publish_date:match("(%d%d%d%d)") or " "
    end
    local isbn_val = bibkey
    local pagetotal = (value.number_of_pages and tostring(value.number_of_pages)) or " "
    local address = (value.publish_places and value.publish_places[1] and value.publish_places[1].name) or " "

    bibtex_entry = string.format(
      "@book{%s,\n  title        = {%s},\n  subtitle     = {%s},\n  author       = {%s},\n  translator   = {%s},\n  publisher    = {%s},\n  year         = {%s},\n  isbn         = {%s},\n  pagetotal    = {%s},\n  address      = {%s}\n}",
      bibkey,
      title,
      subtitle,
      author,
      translator,
      publisher,
      year,
      isbn_val,
      pagetotal,
      address
    )
  end

  local summary = string.format("%s | %s | %s", format_isbn, author, title)

  local metadata = {
    bibtex = bibtex_entry,
    isbn = format_isbn,
    author = author,
    title = title,
  }

  local buf = vim.api.nvim_create_buf(false, true)
  local width = 80
  local height = 5
  local row = math.floor((vim.o.lines - height) / 2 - 1)
  local col = math.floor((vim.o.columns - width) / 2)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { summary })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = "Resultado Open Library",
    title_pos = "center",
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
    callback = function()
      local bib_file = vim.fn.expand("%:p:h") .. "/referencias.bib"
      local file = io.open(bib_file, "a")
      if file then
        file:write("\n" .. metadata.bibtex .. "\n")
        file:close()
        vim.notify("✓ Entrada añadida a " .. bib_file, vim.log.levels.INFO)
        vim.api.nvim_win_close(win, true)
      else
        vim.notify("Error al abrir el archivo referencias.bib", vim.log.levels.ERROR)
      end
    end,
    noremap = true,
    silent = true,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    callback = function()
      vim.api.nvim_win_close(win, true)
    end,
    noremap = true,
    silent = true,
  })
end

return M
