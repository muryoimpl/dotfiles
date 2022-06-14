# setup zplugin.zsh
if [ -e ~/.zinit/bin/zinit.zsh ]; then
  source ~/.zinit/bin/zinit.zsh
else
  source ~/.local/share/zinit/zinit.git/zinit.zsh
fi
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

############################################
# zsh plugins
############################################
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting
zinit load zsh-users/zsh-completions

export FZF_DEFAULT_OPTS='--no-height --no-reverse'
export FZF_CTRL_T_OPTS="--preview '(highlight -O ansi -l {} 2> /dev/null || cat {} || tree -C {}) 2> /dev/null | head -200'"
zinit ice from"gh-r" as"program"
zinit load junegunn/fzf-bin

export FZF_TMUX=1
zinit ice as:command pick"bin/fzf-tmux" multisrc"shell/key-bindings.zsh shell/completion.zsh"
zinit light "junegunn/fzf"

zinit ice as"completion"
zinit snippet https://github.com/docker/cli/blob/master/contrib/completion/zsh/_docker

zinit light "chrissicool/zsh-256color"

zinit ice as:command src"manydots-magic"
zinit light "knu/zsh-manydots-magic"

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk
