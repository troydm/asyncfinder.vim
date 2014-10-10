" asyncfinder.vim - simple asynchronous fuzzy file finder for vim
" Maintainer: Dmitry "troydm" Geurkov <d.geurkov@gmail.com>
" Version: 0.2.7
" Description: asyncfinder.vim is a simple asychronous fuzzy file finder
" that searches for files in background without making you frustuated 
" Last Change: 10 October, 2014
" License: Vim License (see :help license)
" Website: https://github.com/troydm/asyncfinder.vim
"
" See asyncfinder.vim for help.  This can be accessed by doing:
" :help asyncfinder

if !has("python")
    echo "asyncfinder needs vim compiled with +python option"
    finish
endif

" options {{{
if !exists("g:asyncfinder_open_in_prev_win")
    let g:asyncfinder_open_in_prev_win = 0
endif

if !exists("g:asyncfinder_ignore_dirs")
    let g:asyncfinder_ignore_dirs = "['.AppleDouble','.DS_Store','.git','.hg','.bzr']"
endif

if !exists("g:asyncfinder_ignore_files")
    let g:asyncfinder_ignore_files = "['*.swp']"
endif

if !exists("g:asyncfinder_initial_mode")
    let g:asyncfinder_initial_mode = "a"
endif

if !exists("g:asyncfinder_initial_pattern")
    let g:asyncfinder_initial_pattern = "*"
endif

if !exists("g:asyncfinder_match_exact")
    let g:asyncfinder_match_exact = 0
endif

if !exists("g:asyncfinder_match_camel_case")
    let g:asyncfinder_match_camel_case = 0
endif

if !exists("g:asyncfinder_include_buffers")
    let g:asyncfinder_include_buffers = 1
endif

if !exists("g:asyncfinder_include_mru_files")
    let g:asyncfinder_include_mru_files = 1
endif

if !exists("g:asyncfinder_edit_file_on_single_result")
    let g:asyncfinder_edit_file_on_single_result = 1
endif

if !exists("g:asyncfinder_speed_mode")
    let g:asyncfinder_speed_mode = 1
endif 

if !exists("g:asyncfinder_grep_open_in_prev_win")
    let g:asyncfinder_grep_open_in_prev_win = 0 
endif

if !exists("g:asyncfinder_grep_cmd")
    let g:asyncfinder_grep_cmd = "grep"
endif

if !exists("g:asyncfinder_grep_initial_pattern")
    let g:asyncfinder_grep_initial_pattern = ""
endif

if !exists("g:asyncfinder_grep_ignore_dirs")
    let g:asyncfinder_grep_ignore_dirs = "['.AppleDouble','.DS_Store','.git','.hg','.bzr']"
endif

if !exists("g:asyncfinder_grep_ignore_case")
    let g:asyncfinder_grep_ignore_case = 0
endif

if !exists("g:asyncfinder_grep_ignore_files")
    let g:asyncfinder_grep_ignore_files = "['*.swp']"
endif
" }}}

" commands {{{1
command! -bang -nargs=* -complete=file AsyncFinder call asyncfinder#OpenWindow('<bang>','',<q-args>) 
command! -bang -nargs=* -complete=file AsyncFinderTop call asyncfinder#OpenWindow('<bang>','topleft ',<q-args>) 
command! -bang -nargs=* -complete=file AsyncFinderBottom call asyncfinder#OpenWindow('<bang>','botright ',<q-args>) 
command! -bang -nargs=* AsyncGrep call asyncfinder#OpenGrepWindow('<bang>','',<q-args>) 
command! -bang -nargs=* AsyncGrepTop call asyncfinder#OpenGrepWindow('<bang>','topleft',<q-args>) 
command! -bang -nargs=* AsyncGrepBottom call asyncfinder#OpenGrepWindow('<bang>','botright',<q-args>) 

" vim: set sw=2 sts=2 et fdm=marker:
