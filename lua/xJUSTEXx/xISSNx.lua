local M = {}
local curl = require("plenary.curl")
local Job = require("plenary.job")

local function remove_accents(str)
  local accents = {
    ["á"] = "a",
    ["é"] = "e",
    ["í"] = "i",
    ["ó"] = "o",
    ["ú"] = "u",
    ["Á"] = "A",
    ["É"] = "E",
    ["Í"] = "I",
    ["Ó"] = "O",
    ["Ú"] = "U",
    ["ñ"] = "n",
    ["Ñ"] = "N",
  }
  return str:gsub("[%z\1-\127\194-\244][\128-\191]*", accents)
end

local function is_valid_url(url)
  local curl_args = {
    "-sSL",
    "-o",
    "/dev/null",
    "-w",
    "%{http_code}",
    "--max-time",
    "10",
    "--retry",
    "2",
    "--retry-max-time",
    "30",
    "--retry-delay",
    "1",
    url,
  }

  local result, errors = {}, {}
  local job = Job:new({
    command = "curl",
    args = curl_args,
    on_stdout = function(_, data)
      table.insert(result, data)
    end,
    on_stderr = function(_, err)
      if err and err ~= "" then
        table.insert(errors, err)
      end
    end,
  })

  local success, err = pcall(function()
    job:sync(35000)
  end)
  if not success then
    vim.schedule(function()
      vim.notify("Job execution failed: " .. (err or "unknown error"), vim.log.levels.ERROR)
    end)
    return false
  end

  if #errors > 0 then
    vim.schedule(function()
      vim.notify("cURL errors:\n" .. table.concat(errors, "\n"), vim.log.levels.WARN)
    end)
  end

  if #result > 0 then
    local status_code = tonumber(result[1])
    return status_code and status_code >= 200 and status_code < 400
  end

  return false
end

local function get_valid_url(links)
  for _, link in ipairs(links) do
    if link.URL and is_valid_url(link.URL) then
      return link.URL
    end
  end
  return nil
end

local function safe_curl_get(url, options)
  options = options or {}
  local ok, resp = pcall(curl.get, url, options)
  if not ok or not resp or resp.status ~= 200 then
    vim.notify("Failed to fetch: " .. url, vim.log.levels.ERROR)
    return nil
  end
  return resp
end

local function extract_issn(selected_journal)
  local issn = selected_journal:match("ISSN:%s*([^,]+)")
  if not issn then
    vim.notify("No ISSN found", vim.log.levels.ERROR)
    return nil
  end
  return issn:gsub("print:%s*", ""):gsub("electronic:%s*", "")
end

local function prompt_select(options, prompt, callback)
  vim.ui.select(options, { prompt = prompt }, function(choice)
    if not choice then
      vim.notify("No selection made", vim.log.levels.WARN)
      return
    end
    callback(choice)
  end)
end

local function download_file(url, filepath, format)
  vim.notify("Downloading " .. format .. "...", vim.log.levels.INFO)
  vim.fn.jobstart({ "wget", "-O", filepath, url }, {
    detach = true,
    on_exit = function(_, code)
      if code == 0 then
        vim.notify(format .. " downloaded: " .. filepath, vim.log.levels.INFO)
      else
        vim.notify("Failed to download " .. format, vim.log.levels.ERROR)
      end
    end,
  })
end

function M.xCROSSREFx()
  prompt_select({ "Keywords", "ISSN" }, "Search by:", function(search_type)
    if not search_type then
      vim.notify("No search type selected", vim.log.levels.WARN)
      return
    end

    local journal_resp
    if search_type == "Keywords" then
      local journal_search = vim.fn.input("Search journals: ")
      if journal_search == "" then
        vim.notify("No journal search term provided", vim.log.levels.WARN)
        return
      end

      local clean_query = remove_accents(journal_search)
      local encode_query = clean_query:gsub("%s+", "+")
      journal_resp = safe_curl_get("https://api.crossref.org/journals?query=" .. encode_query)
      if not journal_resp then
        return
      end
    elseif search_type == "ISSN" then
      local issn_input = vim.fn.input("Enter ISSN (e.g., 2594-1917): "):gsub("%s+", "")
      if issn_input == "" then
        vim.notify("No ISSN provided", vim.log.levels.WARN)
        return
      end
      journal_resp = curl.get("https://api.crossref.org/journals/" .. issn_input)
    end

    if journal_resp.status ~= 200 then
      vim.notify("Error fetching journals: " .. journal_resp.status, vim.log.levels.ERROR)
      return
    end

    local journal_data = vim.fn.json_decode(journal_resp.body)
    local journal_items = search_type == "Keywords" and journal_data.message.items or { journal_data.message }

    if vim.tbl_isempty(journal_items) then
      vim.notify("No journals found", vim.log.levels.WARN)
      return
    end

    local journal_list = {}
    for _, item in ipairs(journal_items) do
      local title = item.title or "No title"
      local issn_types = {}
      if item["issn-type"] then
        for _, itype in ipairs(item["issn-type"]) do
          table.insert(issn_types, tostring(itype.type) .. ": " .. itype.value)
        end
      end
      table.insert(journal_list, title .. "::ISSN: " .. table.concat(issn_types, ", "))
    end

    prompt_select(journal_list, "Select journal:", function(selected_journal)
      if not selected_journal then
        vim.notify("No journal selected", vim.log.levels.WARN)
        return
      end

      local issn = extract_issn(selected_journal)
      if not issn then
        return
      end

      vim.notify("Selected ISSN: " .. issn, vim.log.levels.INFO)

      local article_search = vim.fn.input("Search article: ")
      if article_search == "" then
        vim.notify("No article search term provided", vim.log.levels.WARN)
        return
      end

      local cleaned_query = remove_accents(article_search)
      local encoded_query = cleaned_query:gsub(" ", "%%20")

      local articles_resp = curl.get("https://api.crossref.org/journals/" .. issn .. "/works?query=" .. encoded_query)
      if articles_resp.status ~= 200 then
        vim.notify("Error fetching articles: " .. articles_resp.status, vim.log.levels.ERROR)
        return
      end

      local articles_data = vim.fn.json_decode(articles_resp.body)
      if vim.tbl_isempty(articles_data.message.items) then
        vim.notify("No articles found", vim.log.levels.WARN)
        return
      end

      local article_list = {}
      for _, art in ipairs(articles_data.message.items) do
        local doi = art.DOI or "no DOI"
        local title = (art.title and art.title[1]) or "No title"
        local author = "No author"
        if art.author and #art.author > 0 then
          author = art.author[1].given .. " " .. art.author[1].family
        end
        local year = (art.created and art.created["date-parts"] and art.created["date-parts"][1][1]) or "No year"
        table.insert(article_list, doi .. "::" .. title .. "::" .. author .. "::" .. year)
      end

      prompt_select(article_list, "Select article:", function(selected_article)
        if not selected_article then
          vim.notify("No article selected", vim.log.levels.WARN)
          return
        end

        local doi = selected_article:match("([^:]+)")
        if not doi then
          vim.notify("DOI not found", vim.log.levels.ERROR)
          return
        end

        local details_resp = curl.get("https://api.crossref.org/works/" .. doi)
        if details_resp.status ~= 200 then
          vim.notify("Error fetching article details", vim.log.levels.ERROR)
          return
        end

        local details_data = vim.fn.json_decode(details_resp.body)
        local message = details_data.message
        local links = message.link or {}
        local pdf_url, epub_url
        for _, link in ipairs(links) do
          if link["content-type"] and link["content-type"]:find("application/pdf") then
            pdf_url = link.URL
          elseif link["content-type"] and link["content-type"]:find("application/epub%+zip") then
            epub_url = link.URL
          end
        end

        local bibtex_resp = curl.get("https://doi.org/" .. doi, { headers = { Accept = "application/x-bibtex" } })
        local bibtex = bibtex_resp.body or ""

        local format_options = { "BibTeX" }
        if pdf_url then
          table.insert(format_options, "PDF")
        end
        if epub_url then
          table.insert(format_options, "EPUB")
        end

        prompt_select(format_options, "Select format:", function(format_choice)
          if not format_choice then
            vim.notify("No format selected", vim.log.levels.WARN)
            return
          end

          if format_choice == "BibTeX" then
            local formatted_bibtex = bibtex:gsub(",%s", ",\n  ")
            local bib_file = vim.fn.expand("%:p:h") .. "/refs.bib"
            local file = io.open(bib_file, "a")
            if file then
              file:write("\n" .. formatted_bibtex .. "\n")
              file:close()
              vim.notify("BibTeX entry appended to " .. bib_file, vim.log.levels.INFO)
              vim.cmd("vsplit " .. bib_file)
            else
              vim.notify("Error opening file " .. bib_file, vim.log.levels.ERROR)
            end
          elseif format_choice == "PDF" then
            local valid_pdf_url = get_valid_url(message.link or {})
            if valid_pdf_url then
              vim.notify("Opening valid PDF link...")
              vim.fn.jobstart({ "zathura", valid_pdf_url }, { detach = true })
            else
              vim.notify("No valid PDF links available. Try searching manually.", vim.log.levels.ERROR)
            end
          elseif format_choice == "EPUB" then
            if epub_url then
              local filename = (message.title and message.title[1] or "Untitled"):gsub("%s", "_") .. ".epub"
              local filepath = os.getenv("HOME") .. "/Downloads/" .. filename
              download_file(epub_url, filepath, "EPUB")
            end
          else
            vim.notify("Invalid selection", vim.log.levels.ERROR)
          end
        end)
      end)
    end)
  end)
end

return M
