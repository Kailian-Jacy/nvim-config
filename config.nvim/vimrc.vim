""" lua require("main")
"" use autocmd to restore the cursor style.
"" built in terminal cursor style is currently an issue 
""  https://github.com/neovim/neovim/issues/3681
au VimLeave * set guicursor=a:ver10-blinkon1

""" Get the rull path
""" 1 <C-g>

""" Main Configurations
filetype plugin indent on
" set autochdir
" tab
""" set expandtab
""" set tabstop=4 softtabstop=4 shiftwidth=0 smarttab autoindent
set softtabstop=4 smarttab autoindent
set incsearch ignorecase smartcase hlsearch
set wildmode=longest,list,full wildmenu

""" not showing bottom line.
""" set laststatus=0 showcmd showmode
set showbreak=↪\
set list listchars=tab:→\ ,nbsp:␣,trail:•,extends:⟩,precedes:⟨
set wrap breakindent
""" set encoding=utf-8
set textwidth=0
set hidden
set title
""" Only highlight the current line number
"set cursorline
"set cursorlineopt=number
set linebreak
set smoothscroll

nnoremap <expr> k (v:count == 0 ? 'gk' : 'k')
nnoremap <expr> j (v:count == 0 ? 'gj' : 'j')

"highlight WinSeparator guifg=#565f89

" using range-aware function
function! QFdelete(bufnr) range
    " get current qflist
    let l:qfl = getqflist()
    " no need for filter() and such; just drop the items in range
    call remove(l:qfl, a:firstline - 1, a:lastline - 1)
    " replace items in the current list, do not make a new copy of it;
    " this also preserves the list title
    call setqflist([], 'r', {'items': l:qfl})
    " restore current line
    call setpos('.', [a:bufnr, a:firstline, 1, 0])
endfunction

" using buffer-local mappings
" note: still have to check &bt value to filter out `:e quickfix` and such
augroup QFList | au!
    autocmd BufWinEnter quickfix if &bt ==# 'quickfix'
    autocmd BufWinEnter quickfix    nnoremap <silent><buffer>dd :call QFdelete(bufnr())<CR>
    autocmd BufWinEnter quickfix    vnoremap <silent><buffer>d  :call QFdelete(bufnr())<CR>
    autocmd BufWinEnter quickfix endif
augroup end

autocmd ColorScheme * highlight CursorLineNr cterm=bold term=bold gui=bold
set termguicolors

""" Filetype-Specific Configurations

" HTML, XML, Jinja
autocmd FileType html setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType css setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType xml setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType json setlocal shiftwidth=2 tabstop=2 softtabstop=2

" Markdown and Journal
autocmd FileType md setlocal shiftwidth=4 tabstop=4 softtabstop=4
autocmd FileType journal setlocal shiftwidth=2 tabstop=2 softtabstop=2

" Functions and autocmds to run whenever changing colorschemes
""" function! TransparentBackground()
"""     highlight Normal guibg=NONE ctermbg=NONE
"""     highlight LineNr guibg=NONE ctermbg=NONE
"""     set fillchars+=vert:\│
"""     highlight WinSeparator gui=NONE guibg=NONE guifg=#444444 cterm=NONE ctermbg=NONE ctermfg=gray
"""     highlight VertSplit gui=NONE guibg=NONE guifg=#444444 cterm=NONE ctermbg=NONE ctermfg=gray
""" endfunction

""" Core plugin configuration (vim)

""" " Treesitter
""" augroup DraculaTreesitterSourcingFix
"""     autocmd!
"""     autocmd ColorScheme dracula runtime after/plugin/dracula.vim
"""     syntax on
""" augroup end
""" 
""" " nvim-cmp
""" set completeopt=menu,menuone,noselect
""" 
""" " signify
""" let g:signify_sign_add = '│'
""" let g:signify_sign_delete = '│'
""" let g:signify_sign_change = '│'
""" hi DiffDelete guifg=#ff5555 guibg=none
""" 
""" " indentLine
""" let g:indentLine_char = '▏'
""" let g:indentLine_defaultGroup = 'NonText'
""" " Disable indentLine from concealing json and markdown syntax (e.g. ```)
""" let g:vim_json_syntax_conceal = 0
""" let g:vim_markdown_conceal = 0
""" let g:vim_markdown_conceal_code_blocks = 0
""" 
""" " FixCursorHold for better performance
""" let g:cursorhold_updatetime = 100
""" 
""" " context.vim
""" let g:context_nvim_no_redraw = 1
""" 
""" " Neovim :Terminal
""" tmap <Esc> <C-\><C-n>
""" tmap <C-w> <Esc><C-w>
""" "tmap <C-d> <Esc>:q<CR>
""" autocmd BufWinEnter,WinEnter term://* startinsert
""" autocmd BufLeave term://* stopinsert
""" 
""" " Python
""" let g:python3_host_prog = '~/.config/nvim/env/bin/python3'
""" let g:pydocstring_doq_path = '~/.config/nvim/env/bin/doq'
""" 
""" """ Core plugin configuration (lua)
""" lua << EOF
""" servers = {
"""     'pyright',
"""     --'tsserver', -- uncomment for typescript. See https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md for other language servers
""" }
""" require('treesitter-config')
""" require('nvim-cmp-config')
""" require('lspconfig-config')
""" require('telescope-config')
""" require('lualine-config')
""" require('nvim-tree-config')
""" require('diagnostics')
""" EOF
""" 
""" """ Custom Functions
""" 
""" " Trim Whitespaces
""" function! TrimWhitespace()
"""     let l:save = winsaveview()
"""     %s/\\\@<!\s\+$//e
"""     call winrestview(l:save)
""" endfunction
""" 
""" """ Custom Mappings (vim) (lua custom mappings are within individual lua config files)
""" 

""" Hopping
"nnoremap <silent> <leader><leader> :HopWord<CR>
"nnoremap <silent> <leader>j :HopVerticalAC<CR>
"nnoremap <silent> <leader>k :HopVerticalBC<CR>
"vnoremap <silent> <leader><leader> :HopWord<CR>
"vnoremap <silent> <leader>j :HopVerticalAC<CR>
"vnoremap <silent> <leader>k :HopVerticalBC<CR>

""" nmap \ <leader>q
""" nmap <leader>r :so ~/.config/nvim/init.vim<CR>
""" nmap <leader>t :call TrimWhitespace()<CR>
""" xmap <leader>a gaip*
""" nmap <leader>a gaip*
""" nmap <leader>h :RainbowParentheses!!<CR>
""" nmap <leader>j :set filetype=journal<CR>
""" nmap <leader>k :ColorToggle<CR>
""" nmap <leader>l :Limelight!!<CR>
""" xmap <leader>l :Limelight!!<CR>
""" nmap <silent> <leader><leader> :noh<CR>

""" H and L are switching between tabs.
"nmap <silent> <Tab><Tab> :bnext<CR>
"nmap <silent> <S-Tab> :bprevious<CR>
"
""" nmap <leader>$s <C-w>s<C-w>j:terminal<CR>:set nonumber<CR><S-a>
""" nmap <leader>$v <C-w>v<C-w>l:terminal<CR>:set nonumber<CR><S-a>
""" 
""" " Python
""" autocmd Filetype python nmap <leader>d <Plug>(pydocstring)
""" autocmd FileType python nmap <leader>p :Black<CR>
""" 
""" " Solidity (requires: npm install --save-dev prettier prettier-plugin-solidity)
""" autocmd Filetype solidity nmap <leader>p :0,$!npx prettier %<CR>
""" 

""" Text matching in workspace and current buffer.
""" nnoremap <leader>fc <cmd>Telescope command_history<cr> """ update: replaced with <leader>: and <leader>sc

""" nnoremap <leader>/ <cmd>Telescope current_bufer_fuzzy_find<cr>
""" vnoremap <leader>/ "zy:Telescope current_buffer_fuzzy_find default_text=<C-r>z<cr>

""" keymap finding has been replaced with <leader>sk
""" nnoremap <leader>fk <cmd>Telescope keymaps<cr>

""" Diagnostics
nnoremap <leader>le <cmd>Telescope diagnostics severity=1<cr> 
nnoremap <leader>lw <cmd>Telescope diagnostics severity=2<cr>
nnoremap gh <cmd>vim.lsp.buf.hover()<cr>

""" Debugging related
nnoremap <leader>sd <cmd>Telescope dap commands<cr>
nnoremap <leader>df <cmd>Telescope dap configurations<cr>
nnoremap <leader>db <cmd>Telescope dap list_breakpoints<cr>
nnoremap <leader>dv <cmd>Telescope dap variables<cr>
nnoremap <leader>df <cmd>Telescope dap frames<cr>

""" Noise history report.
""" <leader>snt noice telescope<cr>
""" <leader>snl last noice<cr>
""" <leader>sna all noice<cr>

""" Moving lines 
"nnoremap <silent> <esc>k :move-2<CR>==
"nnoremap <silent> <esc>j :move+<CR>==
"vnoremap <silent> <esc>j :m '>+1<cr>gv=gv
"vnoremap <silent> <esc>k :m '<-2<cr>gv=gv

