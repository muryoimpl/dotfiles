" fzf
let g:fzf_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

" - down / up / left / right
let g:fzf_layout = { 'down': '~50%' }

let $FZF_DEFAULT_OPTS="--layout=reverse"
let $FZF_DEFAULT_COMMAND="ag -l --hidden --skip-vcs-ignores --ignore-dir=.git"

" Agf <PATTERN> キー入力はファイル名をフィルタする
command! -bang -nargs=* Agf
  \ call fzf#vim#grep(
  \   'ag --column --color --hidden --ignore-dir=.git --skip-vcs-ignores '.shellescape(<q-args>), 1,
  \   fzf#vim#with_preview(), <bang>0)

" Ag <PATTERN> キー入力は内容をフィルタする
command! -bang -nargs=* Ag
  \ call fzf#vim#grep(
  \   'ag --column --color --hidden --ignore-dir=.git --skip-vcs-ignores '.shellescape(<q-args>), 1,
  \   fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}), <bang>0)

" shortcut
nnoremap <silent> <space>f :Files<CR>
nnoremap <silent> <space>g :GFiles<CR>
nnoremap <silent> <space>G :GFiles?<CR>
nnoremap <silent> <space>b :Buffers<CR>
nnoremap <silent> <space>h :History<CR>
nnoremap <silent> <space>l :Lines<CR>
