" asyncfinder.vim - simple asynchronous fuzzy file finder for vim
" Maintainer: Dmitry "troydm" Geurkov <d.geurkov@gmail.com>
" Version: 0.2.8
" Description: asyncfinder.vim is a simple asychronous fuzzy file finder
" that searches for files in background without making you frustuated 
" Last Change: 11 March, 2016
" License: Vim License (see :help license)
" Website: https://github.com/troydm/asyncfinder.vim
"
" See asyncfinder.vim for help.  This can be accessed by doing:
" :help asyncfinder

" load python module {{{
python << EOF
import vim, sys
asyncfinder_path = vim.eval("expand('<sfile>:h')")
if not asyncfinder_path in sys.path:
    sys.path.insert(0, asyncfinder_path)
del asyncfinder_path 
import asyncfinder
EOF
" }}}

" variables {{{
if has('win32') || has('win64')
    let s:path_sep = '\'
else
    let s:path_sep = '/'
endif
" }}}

" functions {{{
" asyncfinder search prompt functions {{{
function! s:MoveCursorI()
    if col('.') == 1
        call feedkeys("\<Right>\<Left>",'n')
    else
        call feedkeys("\<Left>\<Right>",'n')
    endif
endfunction
function! s:Clear()
    if line('$') > 2
        silent! 3,$delete
    endif
endfunction
function! s:ClearPrompt()
    call setline(1,'>  ')
endfunction
function! s:Edit()
    let f = ''
    let p = getpos('.')
    if p[1] == 1
        if line('$') == 2
            let f = getline(2)
        endif
    else
        if p[1] > 1
            let f = getline(p[1])
        endif
    endif
    if !empty(f)
        if f[0] == 'd' && f[1] == ' '
            call setline(1,"> ".f[2:].s:path_sep)
            call feedkeys("ggA")
            call s:Clear()
        endif
        if (f[0] == 'f' || f[0] == 'b' || f[0] == 'm') && f[1] == ' ' 
            if g:asyncfinder_open_in_prev_win
                exe b:prevwinnr.'wincmd w'
            else
                silent! bd!
            endif
            exe ':e '.escape(f[2:], ' \')
        endif
    endif
endfunction
function! s:EnterPressedI()
    if col('.') != (col('$')-1)
        normal! l
    endif
    call s:EnterPressed()
endfunction
function! s:EnterPressed()
    let p = getpos('.')
    if p[1] == 1
        let t = getline(2)
        if !empty(t) 
            if t[0] == 'd'
                call setline(1,"> ".t[2:].s:path_sep)
                call feedkeys("$a")
                call s:Clear()
                return
            endif
            if g:asyncfinder_edit_file_on_single_result && (t[0] == 'f' || t[0] == 'b' || t[0] == 'm')
                if line('$') == 2
                    call s:Edit()
                    return
                endif
            endif
        endif
        startinsert
        return
    endif
    if p[1] > 1
        call s:Edit()
    endif
endfunction
function! s:EnterPressedGrepI()
    if col('.') != (col('$')-1)
        normal! l
    endif
    call s:EnterPressedGrep()
endfunction
function! s:EnterPressedGrep()
    let p = getpos('.')
    if p[1] == 1
        startinsert
        return
    endif
    let ln = getpos('.')[1]
    if ln > 1
        let line = getline(ln)
        let mln = matchstr(line, ":\\d\\+:")
        if mln != ''
          let mfn = ''
          let mln = mln[1:-2]
          let i = match(line, ":\\d\\+:")
          let mfn = line[:i-1]
          if filereadable(mfn)
              if g:asyncfinder_grep_open_in_prev_win
                  exe b:prevwinnr.'wincmd w'
              else
                  silent! bd!
              endif
              exe ':e +'.mln.' '.mfn
          endif
        endif 
    endif
endfunction
function! s:CursorInPrompt()
    let p = getpos('.')
    return p[1] == 1 && p[2] > 2
endfunction
function! s:BackspacePressed()
    if s:CursorInPrompt()
        if (col('.')+1) == col('$')
            normal! "_xa 
        else
            normal! "_x
        endif
    endif
endfunction
function! s:DelPressed()
    if s:CursorInPrompt()
        if (col('.')+1) == col('$')
            normal! "_xa 
        else
            normal! "_x
        endif
    endif
endfunction
function! s:CharTyped()
    if !s:CursorInPrompt()
        let v:char = ''
    endif
endfunction
function! s:PositionCursor()
    let p = getpos('.')
    if (p[1] == 1 && p[2] < 3) || p[1] > 1
        normal! ggA
    endif
    " to prevent position reset after InsertEnter autocommand is triggered
    let v:char = '.'
endfunction
function! s:ChangeMode()
    let mode = getbufvar('%','asyncfinder_mode')
    if mode == 'a'
        if g:asyncfinder_include_buffers
            let mode = 'b'
        else
            let mode = 'f'
        endif
    elseif mode == 'b'
        let mode = 'f'
    elseif mode == 'f'
        if g:asyncfinder_include_mru_files
            let mode = 'm'
        else
            let mode = 'a'
        endif
    else
        let mode = 'a'
    endif
    call setbufvar('%','asyncfinder_mode',mode)
    python asyncfinder.AsyncCancel()
endfunction
function! s:ChangeModeTo(mode)
    if a:mode == 'a' || a:mode == 'b' || a:mode == 'f' || a:mode =='m' 
        let mode = getbufvar('%','asyncfinder_mode')
        call setbufvar('%','asyncfinder_mode',a:mode)
    endif
endfunction
function! s:SetStatus(status)
    let &l:statusline=a:status
endfunction
function! s:StrEndsWith(s,e)
    return a:s[len(a:s)-len(a:e) : len(a:s)-1] == a:e
endfunction
function! s:GrepCmd()
    let options = ''
    if g:asyncfinder_grep_ignore_case
        let options .= ' -i'
    endif
    if g:asyncfinder_grep_cmd == 'builtin'
        let options .= string(eval(g:asyncfinder_grep_ignore_files))
        let options .= string(eval(g:asyncfinder_grep_ignore_dirs))
        let pattern = substitute(s:GrepPattern(),"'","\\\\'",'g')
        if pattern == '\'
            let pattern = ''
        endif
        return g:asyncfinder_grep_cmd.' '.options.' '''.pattern.''' '.getcwd()
    elseif s:StrEndsWith(g:asyncfinder_grep_cmd,'ack') || s:StrEndsWith(g:asyncfinder_grep_cmd,'ack-grep')
        " ack command
        for d in eval(g:asyncfinder_grep_ignore_dirs)
            let options .= ' --ignore-dir='.d
        endfor
        let pattern = substitute(s:GrepPattern(),"'","'\"'\"'",'g')
        return g:asyncfinder_grep_cmd.options.' '''.pattern.''' '.getcwd()
    elseif s:StrEndsWith(g:asyncfinder_grep_cmd,'ag')
        " ag command
        if !g:asyncfinder_grep_ignore_case
            let options .= ' -s'
        endif
        for f in eval(g:asyncfinder_grep_ignore_files)
            let options .= ' --ignore '.f
        endfor
        for d in eval(g:asyncfinder_grep_ignore_dirs)
            let options .= ' --ignore '.d
        endfor
        let pattern = substitute(s:GrepPattern(),"'","'\"'\"'",'g')
        return g:asyncfinder_grep_cmd.options.' '''.pattern.''' '.getcwd()
    else
        " grep command
        for f in eval(g:asyncfinder_grep_ignore_files)
            let options .= ' --exclude='.f
        endfor
        for d in eval(g:asyncfinder_grep_ignore_dirs)
            let options .= ' --exclude-dir='.d
        endfor
        let pattern = substitute(s:GrepPattern(),"'","'\"'\"'",'g')
        return g:asyncfinder_grep_cmd.' -n -r'.options.' -e '''.pattern.''' '.getcwd()
    endif
endfunction
function! s:GrepPattern()
    let pattern = getline(1)[2:]
    if pattern[len(pattern)-1] == ' '
        let pattern = pattern[:-2]
    endif
    return pattern 
endfunction
" }}}

" open window function {{{2
function! asyncfinder#OpenWindow(bang,win,pattern)
    let winnr = bufwinnr('^asyncfinder$')
    if winnr < 0
        execute a:win.(&lines/3).'sp asyncfinder'
        setlocal filetype=asyncfinder buftype=nofile bufhidden=wipe nolist nobuflisted noswapfile nonumber nowrap
        call setbufvar("%","prevwinnr",winnr('#'))
        call setbufvar("%","prevupdatetime",&updatetime)
        call setbufvar("%","asyncfinder_mode",g:asyncfinder_initial_mode)
        call s:SetStatus('Type your pattern (mode: '.g:asyncfinder_initial_mode.' cwd: '.getcwd().')')
        call s:ClearPrompt()
        set updatetime=250
        au BufEnter <buffer> set updatetime=250
        au BufWipeout <buffer> python asyncfinder.AsyncCancel()
        au BufLeave <buffer> let &updatetime=getbufvar('%','prevupdatetime')
        au InsertEnter <buffer> call s:PositionCursor()
        au CursorHold <buffer> python asyncfinder.AsyncRefreshN()
        au CursorHoldI <buffer> python asyncfinder.AsyncRefreshI()
        au InsertCharPre <buffer> call <SID>CharTyped()
        inoremap <buffer> <CR> <ESC>:call <SID>EnterPressedI()<CR>
        inoremap <buffer> <BS> <ESC>:call <SID>BackspacePressed() \| startinsert<CR>
        inoremap <buffer> <Del> <ESC>l:call <SID>DelPressed() \| startinsert<CR>
        nnoremap <buffer> <CR> :call <SID>EnterPressed()<CR>
        nnoremap <buffer> <Del> :call <SID>DelPressed()<CR>
        inoremap <buffer> <C-q> <ESC>:silent! bd! \| echo<CR>
        inoremap <buffer> <C-f> <C-o>:call <SID>ChangeMode()<CR>
        nnoremap <buffer> <C-f> :call <SID>ChangeMode()<CR>
        startinsert
        let pattern = a:pattern
        if a:bang == '!'
            let pattern = pyeval('asyncfinder.async_prev_pattern')
            let mode = pyeval('asyncfinder.async_prev_mode')
            if mode != g:asyncfinder_initial_mode
                let pattern = '-mode='.mode.' '.pattern
            endif
        endif
        let m = matchlist(pattern,'-mode=\?\([abfm]\)\?')
        if !empty(m)
            call s:ChangeModeTo(m[1])
            let pattern = substitute(pattern, '\s*-mode=\?[abfm]\?\s*','','')
        endif
        if !empty(pattern)
            call feedkeys(pattern)
            python asyncfinder.AsyncRefreshI()
        elseif !empty(g:asyncfinder_initial_pattern)
            call feedkeys(g:asyncfinder_initial_pattern)
            python asyncfinder.AsyncRefreshI()
        endif
    else
        exe winnr . 'wincmd w'
        call s:ClearPrompt()
        normal! gg
        startinsert
        let pattern = a:pattern
        let m = matchlist(pattern,'-mode=\?\([abfm]\)\?')
        if !empty(m)
            call s:ChangeModeTo(m[1])
            let pattern = substitute(pattern, '\s*-mode=\?[abfm]\?\s*','','')
        endif
        if a:bang == '!'
            let pattern = pyeval('asyncfinder.async_prev_pattern')
        endif
        if !empty(pattern)
            call feedkeys(pattern)
            python asyncfinder.AsyncRefreshI()
        else
            let pattern = pyeval('asyncfinder.async_prev_pattern')
            call feedkeys(pattern)
            python asyncfinder.AsyncRefreshI()
        endif
    endif
endfunction

function! asyncfinder#OpenGrepWindow(bang,win,pattern)
    let winnr = bufwinnr('^asyncgrep$')
    if winnr < 0
        execute a:win.(&lines/3).'sp asyncgrep'
        setlocal filetype=asyncgrep buftype=nofile bufhidden=wipe nolist nobuflisted noswapfile nonumber nowrap
        call setbufvar("%","prevwinnr",winnr('#'))
        call setbufvar("%","prevupdatetime",&updatetime)
        if g:asyncfinder_grep_cmd == 'builtin'
            let s = 'ignore_files: '.g:asyncfinder_grep_ignore_files
            let s .= ' ignore_dirs: '.g:asyncfinder_grep_ignore_dirs
            if g:asyncfinder_grep_ignore_case == 1
                let s .= ' ignore_case'
            endif
            let s .= ' cwd: '.getcwd()
            call s:SetStatus('Type your pattern ('.s.')')
        else
            call s:SetStatus('Type your pattern ('.s:GrepCmd().')')
        endif
        call s:ClearPrompt()
        set updatetime=250
        au BufEnter <buffer> set updatetime=250
        au BufWipeout <buffer> python asyncfinder.AsyncGrepCancel()
        au BufLeave <buffer> let &updatetime=getbufvar('%','prevupdatetime')
        au InsertEnter <buffer> call s:PositionCursor()
        au CursorHold <buffer> python asyncfinder.AsyncGrepRefreshN()
        au CursorHoldI <buffer> python asyncfinder.AsyncGrepRefreshI()
        au InsertCharPre <buffer> call <SID>CharTyped()
        inoremap <buffer> <CR> <ESC>:call <SID>EnterPressedGrepI()<CR>
        inoremap <buffer> <BS> <ESC>:call <SID>BackspacePressed() \| startinsert<CR>
        inoremap <buffer> <Del> <ESC>l:call <SID>DelPressed() \| startinsert<CR>
        nnoremap <buffer> <CR> :call <SID>EnterPressedGrep()<CR> \| echo<CR>
        inoremap <buffer> <C-q> <ESC>:silent! bd! \| echo<CR>
        startinsert
        let pattern = a:pattern
        if a:bang == '!'
            let pattern = pyeval('asyncfinder.async_grep_prev_pattern')
        endif
        if !empty(pattern)
            call feedkeys(pattern)
            python asyncfinder.AsyncGrepRefreshI()
        elseif !empty(g:asyncfinder_grep_initial_pattern)
            call feedkeys(g:asyncfinder_grep_initial_pattern)
            python asyncfinder.AsyncGrepRefreshI()
        endif
    else
        exe winnr . 'wincmd w'
        call s:ClearPrompt()
        normal! gg
        startinsert
        let pattern = a:pattern
        if a:bang == '!'
            let pattern = pyeval('asyncfinder.async_grep_prev_pattern')
        endif
        if !empty(pattern)
            call feedkeys(pattern)
            python asyncfinder.AsyncGrepRefreshI()
        endif
    endif
endfunction
" }}}

" vim: set sw=4 sts=4 et fdm=marker:
