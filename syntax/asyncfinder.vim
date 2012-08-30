" asyncfinder.vim - simple asynchronous fuzzy file finder for vim
" Maintainer: Dmitry "troydm" Geurkov <d.geurkov@gmail.com>
" Version: 0.1
" Description: asyncfinder.vim is a simple asychronous fuzzy file finder
" that searches for files in background without making you frustuated 
" Last Change: 30 August, 2012
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

syntax match AsyncFinderTitle /^Type your pattern$/ 
syntax match AsyncFinderTitle /^Searching for files\.*$/
syntax match AsyncFinderPattern /^>.*$/
syntax match AsyncFinderDir /^d .*$/
syntax match AsyncFinderFile /^f .*$/
syntax match AsyncFinderBuffer /^b .*$/

highlight default link AsyncFinderTitle    Comment
highlight default link AsyncFinderPattern  Title
highlight default link AsyncFinderDir      Identifier
highlight default link AsyncFinderFile     Character
highlight default link AsyncFinderBuffer   String

let b:current_syntax = "asyncfinder"

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: ts=8 sw=4 sts=4 et foldenable foldmethod=marker foldcolumn=1
