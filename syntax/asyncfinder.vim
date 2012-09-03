" asyncfinder.vim - simple asynchronous fuzzy file finder for vim
" Maintainer: Dmitry "troydm" Geurkov <d.geurkov@gmail.com>
" Version: 0.2.5
" Description: asyncfinder.vim is a simple asychronous fuzzy file finder
" that searches for files in background without making you frustuated 
" Last Change: 3 September, 2012
" License: Vim License (see :help license)
" Website: https://github.com/troydm/asyncfinder.vim
"
" See asyncfinder.vim for help.  This can be accessed by doing:
" :help asyncfinder

if exists("b:current_syntax")
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

syntax match AsyncFinderTitle /^Type your pattern/ 
syntax match AsyncFinderTitle /^Searching files\.*/
syntax match AsyncFinderTitle /mode: /
syntax match AsyncFinderTitle /cwd: /
syntax match AsyncFinderPattern /^>.*$/
syntax match AsyncFinderDir /^d .*$/
syntax match AsyncFinderFile /^f /
syntax match AsyncFinderFile /^\zsf .*\/\ze[^\/]\+$/
syntax match AsyncFinderMruFile /^m /
syntax match AsyncFinderMruFile /^\zsm .*\/\ze[^\/]\+$/
syntax match AsyncFinderBuffer /^b /
syntax match AsyncFinderBuffer /^\zsb .*\/\ze[^\/]\+$/
syntax match AsyncFinderFileName /[^ \/]\+$/

highlight default link AsyncFinderTitle    Comment
highlight default link AsyncFinderPattern  Title
highlight default link AsyncFinderDir      Identifier
highlight default link AsyncFinderFile     Character
highlight default link AsyncFinderMruFile  Type
highlight default link AsyncFinderBuffer   String
highlight default link AsyncFinderFileName Normal

let b:current_syntax = "asyncfinder"

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: ts=8 sw=4 sts=4 et foldenable foldmethod=marker foldcolumn=1
