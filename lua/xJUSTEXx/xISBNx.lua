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

  local options = {}

  for key, value in pairs(data) do
    local bibkey = key:gsub("ISBN:", "")
    local title = value.title or " "
    local subtitle = value.subtitle or " "
    local author = (value.authors and value.authors[1] and value.authors[1].name) or " "
    local translator = (value.authors and value.authors[2] and value.authors[2].name) or " "
    local publisher = (value.publishers and value.publishers[1] and value.publishers[1].name) or " "
    local year = (value.publish_date and value.publish_date:match("(%d%d%d%d)")) or " "
    local isbn_val = bibkey
    local pagetotal = (value.number_of_pages and tostring(value.number_of_pages)) or " "
    local address = (value.publish_places and value.publish_places[1] and value.publish_places[1].name) or " "

    local bibtex_entry = string.format(
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

    local summary = string.format("%s | %s | %s", format_isbn, author, title)
    table.insert(options, { summary = summary, bibtex = bibtex_entry })
  end

  local function save_and_open_bib(selected_bibtex)
    local bib_file = vim.fn.expand("%:p:h") .. "/refs.bib"
    local file = io.open(bib_file, "a")
    if file then
      file:write("\n" .. selected_bibtex .. "\n")
      file:close()
      vim.notify("✓ Entrada añadida a " .. bib_file, vim.log.levels.INFO)
      vim.cmd("vsplit " .. bib_file)
    else
      vim.notify("Error al abrir el archivo referencias.bib", vim.log.levels.ERROR)
    end
  end

  if #options == 1 then
    save_and_open_bib(options[1].bibtex)
    return
  end

  local summaries = vim.tbl_map(function(opt)
    return opt.summary
  end, options)

  vim.ui.select(summaries, { prompt = "Seleccione una entrada:" }, function(choice)
    if not choice then
      vim.notify("Operación cancelada", vim.log.levels.WARN)
      return
    end

    for _, opt in ipairs(options) do
      if opt.summary == choice then
        save_and_open_bib(opt.bibtex)
        break
      end
    end
  end)
end

return M
