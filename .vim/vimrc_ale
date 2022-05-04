" Set this variable to 1 to fix files when you save them.
let g:ale_fix_on_save = 1
let g:ale_lint_on_insert_leave = 1
let g:ale_lint_on_enter = 0
let g:ale_lint_on_text_change = 0

let g:ale_set_quickfix = 1
let g:ale_set_loclist = 0
let g:ale_open_list = 1
let g:alg_keep_list_window_open = 0
let g:ale_list_window_size = 10

let g:ale_sign_column_always = 1
let g:ale_sign_error = '=='
let g:ale_sign_warning = '--'
let g:ale_completion_enabled = 1

nmap <silent> <C-k> <Plug>(ale_previous_wrap)
nmap <silent> <C-j> <Plug>(ale_next_wrap)

" vim-lsp-ale
let g:ale_linters = {
    \   'ruby': ['rubocop'],
    \   'javascript': ['prettier'],
    \   'javascriptreact': ['prettier'],
    \   'go': ['gofmt', 'goimports'],
    \ }

let g:ale_fixers = {
    \   'ruby': ['rubocop'],
    \   'javascript': ['prettier', 'eslint'],
    \   'javascriptreact': ['prettier', 'eslint'],
    \   'go': ['gofmt', 'goimports'],
    \ }

function! s:set_ale_ruby_rubocop_executable()
  let b:ale_ruby_rubocop_executable = 'bundle'
endfunction

augroup my_ale_ruby_rubocop_setting
  au!
  au FileType ruby :call s:set_ale_ruby_rubocop_executable()
augroup END
