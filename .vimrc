"neobundleの設定
source ~/.vim/vimrc_bundle
"基本設定
source ~/.vim/vimrc_basic
"plugins_unite
source ~/.vim/vimrc_plugins_unite
"plugins_completion
source ~/.vim/vimrc_plugins_completion
"plugins_quickrun
source ~/.vim/vimrc_plugins_quickrun
"plugins
source ~/.vim/vimrc_plugins_others
"tab
source ~/.vim/vimrc_tab
"statusline
source ~/.vim/vimrc_status
"keybindの設定とか細々したやつ
source ~/.vim/vimrc_utils
"tags
source ~/.vim/vimrc_tags
"for ruby/rails
source ~/.vim/vimrc_for_ruby_with_unite
"for rbenv-ctags
source ~/.vim/vimrc_rbenv_ctags
"for vim 3 way diff
source ~/.vim/vimrc_3way_diff
"for gitv
source ~/.vim/vimrc_gitv
"for git-gutter
source ~/.vim/vimrc_git_gutter


"カラースキーマを設定
colorscheme Tomorrow-Night
"colorscheme darkblue

"カーソルをハイライト
:hi Cursor ctermfg=DarkGray

set cursorline
:hi CursorLine gui=underline cterm=underline
:hi CursorLine ctermbg=DarkBlue guibg=DarkBlue

" font
set guifont=Ricty:h16
