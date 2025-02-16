--- Module for handling ISBN validation, fetching book data, and generating BibTeX entries.
local M = {}

local curl = require("plenary.curl")

--- Validates the given ISBN by removing invalid characters and checking its length.
--- @param isbn string The ISBN to validate.
--- @return string|nil The formatted ISBN if valid, or nil if invalid.
--- @return string|nil An error message if the ISBN is invalid.
local function validate_isbn(isbn)
  local format_isbn = isbn:gsub("[^%dX]", "")
  if #format_isbn ~= 10 and #format_isbn ~= 13 then
    return nil, " ISBN inválido. Debe tener 10 o 13 dígitos."
  end
  return format_isbn
end

--- Fetches book data from the Open Library API for the given ISBN.
--- @param isbn string The validated ISBN.
--- @return table|nil The decoded JSON data if successful, or nil if an error occurs.
--- @return string|nil An error message if the fetch fails.
local function fetch_data(isbn)
  local url = string.format("https://openlibrary.org/api/books?bibkeys=ISBN:%s&jscmd=data&format=json", isbn)
  local resp = curl.get(url, { timeout = 10000 })
  if resp.status ~= 200 then
    return nil, " Error al obtener datos de Open Library: " .. resp.status
  end
  local ok, data = pcall(vim.fn.json_decode, resp.body)
  if not ok or vim.tbl_isempty(data) then
    return nil, " No se encontraron datos para el ISBN ingresado"
  end
  return data
end

--- Builds a BibTeX entry from the given book data.
--- @param bibkey string The BibTeX key for the entry.
--- @param value table The book data from the API.
--- @return string The formatted BibTeX entry.
local function build_bibtex_entry(bibkey, value)
  local authors = {}
  if value.authors then
    for _, author in ipairs(value.authors) do
      table.insert(authors, author.name)
    end
  end

  local fields = {
    string.format("@book{%s,", bibkey),
    string.format("  title        = {%s},", value.title or " "),
    string.format("  subtitle     = {%s},", value.subtitle or " "),
    string.format("  author       = {%s},", table.concat(authors, ", ") or " "),
    string.format("  translator   = {%s},", (value.authors and value.authors[2] and value.authors[2].name) or " "),
    string.format(
      "  publisher    = {%s},",
      (value.publishers and value.publishers[1] and value.publishers[1].name) or " "
    ),
    string.format("  year         = {%s},", (value.publish_date and value.publish_date:match("(%d%d%d%d)")) or " "),
    string.format("  isbn         = {%s},", bibkey),
    string.format("  pagetotal    = {%s},", (value.number_of_pages and tostring(value.number_of_pages)) or " "),
    string.format(
      "  address      = {%s}",
      (value.publish_places and value.publish_places[1] and value.publish_places[1].name) or " "
    ),
    "}",
  }
  return table.concat(fields, "\n")
end

--- Saves the selected BibTeX entry to a file and opens it in a split window.
--- @param selected_bibtex string The BibTeX entry to save.
local function save_and_open_bib(selected_bibtex)
  local bib_file = vim.fn.expand("%:p:h") .. "/refs.bib"
  local file = io.open(bib_file, "a")
  if file then
    file:write("\n" .. selected_bibtex .. "\n")
    file:close()
    vim.notify(" Entrada añadida a " .. bib_file, vim.log.levels.INFO)
    vim.cmd("vsplit " .. bib_file)
  else
    vim.notify("󰮘 Error al abrir el archivo referencias.bib", vim.log.levels.ERROR)
  end
end

--- Main function to search for a book by ISBN and handle user interaction.
function M.xSEARCH_ISBNx()
  local isbn_input = vim.fn.input(" Ingrese ISBN (puede incluir guiones): ")
  if isbn_input == "" then
    return
  end

  local format_isbn, err = validate_isbn(isbn_input)
  if not format_isbn then
    vim.notify(err or "Error desconocido", vim.log.levels.ERROR)
    return
  end

  local data, fetch_err = fetch_data(format_isbn)
  if not data then
    vim.notify(fetch_err or "Error desconocido", vim.log.levels.ERROR)
    return
  end

  local options = {}
  for key, value in pairs(data) do
    local bibkey = key:gsub("ISBN:", "")
    local bibtex_entry = build_bibtex_entry(bibkey, value)
    local summary = string.format(
      "%s | %s | %s",
      format_isbn,
      (value.authors and value.authors[1] and value.authors[1].name) or " ",
      value.title or " "
    )
    table.insert(options, { summary = summary, bibtex = bibtex_entry })
  end

  if #options == 1 then
    save_and_open_bib(options[1].bibtex)
    return
  end

  local summaries = vim.tbl_map(function(opt)
    return opt.summary
  end, options)
  vim.ui.select(summaries, { prompt = " Seleccione una entrada:" }, function(choice)
    if not choice then
      vim.notify("󰜺 Operación cancelada", vim.log.levels.WARN)
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
