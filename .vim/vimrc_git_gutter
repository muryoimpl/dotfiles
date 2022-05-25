set signcolumn=yes
set updatetime=100

let g:gitgutter_signs = 1
let g:gitgutter_highlight_linenrs = 1
let g:gitgutter_realtime = 1
let g:gitgutter_max_signs = -1
let g:gitgutter_show_msg_on_hunk_jumping = 1

" cycle
function! GitGutterNextHunkCycle()
  let line = line('.')
  silent! GitGutterNextHunk
  if line('.') == line
    1
    GitGutterNextHunk
  endif
endfunction

nnoremap <Space>gt :<C-u>GitGutterToggle<Enter>

nmap <Space>] <Plug>(GitGutterNextHunk)
nmap <Space>[ <Plug>(GitGutterPrevHunk)
nmap <silent> <Space>n :call GitGutterNextHunkCycle()<CR>
