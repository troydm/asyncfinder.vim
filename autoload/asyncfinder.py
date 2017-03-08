# asyncfinder.vim - simple asynchronous fuzzy file finder for vim
# Maintainer: Dmitry "troydm" Geurkov <d.geurkov@gmail.com>
# Version: 0.2.8
# Description: asyncfinder.vim is a simple asychronous fuzzy file finder
# that searches for files in background without making you frustuated 
# Last Change: 8 March, 2017
# License: Vim License (see :help license)
# Website: https://github.com/troydm/asyncfinder.vim

import vim, os, threading, multiprocessing, Queue, fnmatch, re, random, platform, subprocess, time

try:
    import fcntl, select
except Error:
    pass

async_pattern = None
async_grep_pattern = None
async_prev_pattern = None
async_grep_prev_pattern = None
async_prev_mode = None
async_output = None
async_grep_output = None
async_grep_file_output = None
async_on_windows = platform.system() == 'Windows'

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
        self.dirps = None
        self.case_sensitive = False
        self.ignore_dirs = []
        self.ignore_files = []
        self.buffers = []
        self.files = []
        self.cwd = os.getcwd()+os.path.sep

    def addDir(self,p):
        if p.startswith(self.dirps):
            p = p[len(self.dirps):] 
        if not p in self.buffers:
            self.output.append("d "+p)
            self.files.append(p)

    def addFile(self,p):
        if p.startswith(self.dirps):
            p = p[len(self.dirps):] 
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
        self.dirps = self.dir+os.path.sep
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
        i = 0
        walkQueue = None
        resultQueue = None
        threads = None
        for root, dirs, files in os.walk(dir):
            if self.output.toExit():
                return
            if self.fnmatch_list(root,self.ignore_dirs):
                continue
            i += 1
            if i == 1000:
                threadsCount = multiprocessing.cpu_count()*2-1
                walkQueue = Queue.Queue(threadsCount*20)
                resultQueue = Queue.Queue(threadsCount*20)
                threads = []
                for ti in xrange(threadsCount):
                    t = threading.Thread(target=self.walkThread, args=(walkQueue,resultQueue,pattern))
                    t.daemon = True
                    threads.append(t)
                    t.start()
            if i >= 1000:
                while True:
                    try:
                        walkQueue.put((root,dirs,files),True,1)
                        break
                    except Queue.Full:
                        if self.output.toExit():
                            return
                r = None
                try:
                    r = resultQueue.get_nowait()
                except Queue.Empty:
                    pass
                if r != None:
                    (rdirs,rfiles) = r
                    for rdir in rdirs:
                        self.addDir(rdir)
                    for rfile in rfiles:
                        self.addFile(rfile)
            else:
                dirs[:] = [d for d in dirs if not self.fnmatch_list(d,self.ignore_dirs)]
                for d in dirs:
                    if self.fnmatch(os.path.join(root,d),pattern):
                        self.addDir(os.path.join(root,d))
                for f in files:
                    if self.fnmatch(os.path.join(root,f),pattern):
                        if not self.fnmatch_list(f,self.ignore_files):
                            self.addFile(os.path.join(root,f))
                if not recurse:
                    return
        if walkQueue == None:
            return
        while not resultQueue.empty():
            if self.output.toExit():
                return
            r = None
            try:
                r = resultQueue.get_nowait()
            except Queue.Empty:
                pass
            if r != None:
                (rdirs,rfiles) = r
                for rdir in rdirs:
                    self.addDir(rdir)
                for rfile in rfiles:
                    self.addFile(rfile)
        walkQueue.join()
        while not resultQueue.empty():
            if self.output.toExit():
                return
            r = None
            try:
                r = resultQueue.get_nowait()
            except Queue.Empty:
                pass
            if r != None:
                (rdirs,rfiles) = r
                for rdir in rdirs:
                    self.addDir(rdir)
                for rfile in rfiles:
                    self.addFile(rfile)

    def walkThread(self,walkQueue,resultQueue,pattern):
        while True:
            if self.output.toExit():
                return
            t = None
            try:
                t = walkQueue.get_nowait()
            except Queue.Empty:
                pass
            if t == None:
                time.sleep(0.01)
                continue
            (root,dirs,files) = t
            rdirs = []
            rfiles = []
            dirs[:] = [d for d in dirs if not self.fnmatch_list(d,self.ignore_dirs)]
            for d in dirs:
                if self.fnmatch(os.path.join(root,d),pattern):
                    rdirs.append(os.path.join(root,d))
            for f in files:
                if self.fnmatch(os.path.join(root,f),pattern):
                    if not self.fnmatch_list(f,self.ignore_files):
                        rfiles.append(os.path.join(root,f))
            if len(rdirs) > 0 or len(rfiles) > 0:
                while True:
                    try:
                        resultQueue.put((rdirs,rfiles),True,1)
                        break
                    except Queue.Full:
                        if self.output.toExit():
                            return
            walkQueue.task_done()


def AsyncRefreshN():
    AsyncRefresh()
    vim.command("call feedkeys(\"f\e\")")

def AsyncRefreshI():
    AsyncRefresh()
    vim.command("call <SID>MoveCursorI()")

def AsyncRefresh():
    global async_pattern, async_prev_pattern, async_prev_mode, async_output
    # detect quit
    cl = len(vim.current.buffer[0])
    if cl < 2:
        vim.command("bd!")
        return
    elif cl < 3:
        vim.current.buffer[0] = '>  '
    mode = vim.eval("getbufvar('%','asyncfinder_mode')")
    pattern = vim.current.buffer[0]
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
            if len(vim.current.buffer) > 1:
                vim.current.buffer[1:] = None
            if async_output != None:
                async_output.exit()
            async_output = AsyncOutput() 
            async_pattern = pattern
            speed_mode = vim.eval("g:asyncfinder_speed_mode") == '1'
            match_exact = vim.eval("g:asyncfinder_match_exact") == '1'
            match_camel_case = vim.eval("g:asyncfinder_match_camel_case") == '1'
            ignore_dirs = vim.eval("g:asyncfinder_ignore_dirs")
            ignore_files = vim.eval("g:asyncfinder_ignore_files")
            # Get buffer list
            if ('a' in mode or 'b' in mode) and vim.eval("g:asyncfinder_include_buffers") == "1":
                buf_list = vim.eval("map(filter(range(1,bufnr(\"$\")), \"buflisted(v:val) && bufname(v:val) != ''\"),\"bufname(v:val)\")")
            else:
                buf_list = []
            mru_file = ""
            if ('a' in mode or 'm' in mode) and vim.eval("g:asyncfinder_include_mru_files") == "1" and vim.eval("exists('MRU_File')") == "1":
                mru_file = vim.eval("MRU_File")
            # Disable speed mode when doing recursive file search
            if speed_mode:
                if ('a' in mode or 'f' in mode) and '**' in pattern:
                    speed_mode = False
            if speed_mode:
                AsyncSearch(async_output,mode,pattern,buf_list,mru_file,match_exact,match_camel_case,ignore_dirs,ignore_files)
            else:
                t = threading.Thread(target=AsyncSearch, args=(async_output,mode,pattern,buf_list,mru_file,match_exact,match_camel_case,ignore_dirs,ignore_files,))
                t.daemon = True
                t.start()
    else:
        if len(vim.current.buffer) > 1:
            vim.current.buffer[1:] = None
        async_pattern = None
        if async_output != None:
            async_output.exit()
            async_output = None
    running = async_output != None and not async_output.toExit()
    status = None
    status_mode='(%#AsyncFinderTitle#mode:%* '+mode+' %#AsyncFinderTitle#cwd:%* '+os.getcwd()+')'
    if running:
        dots = '.'*random.randint(1,3)
        dots = dots+' '*(3-len(dots))
        status = '%#AsyncFinderTitle#Searching files'+dots+'%*'+status_mode
    else:
        status = '%#AsyncFinderTitle#Type your pattern%* '+status_mode
    vim.eval("s:SetStatus('"+status.replace("'","''")+"')")
    if async_output != None:
        output = async_output.get()
        if len(output) > 0:
            vim.current.buffer.append(output)

def AsyncSearch(output,mode,pattern,buf_list, mru_file, match_exact, match_camel_case, ignore_dirs,ignore_files):
    global async_on_windows
    if output.toExit():
        return
    if async_on_windows:
        pattern = pattern.replace('/','\\')
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

def AsyncGrepRefreshN():
    AsyncGrepRefresh()
    vim.command("call feedkeys(\"f\e\")")

def AsyncGrepRefreshI():
    AsyncGrepRefresh()
    vim.command("call <SID>MoveCursorI()")

def AsyncGrepRefresh():
    global async_grep_pattern, async_grep_prev_pattern, async_grep_output, async_grep_file_output
    # detect quit
    cl = len(vim.current.buffer[0])
    if cl < 2:
        vim.command("bd!")
        return
    elif cl < 3:
        vim.current.buffer[0] = '>  '
    pattern = vim.current.buffer[0]
    pattern = pattern[2:]
    if pattern[-1] == ' ':
        pattern = pattern[:-1]
    async_grep_prev_pattern = pattern
    cmd = vim.eval("s:GrepCmd()")
    cwd = None
    if len(pattern) > 0:
        # Pattern changed
        if pattern != async_grep_pattern:
            async_grep_pattern = pattern
            # Remove ouput
            if async_grep_output != None:
                async_grep_output.exit()
            if async_grep_file_output != None:
                async_grep_file_output.exit()
            if len(vim.current.buffer) > 1:
                vim.current.buffer[1:] = None
            async_grep_output = AsyncOutput() 
            async_grep_file_output = None
            cwd = vim.eval("getcwd()")
            t = None
            if cmd.startswith('builtin'):
                t = threading.Thread(target=AsyncGrepBuiltin, args=(cmd,cwd))
            else:
                t = threading.Thread(target=AsyncGrep, args=(cmd,cwd))
            t.daemon = True
            t.start()
    else:
        if len(vim.current.buffer) > 1:
            vim.current.buffer[1:] = None
        async_grep_pattern = None
        if async_grep_output != None:
            async_grep_output.exit()
            async_grep_output = None
    running = async_grep_output != None and not async_grep_output.toExit()
    if cmd.startswith('builtin'):
        cmd = 'ignore_files: '+vim.eval("g:asyncfinder_grep_ignore_files")
        cmd += ' ignore_dirs: '+vim.eval("g:asyncfinder_grep_ignore_dirs")
        if vim.eval("g:asyncfinder_grep_ignore_case") == 1:
            cmd += ' ignore_case'
        if cwd == None:
            cwd = vim.eval("getcwd()")
        cmd += ' cwd: '+cwd
    status = None
    if running:
        dots = '.'*random.randint(1,3)
        dots = dots+' '*(3-len(dots))
        status = '%#AsyncGrepTitle#Searching files'+dots+'%*('+cmd+')'
    else:
        status = '%#AsyncGrepTitle#Type your pattern%* ('+cmd+')' 
    vim.eval("s:SetStatus('"+status.replace("'","''")+"')")
    if async_grep_output != None:
        output = async_grep_output.get()
        if len(output) > 0:
            vim.current.buffer.append(output)


def AsyncGrepBuiltin(cmd,cwd):
    global async_grep_output, async_grep_file_output
    output = async_grep_output
    if output.toExit():
        return
    ignore_case = False
    cmd = cmd[7:].lstrip()
    if cmd.startswith('-i'):
        ignore_case = True
        cmd = cmd[2:].lstrip()
    ignore_files =cmd[:cmd.index(']')+1]
    cmd = cmd[cmd.index(']')+1:].lstrip()
    ignore_dirs = cmd[:cmd.index(']')+1]
    cmd = cmd[cmd.index(']')+1:].lstrip()
    i = 1
    while cmd[i] != "'" or cmd[i-1] == "\\":
        i += 1
    pattern = cmd[1:i]
    pattern = pattern.replace("\\'","'")
    cwd = cmd[i+1:].lstrip()
    async_grep_file_output = AsyncOutput()
    file_output = async_grep_file_output
    match_exact = vim.eval("g:asyncfinder_match_exact") == '1'
    match_camel_case = vim.eval("g:asyncfinder_match_camel_case") == '1'
    buf_list = []
    mru_file = ""
    t = threading.Thread(target=AsyncSearch, args=(file_output,'f','**',buf_list,mru_file,match_exact,match_camel_case,ignore_dirs,ignore_files,))
    t.daemon = True
    t.start()
    if pattern.startswith('/') and pattern.endswith('/'):
        try:
            if ignore_case:
                pattern = re.compile(pattern[1:-1],re.IGNORECASE)
            else:
                pattern = re.compile(pattern[1:-1])
        except:
            pass
    if type(pattern) == str and ignore_case:
        pattern = pattern.lower()
    while not file_output.toExit():
        files = file_output.get()
        if len(files) == 0:
            time.sleep(0.01)
        else:
            for f in files:
                lines = AsyncSearchInFile(f[2:],pattern,cwd,ignore_case)
                if len(lines) > 0:
                    output.extend(lines)
    for f in file_output.get():
        lines = AsyncSearchInFile(f[2:],pattern,cwd,ignore_case)
        if len(lines) > 0:
            output.extend(lines)
    output.exit()

def AsyncSearchInFile(fn,pattern,cwd,ignore_case):
    f = None
    found = []
    try:
        fn = os.path.abspath(cwd+os.sep+fn)
        f = open(fn,'r')
        if type(pattern) == str:
            for i, line in enumerate(f):
                if ignore_case:
                    line = line.lower()
                if pattern in line:
                    found.append(fn+":"+str(i+1)+":"+line)
        else:
            for i, line in enumerate(f):
                if len(re.findall(pattern, line)) > 0:
                    found.append(fn+":"+str(i+1)+":"+line)
        return found
    except:
        return found
    finally:
        if f is not None:
            f.close()

def AsyncGrep(cmd,cwd):
    global async_grep_output
    output = async_grep_output
    if output.toExit():
        return
    p = subprocess.Popen(cmd+" 2>&1", shell=True, cwd=cwd, preexec_fn=os.setsid, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    fcntl.fcntl(p.stdout.fileno(), fcntl.F_SETFL, os.O_NONBLOCK)
    if 'poll' in dir(select):
        pl = select.poll()
        pl.register(p.stdout)
    else:
        pl = None
    outread = ''
    outrem = ''
    while True:
        try:
            outread = ''
            if pl != None:
                plr = pl.poll(50)
                if len(plr) == 0:
                    outread = ''
                else:
                    plr = plr[0][1]
                    try:
                        if plr & select.POLLIN or plr & select.POLLPRI:
                            outread = p.stdout.read()
                        else:
                            outread = ''
                    except IOError:
                        outread = ''
            else:
                try:
                    outread = p.stdout.read()
                except IOError:
                    outread = ''
            if len(outread) == 0:
                retval = p.poll()
                if retval != None:
                    break
                else:
                    time.sleep(0.01)
            else:
                outread = outread.split("\n")
                if len(outrem) > 0:
                    outread[0] = outrem+outread[0] 
                if len(outread[-1]) > 0:
                    outrem = outread[-1]
                outread = outread[:-1]
                output.extend(outread)
            if output.toExit():
                break
        except IOError:
            time.sleep(0.01)
    if len(outread) > 0:
        if type(outread) == str:
            outread = outread.split("\n")
        if len(outread[-1]) == 0:
            outread = outread[:-1]
        output.extend(outread)
    output.exit()
    if pl != None:
        pl.unregister(p.stdout)
    try:
        p.terminate()
    except OSError:
        pass


def AsyncGrepCancel():
    global async_grep_pattern, async_grep_output, async_grep_file_output
    async_grep_pattern = None
    if async_grep_output != None:
        async_grep_output.exit()
        async_grep_output = None
    if async_grep_file_output != None:
        async_grep_file_output.exit()
        async_grep_file_output = None

