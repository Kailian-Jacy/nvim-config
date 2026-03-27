""" Restore cursor style on exit.
au VimLeave * set guicursor=a:ver10-blinkon1

""" Main Configurations
filetype plugin indent on
set softtabstop=4 smarttab autoindent
set incsearch ignorecase smartcase hlsearch
set wildmode=longest,list,full wildmenu

set showbreak=↪\
set list listchars=tab:→\ ,nbsp:␣,trail:•,extends:⟩,precedes:⟨
set wrap breakindent
set textwidth=0
set hidden
set title
set linebreak
set smoothscroll

nnoremap <expr> k (v:count == 0 ? 'gk' : 'k')
nnoremap <expr> j (v:count == 0 ? 'gj' : 'j')

" Quickfix list: delete entries with dd/d in visual mode
function! QFdelete(bufnr) range
    let l:qfl = getqflist()
    call remove(l:qfl, a:firstline - 1, a:lastline - 1)
    call setqflist([], 'r', {'items': l:qfl})
    call setpos('.', [a:bufnr, a:firstline, 1, 0])
endfunction

augroup QFList | au!
    autocmd BufWinEnter quickfix if &bt ==# 'quickfix'
    autocmd BufWinEnter quickfix    nnoremap <silent><buffer>dd :call QFdelete(bufnr())<CR>
    autocmd BufWinEnter quickfix    vnoremap <silent><buffer>d  :call QFdelete(bufnr())<CR>
    autocmd BufWinEnter quickfix endif
augroup end

autocmd ColorScheme * highlight CursorLineNr cterm=bold term=bold gui=bold
set termguicolors

""" Filetype-Specific Configurations
autocmd FileType html setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType css setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType xml setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType json setlocal shiftwidth=2 tabstop=2 softtabstop=2
autocmd FileType md setlocal shiftwidth=4 tabstop=4 softtabstop=4
autocmd FileType journal setlocal shiftwidth=2 tabstop=2 softtabstop=2

""" Diagnostics (Telescope-based)
nnoremap <leader>le <cmd>Telescope diagnostics severity=1<cr>
nnoremap <leader>lw <cmd>Telescope diagnostics severity=2<cr>
nnoremap gh <cmd>lua vim.lsp.buf.hover()<cr>

""" Debugging related
nnoremap <leader>sd <cmd>Telescope dap commands<cr>
nnoremap <leader>df <cmd>Telescope dap configurations<cr>
nnoremap <leader>db <cmd>Telescope dap list_breakpoints<cr>
nnoremap <leader>dv <cmd>Telescope dap variables<cr>
nnoremap <leader>df <cmd>Telescope dap frames<cr>
