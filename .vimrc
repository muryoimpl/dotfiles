" vim-plug がインストールされていなければインストール
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.github.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

let files = [
\  "vimrc_vim-plug",
\  "vimrc_basic",
\  "vimrc_utils",
\  "vimrc_tags",
\  "vimrc_git_gutter",
\  "vimrc_lightline",
\  "vimrc_trailing-whitespace",
\  "vimrc_simplenote",
\  "vimrc_ruby",
\  "vimrc_fugitive",
\  "vimrc_ack",
\  "vimrc_lsp",
\  "vimrc_quickhl",
\  "vimrc_indentline",
\  "vimrc_vim-test",
\  "vimrc_ale",
\  "vimrc_undotree",
\  "vimrc_jsdoc",
\  "vimrc_fern",
\  "vimrc_js",
\  "vimrc_dirvish",
\  "vimrc_go",
\  "vimrc_fzf",
\]

for f in files
  exe "source" "~/.vim/".f
endfor

"カラースキーマを設定
set background=dark
colorscheme hybrid


"カーソルをハイライト
:hi Cursor ctermfg=DarkGray

set cursorline
:hi CursorLine gui=underline cterm=underline

" font
set guifont=Noto\ Mono\ Regular:h16
