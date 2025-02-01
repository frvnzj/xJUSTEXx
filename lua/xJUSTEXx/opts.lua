local M = {}

M.default_content = {
  project_dirs = {
    vim.fn.expand("$HOME") .. "/Documents/Articles",
    vim.fn.expand("$HOME") .. "/Documents/Research",
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

function M.set_file_justfile(project_name)
  return string.format(M.default_content.justfile_content, project_name)
end

return M
