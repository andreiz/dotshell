syntax on
filetype plugin indent on

" Airline
set laststatus=2
let g:airline#extensions#tabline#enabled=1
let g:airline_powerline_fonts=1

" Everforest theme
set termguicolors
set background=dark
packadd! everforest
"let g:everforest_background = 'hard'
let g:airline_theme = 'everforest'
let g:everforest_cursor = 'auto'
colorscheme everforest

" Whitespace
set expandtab
set list
set listchars=tab:»·,trail:·,nbsp:␣,extends:»,precedes:«

" Toggle whitespace symbols
nnoremap <leader>l :set list!<CR>
