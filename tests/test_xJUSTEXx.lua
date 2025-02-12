---@diagnostic disable: unused-local, duplicate-set-field

package.path = package.path .. ";../lua/?.lua;../lua/?/init.lua"

local config = require("xJUSTEXx.config")
local xISBNx = require("xJUSTEXx.xISBNx")
local plenary_curl = require("plenary.curl")

local original_vim_fn_mkdir = vim.fn.mkdir

describe("xJUSTEXx plugin", function()
  before_each(function()
    vim.fn.mkdir = function(dir, mode)
      return true
    end
    config.setup({})
  end)

  after_each(function()
    vim.fn.mkdir = original_vim_fn_mkdir
  end)

  describe("Configuración", function()
    it("genera el contenido del justfile con el nombre del proyecto", function()
      local project_name = "testproject"
      local justfile = config.set_file_justfile(project_name)
      assert.is_true(justfile:find(project_name .. "%.tex") ~= nil)
    end)

    it("expande correctamente las rutas de project_dirs con tilde", function()
      local opts = { project_dirs = { "~/mydir" } }
      config.setup(opts)
      local expected = vim.fn.expand("~") .. "/mydir"
      assert.are.same(expected, config.options.project_dirs[1])
    end)
  end)

  describe("Módulo xISBNx", function()
    local original_input, original_curl_get, original_buf_set_keymap
    local original_expand, original_io_open
    local captured_callback

    before_each(function()
      original_input = vim.fn.input
      vim.fn.input = function(_)
        return "8474324211"
      end

      original_curl_get = plenary_curl.get
      plenary_curl.get = function(url, opts)
        assert.is_true(url:find("8474324211") ~= nil)
        return {
          status = 200,
          body = vim.fn.json_encode({
            ["ISBN:8474324211"] = {
              title = "Test Book",
              authors = { { name = "Test Author" } },
              subtitle = "Test Subtitle",
              publishers = { { name = "Test Publisher" } },
              publish_date = "2025",
              number_of_pages = 123,
              publish_places = { { name = "Test City" } },
            },
          }),
        }
      end

      original_buf_set_keymap = vim.api.nvim_buf_set_keymap
      captured_callback = nil
      vim.api.nvim_buf_set_keymap = function(buf, mode, lhs, rhs, opts)
        if mode == "n" and lhs == "<CR>" and opts.callback then
          captured_callback = opts.callback
        end
        return original_buf_set_keymap(buf, mode, lhs, rhs, opts)
      end

      original_expand = vim.fn.expand
      vim.fn.expand = function(arg)
        if arg == "%:p:h" then
          return "/tmp"
        end
        return original_expand(arg)
      end

      original_io_open = io.open
      io.open = function(filename, mode)
        assert.are.equal("/tmp/referencias.bib", filename)
        return {
          write = function(self, data)
            _G.__file_written = true
            _G.__written_data = data
          end,
          close = function() end,
        }
      end
      _G.__file_written = false
      _G.__written_data = ""
    end)

    after_each(function()
      vim.fn.input = original_input
      plenary_curl.get = original_curl_get
      vim.api.nvim_buf_set_keymap = original_buf_set_keymap
      vim.fn.expand = original_expand
      io.open = original_io_open
    end)

    it("genera y escribe la entrada BibTeX para un ISBN válido", function()
      xISBNx.xSEARCH_ISBNx()

      if captured_callback then
        captured_callback()
      end

      assert.is_true(_G.__file_written, "No se ejecutó la escritura de la entrada BibTeX")
      assert.is_true(_G.__written_data:find("@book{") ~= nil, "La entrada BibTeX no contiene '@book{'")
      assert.is_true(_G.__written_data:find("Test Book") ~= nil, "La entrada BibTeX no contiene el título 'Test Book'")
    end)
  end)
end)
