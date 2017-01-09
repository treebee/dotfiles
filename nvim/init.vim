
call plug#begin('~/.local/share/nvim/plugged')

Plug 'mhinz/vim-grepper'

Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }

Plug 'ervandew/supertab'

Plug 'davidhalter/jedi-vim'

Plug 'slashmili/alchemist.vim'
Plug 'elixir-lang/vim-elixir'

Plug 'pangloss/vim-javascript'

" color schemes
Plug 'agude/vim-eldar'


" Initialize plugin system
call plug#end()

filetype plugin indent on

""""""" Jedi-VIM """""""
" Don't mess up undo history
let g:jedi#show_call_signatures = "0"


""""""" SuperTab configuration """""""
"let g:SuperTabDefaultCompletionType = "<c-x><c-u>"
function! Completefunc(findstart, base)
    return "\<c-x>\<c-p>"
endfunction

""""""" General coding stuff """""""
" Highlight 80th column
set colorcolumn=80
" Always show status bar
set laststatus=2
" Let plugins show effects after 500ms, not 4s
set updatetime=500
" Disable mouse click to go to position
set mouse-=a
" Don't let autocomplete affect usual typing habits
set completeopt=menuone,preview,noinsert

set number
set softtabstop=4
set tabstop=4
set shiftwidth=4
set expandtab

:colors eldar

let g:python_host_prog = '/usr/bin/python2'
let g:python3_host_prog = '/usr/bin/python'


"""""""" Language Specific Behaviour """"""""
autocmd FileType javascript setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType jsx setlocal shiftwidth=2 tabstop=2 softtabstop=2 
