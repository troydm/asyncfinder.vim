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

if !has("python")
    echo "asyncfinder needs vim compiled with +python option"
    finish
endif

if !exists("g:asyncfinder_ignore_dirs")
    let g:asyncfinder_ignore_dirs = "['*.AppleDouble*','*.DS_Store*','*.git*','*.hg*','*.bzr*']"
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

python << EOF

import vim, os, threading, fnmatch, random

async_pattern = None
async_prev_pattern = None
async_prev_mode = None
async_output = None

class AsyncOutput:
    def __init__(self):
        self.lock = threading.Lock()
        self.output = []
        self.toexit = False
    
    def get(self):
        self.lock.acquire()
        r = self.output
        self.output = []
        self.lock.release()
        return r

    def append(self,data):
        self.lock.acquire()
        self.output.append(data)
        self.lock.release()

    def extend(self,data):
        self.lock.acquire()
        self.output.extend(data)
        self.lock.release()

    def exit(self):
        self.lock.acquire()
        self.toexit = True
        self.lock.release()
    
    def toExit(self): 
        self.lock.acquire()
        toexit = self.toexit
        self.lock.release()
        return toexit

class AsyncGlobber:
    def __init__(self,output):
        self.output = output
        self.dir = None
        self.case_sensitive = False
        self.ignore_dirs = []
        self.ignore_files = []
        self.buffers = []
        self.files = []
        self.cwd = os.getcwd()+os.path.sep

    def addDir(self,p):
        if p.startswith(self.dir+os.path.sep):
            p = p[len(self.dir+os.path.sep):] 
        if not p in self.buffers:
            self.output.append("d "+p)
            self.files.append(p)

    def addFile(self,p):
        if p.startswith(self.dir+os.path.sep):
            p = p[len(self.dir+os.path.sep):] 
        if not p in self.buffers:
            self.output.append("f "+p)
            self.files.append(p)

    def addBuffer(self,p):
        if p.startswith(self.cwd): 
            p = p[len(self.cwd):]
        self.output.append("b "+p)
        self.buffers.append(p)

    def addMruFile(self,p):
        if p.startswith(self.cwd): 
            p = p[len(self.cwd):]
        if (not p in self.buffers) and (not p in self.files):
            self.output.append("m "+p)

    def fnmatch(self,f,p):
        if self.case_sensitive:
            return fnmatch.fnmatchcase(f,p)
        else:
            return fnmatch.fnmatch(f.lower(),p.lower())

    def has_magic(self,p):
        return '*' in p or '?' in p or '[' in p

    def fnmatch_list(self,f,l):
        for p in l:
            if self.fnmatch(f,p):
                return True
        return False

    def glob_buffers(self,buffers,pattern):
        if buffers == None:
            return
        pattern = '*'.join(pattern.split('**'))
        for buf in buffers:
            if buf != None and self.fnmatch(buf,pattern):
                self.addBuffer(buf)

    def glob_mru_files(self,mru_list,pattern):
        if mru_list == None:
            return
        pattern = '*'.join(pattern.split('**'))
        for mru in mru_list:
            if mru != None:
                mru = mru.strip() 
                if self.fnmatch(mru,pattern):
                    if not self.fnmatch_list(mru,self.ignore_files):
                        self.addMruFile(mru)

    def glob(self,dir,pattern):
        self.dir = dir
        # if no magic specified
        if not self.has_magic(pattern):
            if os.path.exists(os.path.join(dir,pattern)):
                if os.path.isdir(pattern):
                    self.addDir(pattern)
                else:
                    self.addFile(pattern)
            return
        pattern = list(pattern.split(os.path.sep))
        rec_index = None
        mag_index = None
        for pi in xrange(len(pattern)):
            p = pattern[pi]
            if self.has_magic(p):
                if mag_index == None:
                    mag_index = pi
            if '**' in p:
                pattern[pi] = '*'.join(p.split('**'))
                if rec_index == None:
                    rec_index = pi
        pre = pattern[:mag_index]
        post = pattern[mag_index:]
        if len(pre) > 0 and pre[0] == '':
            pre.insert(0,'')
        pre = os.path.sep.join(pre)
        if len(pre) > 0:
            if dir != '.':
                pre = dir+os.path.sep+pre
        else:
            pre = dir
        post = os.path.sep.join(post)
        post = pre+os.path.sep+post
        # normalize path removing double //
        pre = pre.replace(os.path.sep+os.path.sep,os.path.sep)
        post = post.replace(os.path.sep+os.path.sep,os.path.sep)
        self.walk(pre,post,rec_index != None)

    def walk(self,dir, pattern, recurse=True):
        for root, dirs, files in os.walk(dir):
            if self.output.toExit():
                break
            if self.fnmatch_list(root,self.ignore_dirs):
                continue
            for d in dirs:
                if self.fnmatch(os.path.join(root,d),pattern):
                    if not self.fnmatch_list(d,self.ignore_dirs):
                        self.addDir(os.path.join(root,d))
            for f in files:
                if self.fnmatch(os.path.join(root,f),pattern):
                    if not self.fnmatch_list(f,self.ignore_files):
                        self.addFile(os.path.join(root,f))
            if not recurse:
                break

def AsyncRefreshN():
    AsyncRefresh()
    vim.command("call feedkeys(\"f\e\")")

def AsyncRefreshI():
    AsyncRefresh()
    vim.command("call <SID>MoveCursorI()")

def AsyncRefresh():
    global async_pattern, async_prev_pattern, async_prev_mode, async_output
    if len(vim.current.buffer) == 1:
        vim.command("bd!")
        return
    # detect quit
    cl = len(vim.current.buffer[1])
    if cl < 2:
        vim.command("bd!")
        return
    elif cl < 3:
        vim.current.buffer[1] = '>  '
    mode = vim.eval("getbufvar('%','asyncfinder_mode')")
    pattern = vim.current.buffer[1]
    pattern = pattern[2:].strip()
    async_prev_pattern = pattern
    async_prev_mode = mode
    # expand tilde ~ to user home directory
    if '~' in pattern:
        pattern = pattern.replace('~',os.path.expanduser('~'))
    if len(pattern) > 0:
        # Pattern changed
        if pattern != async_pattern:
            # Remove ouput
            if len(vim.current.buffer) > 2:
                vim.current.buffer[2:] = None
            if async_output != None:
                async_output.exit()
            async_output = AsyncOutput() 
            async_pattern = pattern
            match_exact = vim.eval("g:asyncfinder_match_exact") == '1'
            match_camel_case = vim.eval("g:asyncfinder_match_camel_case") == '1'
            ignore_dirs = vim.eval("g:asyncfinder_ignore_dirs")
            ignore_files = vim.eval("g:asyncfinder_ignore_files")
            if ('a' in mode or 'b' in mode) and vim.eval("g:asyncfinder_include_buffers") == "1":
                buf_list = vim.eval("map(filter(range(1,bufnr(\"$\")), \"buflisted(v:val)\"),\"bufname(v:val)\")")
            else:
                buf_list = []
            mru_file = ""
            if ('a' in mode or 'm' in mode) and vim.eval("g:asyncfinder_include_mru_files") == "1" and vim.eval("exists('MRU_File')") == "1":
                mru_file = vim.eval("MRU_File")
            t = threading.Thread(target=AsyncSearch, args=(mode,pattern,buf_list,mru_file,match_exact,match_camel_case,ignore_dirs,ignore_files,))
            t.daemon = True
            t.start()
    else:
        if len(vim.current.buffer) > 2:
            vim.current.buffer[2:] = None
        async_pattern = None
        if async_output != None:
            async_output.exit()
            async_output = None
    running = async_output != None and not async_output.toExit()
    if running:
        dots = '.'*random.randint(1,3)
        dots = dots+' '*(3-len(dots))
        vim.current.buffer[0] = 'Searching files'+dots+' (mode: '+mode+' cwd: '+os.getcwd()+')'
    else:
        vim.current.buffer[0] = 'Type your pattern  (mode: '+mode+' cwd: '+os.getcwd()+')' 
    if async_output != None:
        output = async_output.get()
        if len(output) > 0:
            vim.current.buffer.append(output)

def AsyncSearch(mode,pattern,buf_list, mru_file, match_exact, match_camel_case, ignore_dirs,ignore_files):
    global async_output
    output = async_output
    if output.toExit():
        return
    glob = AsyncGlobber(output)
    glob.ignore_dirs = eval(ignore_dirs)
    glob.ignore_files = eval(ignore_files)
    pattern = pattern.split(os.path.sep)
    if match_camel_case:
        if len(pattern[-1]) > 1:
            camel = []
            i = 0
            f = 0
            prevup = False
            for c in pattern[-1]:
                up = c.isupper()
                if i != f:
                    if up and prevup != up:
                        camel.append(pattern[-1][f:i])
                        f = i
                prevup = up
                i += 1
            if len(pattern[-1][f:]) > 0:
                camel.append(pattern[-1][f:])
            for i in xrange(len(camel)-1):
                p = camel[i]
                p2 = camel[i+1]
                if not (p[-1] == '*' or  p2[0] == '*'):
                    p += '*'
                camel[i] = p
            pattern[-1] = ''.join(camel)
    if len(pattern[-1]) > 0:
        if not match_exact:
            if pattern[-1][0] != '*' and pattern[-1][0] != '^':
                pattern[-1] = '*'+pattern[-1]
            if pattern[-1][0] == '^':
                pattern[-1] = pattern[-1][1:]
                if len(pattern[-1]) == 0:
                    pattern[-1] = '*'
            if pattern[-1][-1] != '*' and pattern[-1][-1] != '$':
                pattern[-1] = pattern[-1]+'*'
            if pattern[-1][-1] == '$':
                pattern[-1] = pattern[-1][:-1]
            if pattern[-1] == '':
                pattern[-1] = '*'
    else:
        pattern[-1] = '*'
    pattern = os.path.sep.join(pattern)
    if 'a' in mode or 'b' in mode:
        glob.glob_buffers(buf_list,pattern)
    if output.toExit():
        return
    if 'a' in mode or 'f' in mode:
        glob.glob('.',pattern)
    if ('a' in mode or 'm' in mode) and len(mru_file) > 0:
            try:
                m = open(mru_file)
                mru_list = m.readlines()[1:]
                m.close()
                if output.toExit():
                    return
                glob.glob_mru_files(mru_list,pattern)
            except IOError:
                pass
    output.exit()

def AsyncCancel():
    global async_pattern, async_output
    async_pattern = None
    if async_output != None:
        async_output.exit()
        async_output = None

EOF

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
    exe moder
    python async_pattern = None
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
function! s:OpenWindow(bang,pattern)
    let winnr = bufwinnr('^asyncfinder$')
    if winnr < 0
        execute &lines/3 . 'sp asyncfinder'
        setlocal filetype=asyncfinder buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
        call setbufvar("%","prevupdatetime",&updatetime)
        call setbufvar("%","asyncfinder_mode",g:asyncfinder_initial_mode)
        call setline(1, 'Type your pattern  (mode: '.g:asyncfinder_initial_mode.' cwd: '.getcwd().')')
        call s:ClearPrompt()
        set updatetime=500
        au BufEnter <buffer> set updatetime=500
        au BufWipeout <buffer> python AsyncCancel()
        au BufLeave <buffer> let &updatetime=getbufvar('%','prevupdatetime')
        au InsertEnter <buffer> call s:PositionCursor()
        au CursorHold <buffer> python AsyncRefreshN()
        au CursorHoldI <buffer> python AsyncRefreshI()
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
            let pattern = pyeval('async_prev_pattern')
            let mode = pyeval('async_prev_mode')
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
            python AsyncRefreshI()
        elseif !empty(g:asyncfinder_initial_pattern)
            call feedkeys(g:asyncfinder_initial_pattern)
            python AsyncRefreshI()
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
            let pattern = pyeval('async_prev_pattern')
        endif
        if !empty(pattern)
            call feedkeys(pattern)
            python AsyncRefreshI()
        else
            let pattern = pyeval('async_prev_pattern')
            call feedkeys(pattern)
            python AsyncRefreshI()
        endif
    endif
endfunction

command! -bang -nargs=* -complete=file AsyncFinder call s:OpenWindow('<bang>',<q-args>) 
