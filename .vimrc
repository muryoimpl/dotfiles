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
source ~/.vim/vimrc_ctrlp
source ~/.vim/vimrc_syntastic
source ~/.vim/vimrc_trailing-whitespace
source ~/.vim/vimrc_simplenote
source ~/.vim/vimrc_ruby
source ~/.vim/vimrc_fugitive
source ~/.vim/vimrc_ack
source ~/.vim/vimrc_lsp

"カラースキーマを設定
set background=dark
colorscheme hybrid


"カーソルをハイライト
:hi Cursor ctermfg=DarkGray

set cursorline
:hi CursorLine gui=underline cterm=underline

" font
set guifont=Noto\ Mono\ Regular:h16
