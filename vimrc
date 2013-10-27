" most of this file is from Armin Ronacher's vimrc, see
" https://github.com/mitsuhiko/dotfiles/blob/master/vim/vimrc

set nocompatible " use VIM defaults
set background=dark 
set ruler        " show cursor position all the time
set showcmd      " show (partial) command in status line
set number       " show line numbers
set showmatch    " show matching brackets
set hlsearch     " highlight search matches
set incsearch    " incremental search while typing
set ignorecase   " ignore case in search patterns
set smartcase    " .. except search pattern contains upper case char.
set backspace=indent,eol,start " proper backspace
set autoindent   " copy indent from current line to new line
set smartindent  " smart autoindenting when starting a new line
" tabs
set shiftwidth=4
set tabstop=4
set expandtab
set nocp

" pathogen
execute pathogen#infect()

" The PC is fast enough, do syntax highlight syncing from start
autocmd BufEnter * :syntax sync fromstart

" Remember cursor position
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif

" Enable hidden buffers
set hidden
"
" enable automatic title setting for terminals
set title
set titleold="Terminal"
set titlestring=%F

" python support
" " --------------
autocmd FileType python setlocal expandtab shiftwidth=4 tabstop=8 colorcolumn=99
\ formatoptions+=croq softtabstop=4 smartindent
\ cinwords=if,elif,else,for,while,try,except,finally,def,class,with
let python_highlight_all=1
let python_highlight_exceptions=0
let python_highlight_builtins=0
autocmd FileType pyrex setlocal expandtab shiftwidth=4 tabstop=8 softtabstop=4 smartindent cinwords=if,elif,else,for,while,try,except,finally,def,class,with,self
" Start python on F5
autocmd FileType python map <F5> :w<CR>:!python2.7 "%"<CR>

" OpenGL
" " ---
autocmd FileType c,cpp source ~/.vim/syntax/opengl.vim

" OpenCL 
" " ----
autocmd BufNewFile,BufRead *.cl setf opencl

" GLSL
" " ----
autocmd BufNewFile,BufRead *.frag,*.fragment,*.vert,*.vertex,*.shader,*.glsl
setlocal ft=glsl
autocmd FileType glsl setlocal expandtab shiftwidth=2 tabstop=2 softtabstop=2

" " Verilog
" " -------
autocmd FileType verilog setlocal expandtab shiftwidth=2 tabstop=8 softtabstop=2

" " HTML
" " ----
autocmd FileType html setlocal expandtab shiftwidth=2 tabstop=2 softtabstop=2

" " CSS
" " ---
autocmd FileType css setlocal expandtab shiftwidth=4 tabstop=4 softtabstop=4

" " jQuery
" "
au BufRead,BufNewFile jquery.*.js set ft=javascript syntax=jquery

" " Coffee
" "
au BufRead,BufNewFile coffee setlocal shiftwidth=4 tabstop=4 softtabstop=4 expandtab smartindent

" " Java
" " ----
autocmd FileType java setlocal shiftwidth=4 tabstop=4 softtabstop=4 expandtab

" " rst
" " ---
autocmd BufNewFile,BufRead *.txt setlocal ft=rst
autocmd FileType rst setlocal expandtab shiftwidth=4 tabstop=4 softtabstop=4 \ formatoptions+=nqt textwidth=74

" " C#
autocmd FileType cs setlocal tabstop=8 softtabstop=4 shiftwidth=4 expandtab

" " C/Obj-C/C++
autocmd FileType c setlocal tabstop=4 softtabstop=4 shiftwidth=4 expandtab colorcolumn=99
autocmd FileType cl setlocal tabstop=4 softtabstop=4 shiftwidth=4 expandtab colorcolumn=99
autocmd FileType cpp setlocal tabstop=4 softtabstop=4 shiftwidth=4 expandtab colorcolumn=99
autocmd FileType objc setlocal tabstop=4 softtabstop=4 shiftwidth=4 expandtab colorcolumn=99
let c_no_curly_error=1

" Erlang support
" --------------
autocmd FileType erlang setlocal expandtab shiftwidth=2 tabstop=8 softtabstop=2
autocmd BufNewFile,BufRead rebar.config setlocal ft=erlang

" " vim
" " ---
autocmd FileType vim setlocal expandtab shiftwidth=2 tabstop=8 softtabstop=2

" " Javascript
" " ----------
autocmd FileType javascript setlocal expandtab shiftwidth=2 tabstop=2 softtabstop=2 colorcolumn=99
autocmd BufNewFile,BufRead *.json setlocal ft=javascript
let javascript_enable_domhtmlcss=1

" rust
" ----
autocmd FileType rust setlocal expandtab shiftwidth=4 tabstop=8 softtabstop=4
autocmd FileType rust setlocal commentstring=//\ %s

" " D
" " -
autocmd FileType d setlocal expandtab shiftwidth=4 tabstop=8 softtabstop=4

" " cmake support
" " -------------
autocmd BufNewFile,BufRead CMakeLists.txt setlocal ft=cmake

" uniform colors between different terminals
set t_Co=8

" haskell
let hs_highlight_boolean=1
let hs_highlight_types=1
let hs_highlight_debug=1

" latex
let g:tex_flavor='latex'


" this is mostly a matter of taste. but LaTeX looks good with just a bit
" " of indentation.
set sw=2
" " TIP: if you write your \label's as \label{fig:something}, then if you
" " type in \ref{fig: and press <C-n> you will automatically cycle through
" " all the figure labels. Very useful!
set iskeyword+=:
set mouse=a

" remove scrollbar from gvim
set guioptions+=lrb
set guioptions-=lrb


filetype plugin on
filetype indent on
syntax on
:colors distinguished

" fontsize
if has('gui_running')
  set guifont=Ubuntu\ Mono\ 12
endif

