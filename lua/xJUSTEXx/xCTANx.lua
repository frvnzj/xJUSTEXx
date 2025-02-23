local M = {}

local curl = require("plenary.curl")
local ctan_mirror = "https://mirrors.mit.edu/CTAN"

local function build_full_url(doc_path)
  return ctan_mirror .. "/" .. doc_path:gsub("^ctan:", ""):gsub("^/+", ""):gsub(" ", "%%20")
end

local function fetch_json(url)
  local response = curl.get(url)
  if not response or response.status ~= 200 then
    vim.notify("Error fetching data: " .. url, vim.log.levels.ERROR)
    return nil
  end
  return vim.fn.json_decode(response.body)
end

local function open_document(url, path)
  local ext = path:match("%.([%a%d]+)$") or ""
  local is_readme = path:match("README")

  if ext == "pdf" then
    vim.fn.jobstart({ "zathura", url }, { detach = true })
    vim.notify("URL: " .. url, vim.log.levels.INFO)
  elseif ext == "html" then
    vim.fn.jobstart({ "xdg-open", url }, { detach = true })
  elseif ext == "md" or ext == "txt" or is_readme then
    local tmp_dir = vim.fn.stdpath("cache") .. "/ctan_docs/"
    local filename = path:match("([^/]+)$"):gsub("%%20", "_")
    local tmp_file = tmp_dir .. filename

    if not filename:match("%.") then
      tmp_file = tmp_file .. ".txt"
    end

    vim.fn.mkdir(tmp_dir, "p")
    vim.fn.system(string.format('curl -sSL -o "%s" "%s"', tmp_file, url))

    if vim.fn.filereadable(tmp_file) == 1 then
      vim.schedule(function()
        vim.cmd("view " .. vim.fn.fnameescape(tmp_file))
      end)
    else
      vim.notify("Error downloading: " .. url, vim.log.levels.ERROR)
    end
  else
    vim.notify("Format not supported: " .. ext, vim.log.levels.WARN)
  end
end

function M.xCTANSEARCHx()
  local packages = fetch_json("https://www.ctan.org/json/2.0/packages")
  if not packages then
    return
  end

  local package_list = vim.tbl_map(function(pkg)
    return { display = string.format("%s - %s", pkg.key, pkg.caption), key = pkg.key }
  end, packages)

  vim.ui.select(package_list, {
    prompt = "Package  > ",
    format_item = function(item)
      return " " .. item.display
    end,
  }, function(selected)
    if not selected then
      return
    end

    local pkg_data = fetch_json("https://www.ctan.org/json/2.0/pkg/" .. selected.key)
    if not pkg_data or not pkg_data.documentation then
      return
    end

    local doc_list = vim.tbl_map(function(doc)
      return { display = string.format("%s - %s", doc.details, doc.href), href = doc.href }
    end, pkg_data.documentation)

    vim.ui.select(doc_list, {
      prompt = selected.key .. " Docs  > ",
      format_item = function(item)
        local icons = { pdf = "󰈦 ", md = " ", html = " ", txt = "󰈙 " }
        local ext = item.href:match("%.([%a%d]+)$") or ""
        return (icons[ext] or "󰈙 ") .. item.display
      end,
    }, function(doc_selected)
      if not doc_selected then
        return
      end

      open_document(build_full_url(doc_selected.href), doc_selected.href)
    end)
  end)
end

return M
