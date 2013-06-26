" https://gist.github.com/728265.git
" unite-grep-quickfix {{{ 
let s:unite_grep_quickfix = { 'name': 'grep-quickfix', 'is_volatile': 1 } 
function! s:unite_grep_quickfix.gather_candidates(args, context) 
  execute printf("vimgrep /%s/jg %s", a:context.input, get(a:args, 0, "**")) 
  let l:res = [] 
  for l:val in getqflist() 
    let name = bufname(l:val.bufnr) 
    let dict = { 
          \ 'word': printf("%s|%d:%d|%s", name, l:val.lnum, l:val.col, matchstr(l:val.text, '\s*\zs.*\S')), 
          \ 'source': 'grep-quickfix', 
          \ "kind": "jump_list", 
          \ 'action__path': name, 
          \ 'action__line': l:val.lnum, 
          \ 'action__pattern': l:val.pattern 
          \} 
    call add(res, dict) 
  endfor 
 
  return l:res 
endfunction 
call unite#define_source(s:unite_grep_quickfix) 
" }}} 
