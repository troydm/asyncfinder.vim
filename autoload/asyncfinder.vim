" asyncfinder.vim - simple asynchronous fuzzy file finder for vim
" Maintainer: Dmitry "troydm" Geurkov <d.geurkov@gmail.com>
" Version: 0.2.6
" Description: asyncfinder.vim is a simple asychronous fuzzy file finder
" that searches for files in background without making you frustuated 
" Last Change: 5 September, 2012
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
    sys.path.append(asyncfinder_path)
del asyncfinder_path 
import asyncfinder
EOF
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
        3,$delete
    endif
endfunction
function! s:ClearPrompt()
    call setline(2,'>  ')
endfunction
function! s:Edit()
    let f = ''
    let p = getpos('.')
    if p[1] == 2
        if line('$') == 3
            let f = getline(3)
        endif
    else
        if p[1] > 2
            let f = getline(p[1])
        endif
    endif
    if !empty(f)
        if f[0] == 'd' && f[1] == ' '
            call setline(2,"> ".f[2:]."/")
            call feedkeys("ggjA")
            call s:Clear()
        endif
        if (f[0] == 'f' || f[0] == 'b' || f[0] == 'm') && f[1] == ' ' 
            silent! bd!
            exe ':e '.f[2:]
        endif
    endif
endfunction
function! s:EnterPressedI()
    if col('.') != (col('$')-1)
        normal l
    endif
    call s:EnterPressed()
endfunction
function! s:EnterPressed()
    let p = getpos('.')
    if p[1] == 1
        startinsert
        return
    endif
    if p[1] == 2
        let t = getline(3)
        if !empty(t) 
            if t[0] == 'd'
                call setline(2,"> ".t[2:]."/")
                call feedkeys("$a")
                call s:Clear()
                return
            endif
            if g:asyncfinder_edit_file_on_single_result && (t[0] == 'f' || t[0] == 'b' || t[0] == 'm')
                if line('$') == 3
                    call s:Edit()
                    return
                endif
            endif
        endif
        startinsert
        return
    endif
    if p[1] > 2
        call s:Edit()
    endif
endfunction
function! s:CursorInPrompt()
    let p = getpos('.')
    return p[1] == 2 && p[2] > 2
endfunction
function! s:BackspacePressed()
    if s:CursorInPrompt()
        if (col('.')+1) == col('$')
            normal xa 
        else
            normal x
        endif
    endif
endfunction
function! s:DelPressed()
    if s:CursorInPrompt()
        if (col('.')+1) == col('$')
            normal xa 
        else
            normal x
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
    if p[1] == 1 || (p[1] == 2 && p[2] < 3)
        normal ggjA
    endif
    " to prevent position reset after InsertEnter autocommand is triggered
    let v:char = '.'
endfunction
function! s:ChangeMode()
    let mode = getbufvar('%','asyncfinder_mode')
    let moder = '1s/mode: '.mode.' /mode: '
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
    let moder .= mode.' '
    let pos = getpos('.')
    exe moder
    call setpos('.',pos)
    python asyncfinder.AsyncCancel()
endfunction
function! s:ChangeModeTo(mode)
    if a:mode == 'a' || a:mode == 'b' || a:mode == 'f' || a:mode =='m' 
        let mode = getbufvar('%','asyncfinder_mode')
        let moder = '1s/mode: '.mode.' /mode: '
        call setbufvar('%','asyncfinder_mode',a:mode)
        let moder .= a:mode.' '
        exe moder
    endif
endfunction
" }}}

" open window function {{{2
function! asyncfinder#OpenWindow(bang,win,pattern)
    let winnr = bufwinnr('^asyncfinder$')
    if winnr < 0
        execute a:win.(&lines/3).'sp asyncfinder'
        setlocal filetype=asyncfinder buftype=nofile bufhidden=wipe nobuflisted noswapfile nonumber nowrap
        call setbufvar("%","prevupdatetime",&updatetime)
        call setbufvar("%","asyncfinder_mode",g:asyncfinder_initial_mode)
        call setline(1, 'Type your pattern  (mode: '.g:asyncfinder_initial_mode.' cwd: '.getcwd().')')
        call s:ClearPrompt()
        set updatetime=500
        au BufEnter <buffer> set updatetime=500
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
        normal gg
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
" }}}

" vim: set sw=2 sts=2 et fdm=marker:
