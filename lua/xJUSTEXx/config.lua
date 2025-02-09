local M = {}

local function ensure_dir_exists(dir)
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

local function expand_path(path)
  return path:gsub("^~", vim.fn.expand("~"))
end

local function set_default_config()
  return {
    project_dirs = {
      vim.fn.expand("$HOME") .. "/Documents/xJUSTEXx/Articles",
      vim.fn.expand("$HOME") .. "/Documents/xJUSTEXx/Research",
    },
    tex_templates = {
      article = {
        name = "Article",
        content = [[
\documentclass{article}


\begin{document}

\title{Title}
\author{Author}
\date{\today}
\maketitle


\section{Introduction}

This is an article template.


\end{document}
      ]],
      },
      book = {
        name = "Book",
        content = [[
\documentclass{book}


\begin{document}

\title{Title}
\author{Author}
\date{\today}
\maketitle


\chapter{Introduction}

This is a book template.


\end{document}
      ]],
      },
      presentation = {
        name = "Presentation",
        content = [[
\documentclass{beamer}


\begin{document}
\title{Title}
\author{Author}
\date{\today}
\frame{\titlepage}


\begin{frame}
\frametitle{Introduction}

This is a presentation template.

\end{frame}


\end{document}
      ]],
      },
    },
    justfile_content = [[
main_file := "%s.tex"

lualatex:
  @latexmk -lualatex -interaction=nonstopmode -synctex=-1 {{main_file}}

pdflatex:
  @latexmk -pdf -interaction=nonstopmode -synctex=-1 {{main_file}} 

pdfxe:
  @latexmk -pdfxe -interaction=nonstopmode -synctex=-1 {{main_file}} 

cleanmain:
  @latexmk -c {{main_file}}

cleanall:
  @latexmk -c
]],
  }
end

M.options = {}

function M.setup(opts)
  if opts and opts.project_dirs then
    for i, dir in ipairs(opts.project_dirs) do
      opts.project_dirs[i] = expand_path(dir)
    end
  end

  M.options = vim.tbl_deep_extend("force", set_default_config(), opts or {})

  if not opts or not opts.project_dirs then
    for _, dir in ipairs(M.options.project_dirs) do
      ensure_dir_exists(dir)
    end
  end
end

function M.set_file_justfile(project_name)
  return string.format(M.options.justfile_content, project_name)
end

return M
