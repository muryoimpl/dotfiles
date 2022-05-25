" vim-plug がインストールされていなければインストール
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.github.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

source ~/.vim/vimrc_vim-plug
source ~/.vim/vimrc_basic
source ~/.vim/vimrc_utils
source ~/.vim/vimrc_tags
source ~/.vim/vimrc_3way_diff
source ~/.vim/vimrc_git_gutter
source ~/.vim/vimrc_lightline
source ~/.vim/vimrc_trailing-whitespace
source ~/.vim/vimrc_simplenote
source ~/.vim/vimrc_ruby
source ~/.vim/vimrc_fugitive
source ~/.vim/vimrc_ack
source ~/.vim/vimrc_lsp
source ~/.vim/vimrc_quickhl
source ~/.vim/vimrc_indentline
source ~/.vim/vimrc_vim-test
source ~/.vim/vimrc_ale
source ~/.vim/vimrc_undotree
source ~/.vim/vimrc_jsdoc
source ~/.vim/vimrc_fern
source ~/.vim/vimrc_js
source ~/.vim/vimrc_dirvish
source ~/.vim/vimrc_go
source ~/.vim/vimrc_fzf

"カラースキーマを設定
set background=dark
colorscheme hybrid


"カーソルをハイライト
:hi Cursor ctermfg=DarkGray

set cursorline
:hi CursorLine gui=underline cterm=underline

" font
set guifont=Noto\ Mono\ Regular:h16
