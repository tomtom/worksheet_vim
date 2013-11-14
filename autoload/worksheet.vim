" worksheet.vim
" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     http://www.vim.org/account/profile.php?user_id=4037
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2008-07-15.
" @Last Change: 2013-11-14.
" @Revision:    0.0.933

" call tlog#Log('Load: '. expand('<sfile>')) " vimtlib-sfile


if !exists('g:worksheet#default')
    " The default worksheet type
    let g:worksheet#default = 'vim'   "{{{2
endif


if !exists('g:worksheet#rewrite')
    " let g:worksheet#rewrite = {}   "{{{2
    let g:worksheet#rewrite = {
                \ '^r\(_com\)\?$': [
                \ ['^\s\+??\(.*\)', 'help.search("\1")', ''],
                \ ['^\s\+?\([^?].*\)', 'help("\1")', ''],
                \ ]
                \ }
endif


if !exists('g:worksheet#skip_nomodifiable')
    " If true, the cursor skips over non-modifiable text.
    let g:worksheet#skip_nomodifiable = 1   "{{{2
endif


let s:modes = {}
let s:bufworksheets = {}
let s:processing = 0
let s:ws_dir = expand('<sfile>:p:h') .'/worksheet/'

augroup Worksheet
    autocmd!
augroup END


" Open a new worksheet.
function! worksheet#Worksheet(...) "{{{3
    let mode = a:0 >= 1 ? a:1 : g:worksheet#default
    let current_buffer = a:0 >= 2 ? a:2 : 0
    if !current_buffer
        exec 'split __Worksheet@'. mode .'__'
        let b:worksheet = worksheet#Prototype()
        let b:worksheet.bufnr = bufnr('')
        let b:worksheet.mode = mode
        let b:worksheet.syntax = mode
        let s:bufworksheets[bufnr('%')] = b:worksheet
    endif
    if getline(line('$') - 1) =~ '^\[worksheet metadata\]$'
        let worksheet_dump = getline('$')
        silent $-1,$delete
        let metadata = eval(worksheet_dump)
        call extend(b:worksheet, metadata)
        let mode = b:worksheet.mode
    endif
    if empty(mode)
        throw 'Worksheet: "mode" is empty'
    endif
    if !has_key(s:modes, mode)
        try
            call worksheet#{mode}#InitializeInterpreter(b:worksheet)
        catch
            if !current_buffer
                wincmd c
            endif
            echoerr 'Worksheet: Failed to initialize '. mode .': '. v:exception
            return
        endtry
        let s:modes[mode] = []
    endif
    call b:worksheet.BufJoin()
    set filetype=worksheet
    call worksheet#{mode}#InitializeBuffer(b:worksheet)
    if current_buffer
        call s:InstallSaveHooks()
    else
        setlocal buftype=nofile
        setlocal noswapfile
        norm! G
        let empty = line('.') == 1
        call b:worksheet.NewEntry(empty ? -1 : 1)
        if empty
            silent exec line('$') .'delete'
        endif
    endif
    exec 'autocmd Worksheet BufUnload <buffer> call s:bufworksheets['. b:worksheet.bufnr .'].BufUnload()'
endf


" Open a new worksheet or use the current one.
function! worksheet#UseWorksheet(...) "{{{3
    let mode = a:0 >= 1 ? a:1 : g:worksheet#default
    if has_key(s:modes, mode) && !empty(s:modes[mode])
        let winnrs = filter(copy(s:modes[mode]), 'bufwinnr(v:val) != -1')
        " TLogVAR winnrs
        if !empty(winnrs)
            exec bufwinnr(winnrs[0]) .'wincmd w'
        else
            exec 'sbuffer '. s:modes[mode][0]
        endif
    else
        return call('worksheet#Worksheet', a:000)
    endif
endf


function! worksheet#Complete(ArgLead, CmdLine, CursorPos) "{{{3
    redraw
    let candidates = split(glob(s:ws_dir .'*.vim'), '\n')
    call map(candidates, 'fnamemodify(v:val, ":t:r")')
    if !empty(a:ArgLead)
        call filter(candidates, 'v:val[0 : len(a:ArgLead) - 1] ==# a:ArgLead')
    endif
    return candidates
endf


function! worksheet#RestoreBuffer() "{{{3
    call worksheet#Worksheet(exists('b:worksheet') ? b:worksheet.mode : '', 1)
endf


function! worksheet#SetModifiable(mode) "{{{3
    if s:processing || s:IsInputField(b:worksheet)
        setlocal modifiable
    else
        setlocal nomodifiable
    endif
    if g:worksheet#skip_nomodifiable
        let lnum1 = line('.')
        if !&l:modifiable
            let lnum0 = exists('b:worksheet_lnum') ? b:worksheet_lnum : 0 
            if lnum0 < lnum1
                let key = ']]'
            else
                let key = '[['
            endif
            if a:mode == 'i'
                let key = "\<esc>" . key ."i"
            endif
            " TLogVAR a:mode, lnum0, lnum1, key
            call feedkeys(key, 'm')
        endif
        let b:worksheet_lnum = lnum1
    endif
endf


function! worksheet#Restore() "{{{3
    if exists('b:worksheet')
        setlocal modifiable
        let pos = getpos('.')
        silent %delete
        let ws = b:worksheet
        for entry_idx in ws.order
            let entry = get(ws.entries, entry_idx, {})
            if empty(entry)
                echomsg 'Worksheet: Missing entry: '. entry_idx
            else
                call append(line('$'), entry.header)
                if has_key(entry, 'input')
                    call append(line('$'), entry.input)
                else
                    call append(line('$'), '')
                endif
                if has_key(entry, 'lines')
                    let [silent, input] = ws.SilentInput(entry.input)
                    if !silent && !empty(entry.lines)
                        call append(line('$'), entry.lines)
                    endif
                endif
            endif
        endfor
        silent 1delete
        call setpos('.', pos)
    else
        echoerr 'Worksheet: Not a worksheet'
    endif
endf


function! worksheet#SaveAs(bang, ...) "{{{3
    if exists('b:worksheet')
        " let ext = '_'. b:worksheet.mode . g:worksheet_suffix
        " let fname = input('Filename ('. string(ext) .' will be added): ', '', 'file')
        call inputsave()
        let fname = a:0 >= 1 ? a:1 : input('Filename: ', '', 'file')
        call inputrestore()
        if !empty(fname)
            setlocal buftype&
            setlocal swapfile&
            call s:InstallSaveHooks()
            exec 'saveas'. a:bang .' '. fnameescape(fname)
        endif
    else
        echoerr 'Worksheet: Not a worksheet'
    endif
endf


function! worksheet#Export(filename) "{{{3
    if exists('b:worksheet')
        let reg = v:register
        let rval = getreg(reg)
        try
            call b:worksheet.YankAll()
            let contents = split(getreg(reg), '\n')
            let filename = a:filename
            if empty(filename)
                call inputsave()
                let filename = input("Export to file: ", "", "file")
                call inputrestore()
            endif
            let filename = fnamemodify(filename, ':p')
            if filereadable(filename)
                let overwrite = input("Overwrite file? (Y/n) ")
                if overwrite == "n"
                    echo "Cancel export."
                    return
                endif
            endif
            call writefile(contents, filename)
        finally
            call setreg(reg, rval)
        endtry
    else
        echoerr 'Worksheet: Not a worksheet'
    endif
endf


function! worksheet#Operator(type) "{{{3
    if a:type == 'line'
        silent exe "normal! '[V']"
    elseif a:type == 'block'
        silent exe "normal! `[\<C-V>`]"
    else
        silent exe "normal! `[v`]"
    endif
    let beg = line("'[")
    let end = line("']")
    let lines = getline(beg, end)
    call worksheet#EvaluateLinesInWorksheet(&filetype, lines)
endf


function! worksheet#EvaluateLinesInWorksheet(filetype, lines) "{{{3
    " TLogVAR a:filetype, a:lines
    let ws = worksheet#Complete(a:filetype, 'Worksheet '. a:filetype, len(a:filetype))
    if !empty(ws)
        call worksheet#UseWorksheet(a:filetype)
        let self = b:worksheet
        let entry_id = self.CurrentEntryId()
        " TLogVAR entry_id, self.entries[entry_id]
        if !empty(get(self.entries[entry_id], 'string', ''))
            let entry_id = self.NewEntry(1, 1)
        endif
        if entry_id >= 0
            if self.SetInput(entry_id, a:lines)
                call self.Submit()
                norm! zt
            endif
        endif
    endif
endf


function! s:InstallSaveHooks() "{{{3
    " autocmd Worksheet VimLeavePre <buffer> call s:WriteBufferPre()
    autocmd Worksheet BufWritePre <buffer> call s:WriteBufferPre()
    autocmd Worksheet BufWritePost <buffer> call s:WriteBufferPost()
endf


function! s:WriteBufferPre() "{{{3
    let pos = getpos('.')
    try
        let worksheet = copy(b:worksheet)
        for key in keys(worksheet)
            if type(worksheet[key]) == 2
                unlet worksheet[key]
            endif
        endfor
        call append(line('$'), ['[worksheet metadata]', string(worksheet)])
    finally
        call setpos('.', pos)
    endtry
endf


function! s:WriteBufferPost() "{{{3
    let pos = getpos('.')
    try
        silent $-1,$delete
    finally
        call setpos('.', pos)
    endtry
endf

function! worksheet#EvaluateAll() "{{{3
    if exists('b:worksheet')
        let pos = getpos('.')
        try
            let worksheet = b:worksheet
            for entry_id in worksheet.order
                let entry = worksheet.entries[entry_id]
                " TLogVAR entry_id, entry
                let lno = b:worksheet.GotoEntry(entry_id, 1, 0)
                if lno
                    call b:worksheet.Submit()
                endif
            endfor
        finally
            call setpos('.', pos)
        endtry
    else
        echoerr 'Worksheet: Not a worksheet'
    endif
endf




function! s:IsInputField(worksheet, ...) "{{{3
    let line = getline(a:0 >= 1 ? a:1 : '.')
    return line !~ a:worksheet['rx_output'] && line !~ a:worksheet['rx_entry']
    " let syn = synIDattr(synID(line("."), col("."), 0), "name")
    " return syn !=# 'WorksheetHead' && syn !=# 'WorksheetBody'
endf


function! s:RegexpEscape(string) "{{{3
    return '\V'. escape(a:string, '\')
endf


function! s:EncodeID(entry_id) "{{{3
    let start = 65
    let base = 26
    let code = []
    let entry_id = a:entry_id - 1
    while 1
        let rem = entry_id % base
        call insert(code, nr2char(start + rem))
        if entry_id < base
            break
        endif
        let entry_id = (entry_id / base) - 1
    endwh
    return join(code, '')
endf


function! DecodeID(code) "{{{3
    let entry_id = 0
    let max = len(a:code) - 1
    for idx in range(0, max)
        let a = char2nr(a:code[idx]) - 64
        let b = float2nr(pow(26, max - idx))
        let c = a * b
        let entry_id += c
    endfor
    return entry_id
endf


let s:prototype = {
            \ 'entry_id': 0,
            \ 'entries': {},
            \ 'order': [],
            \ 'buffers': [],
            \ 'fmt_output': '`	%s',
            \ 'fmt_error': '!	%s',
            \ 'rx_output': '^[`!]	',
            \ 'fmt_entry': '___[@%04d@]_________[%s]___',
            \ 'rx_entry': '^___\[@\(\d\{4,}\)@\]_________\[\([^]]*\)\]___\+$',
            \ }


function! worksheet#Prototype() "{{{3
    let o = copy(s:prototype)
    let o.entries = {}
    let o.order = []
    let o.buffers = []
    return o
endf


function! s:prototype.BufJoin() dict "{{{3
    call add(s:modes[self.mode], self.bufnr)
    " call add(self.buffers, self.bufnr)
endf


function! s:prototype.BufUnload() dict "{{{3
    exec 'autocmd! Worksheet BufUnload <buffer='. self.bufnr .'>'
    " call remove(self.buffers, index(self.buffers, self.bufnr))
    " TLogVAR self.buffers
    " if empty(self.buffers) && has_key(self, 'Quit')
    if !has_key(s:modes, self.mode)
        echom 'Worksheet: Mode '. self.mode .' not found in: '. string(keys(s:modes))
        return
    endif
    let entry_idx = index(s:modes[self.mode], self.bufnr)
    if entry_idx < 0
        echom 'Worksheet: Buffer '. self.bufnr .' not found in: '. string(s:modes[self.mode])
    else
        call remove(s:modes[self.mode], entry_idx)
    endif
    if empty(s:modes[self.mode])
        unlet s:modes[self.mode]
        if has_key(self, 'Quit')
            call self.Quit()
        endif
    endif
endf


function! s:prototype.NextEntry(rel_pos, create, wrap) dict "{{{3
    let entry_id = self.CurrentEntryId()
    let other_id = self.OtherEntry(entry_id, a:rel_pos, a:wrap)
    return self.GotoEntry(other_id, a:rel_pos, a:create)
endf


function! s:prototype.OtherEntry(entry_id, rel_pos, wrap) dict "{{{3
    let entry_idx = index(self.order, a:entry_id)
    let other_idx = entry_idx + a:rel_pos
    " TLogVAR a:entry_id, entry_idx, a:rel_pos, other_idx, self.order
    if a:wrap
        let other_idx = (other_idx + len(self.order)) % len(self.order)
    endif
    " TLogVAR other_idx
    if other_idx < 1
        let other_id = 1
    elseif other_idx >= len(self.order)
        let other_id = 0
    else
        let other_id = get(self.order, other_idx, 1)
    endif
    " TLogVAR a:entry_id, entry_idx, a:rel_pos, other_id, other_idx, self.order
    return other_id
endf


function! s:prototype.GotoEntry(entry_id, rel_pos, create, ...) dict "{{{3
    let geom = a:0 >= 1 ? a:1 : {}
    " TLogVAR a:entry_id, a:rel_pos, a:create
    if a:entry_id == -1
        let entry_id = self.CurrentEntryId()
        " TLogVAR entry_id
    else
        let entry_id = a:entry_id
    endif
    if entry_id > 0
        let entry = get(self.entries, entry_id, {})
        if !empty(entry)
            " TLogVAR entry.header
            return search(s:RegexpEscape(entry.header), 'cw')
        endif
    elseif a:create
        let dir = a:rel_pos < 0 ? -1 : 1
        let new_id = self.NewEntry(dir, 1)
        " TLogVAR dir, new_id
        return self.HeadOfEntry()
    endif
    return 0
endf


function! s:prototype.NextInputField(rel_pos, create, wrap) dict "{{{3
    let lno = self.NextEntry(a:rel_pos, a:create, a:wrap)
    " TLogVAR lno
    if lno
        " TLogDBG getline('.')
        exec self.EndOfInput(lno + 1)
        if s:IsInputField(self) && &modifiable
            norm! A
        endif
    endif
endf


function! s:prototype.CurrentEntryId() dict "{{{3
    let line = self.HeadOfEntry('n')
    let ml = matchlist(getline(line), self.rx_entry)
    let entry_id = 0 + substitute(get(ml, 1), '^0*', '', '')
    " TLogVAR line, ml, entry_id
    return entry_id
endf


function! s:prototype.Header(entry_id) dict "{{{3
    let tstamp = strftime("%c")
    let header = printf(self.fmt_entry, a:entry_id, tstamp)
    " let fill   = min([50, &columns]) - &fdc - len(header)
    " if fill > 0
    "     let header .= repeat('_', fill)
    " endif
    return header
endf


function! s:prototype.NewEntry(direction, ...) dict "{{{3
    let last_entry = a:0 >= 1 ? a:1 : 0
    if last_entry
        if a:direction > 0
            norm! G
        else
            norm! gg
        endif
    endif

    let entry_id = self.CurrentEntryId()
    " TLogVAR entry_id

    let entry_top = max(keys(self.entries)) + 1
    let head = self.Header(entry_top)
    let self.entries[entry_top] = {'header': head}
    let pos = index(self.order, entry_id)
    if a:direction > 0
        let pos += 1
    endif
    if pos < 0
        let pos = 0
    elseif pos > len(self.order)
        let pos = len(self.order)
    endif
    call insert(self.order, entry_top, pos)
    " TLogVAR entry_top, head, pos, self.order

    if a:direction < 0
        let lno = self.HeadOfEntry() - 1
    else
        let lno = self.EndOfOutput()
    endif
    if lno < 0
        let lno = 0
    elseif lno > line('$')
        let lno = line('$')
    endif

    let modifiable = &modifiable
    setlocal modifiable
    call append(lno, head)
    exec lno + 1
    norm! o

    return entry_top
endf


function! s:prototype.HeadOfEntry(...) dict "{{{3
    let flags = 'cW'
    if a:0 >= 1
        let flags .= a:1
    endif
    let line = search(self.rx_entry, 'b'. flags)
    " TLogVAR line
    if !line
        let line = search(self.rx_entry, flags)
        " TLogVAR line
    endif
    return line
endf


function! s:prototype.EndOfInput(...) "{{{3
    let line = a:0 >= 1 ? a:1 : self.HeadOfEntry() + 1
    if line
        let bot = line('$')
        while line < bot && s:IsInputField(self, line + 1)
            let line += 1
        endwh
    endif
    return line
endf


function! s:prototype.EndOfOutput() "{{{3
    let bot = line('$')
    let line = line('.')
    while line < bot && getline(line + 1) !~ self.rx_entry
        let line += 1
    endwh
    return line
endf


function! s:ReplaceVariable(entry_id, worksheet) "{{{3
    let entry = get(a:worksheet.entries, a:entry_id, {})
    " TLogVAR entry
    return get(entry, 'output', '')
endf


function! s:prototype.PrepareInput(line) dict "{{{3
    let line = substitute(a:line, '\\\@<!\zs@\(\w\+\)@', '\=<SID>ReplaceVariable(submatch(1), self)', 'g')
    " TLogVAR a:line, line
    let line = substitute(line, '\\\@<!\zs\\@', '@', 'g')
    " TLogVAR line
    let rules = get(g:worksheet#rewrite, 'mode', [])
    for rule in rules
        let line = call('substitute', rule)
    endfor
    return line
endf


function! s:prototype.Keyword() dict "{{{3
    norm! K
endf


function! s:prototype.SetInput(entry_id, lines) dict "{{{3
    " TLogVAR a:entry_id, a:lines
    let entry_id = a:entry_id > 0 ? a:entry_id : self.CurrentEntryId()
    let ebeg = self.HeadOfEntry()
    let ibeg = ebeg + 1
    let iend = self.EndOfInput()
    " TLogVAR ibeg, iend
    let modifiable = &modifiable
    setlocal modifiable
    try
        if iend > ibeg
            exec ibeg .','. iend .'delete'
        endif
        call setline(ibeg, a:lines)
    finally
        if !modifiable
            setlocal nomodifiable
        endif
    endtry
    return 1
endf


function! s:prototype.Yank(entry_id, what) dict "{{{3
    " TLogVAR a:entry_id, a:what
    let entry_id = a:entry_id > 0 ? a:entry_id : self.CurrentEntryId()
    " TLogVAR entry_id
    let entry = get(self.entries, entry_id, {})
    " TLogVAR entry
    if !empty(entry)
        let reg = v:register
        let v = get(entry, a:what, '')
        if !empty(v)
            call setreg(reg, v)
        elseif s:IsInputField(self)
            let pos = getpos('.')
            try
                let ebeg = self.HeadOfEntry()
                let eend = self.EndOfInput()
                if ebeg < eend
                    let lines = getline(ebeg + 1, eend)
                    " TLogVAR ebeg, eend, lines
                    call setreg(reg, join(lines, "\n"))
                endif
            finally
                call setpos('.', pos)
            endtry
        endif
    endif
endf


function! s:prototype.YankAll() "{{{3
    let reg = v:register
    let rval = getreg(reg)
    let pos = getpos('.')
    let out = []
    try
        for entry_id in self.order
            " TLogVAR entry_id
            call setreg(reg, "")
            call self.Yank(entry_id, 'string')
            let val = getreg(reg)
            " TLogVAR val
            if !empty(val)
                call add(out, val)
            endif
        endfor
    finally
        call setpos('.', pos)
    endtry
    let sout = join(out, "\n\n")
    " TLogVAR sout
    if empty(sout)
        call setreg(reg, rval)
    else
        call setreg(reg, sout)
    endif
endf


function! s:prototype.SwapEntries(rel_pos) dict "{{{3
    let entry_id = self.CurrentEntryId()
    let cp  = index(self.order, entry_id)
    let other_id = self.OtherEntry(entry_id, a:rel_pos, 1)
    let op  = index(self.order, other_id)
    let self.order[cp] = other_id
    let self.order[op] = entry_id
    call worksheet#Restore()
    exec self.GotoEntry(entry_id, 0, 0)
    exec self.EndOfInput()
endf


function! s:prototype.SilentInput(input) dict "{{{3
    if a:input[-1][-1 : -1] == ';'
        let a:input[-1] = a:input[-1][0 : -2]
        return [1, a:input]
    else
        return [0, a:input]
    endif
endf


function! s:prototype.CurrentItemGeometry() dict "{{{3
    let geom = {'pos': getpos('.')}
    try
        let geom.head_lno = self.HeadOfEntry()
        let geom.pos_rlnum = line('.') - geom.head_lno
        exec geom.head_lno
        let geom.entry_id = self.CurrentEntryId()
        let geom.in_beg = geom.head_lno + 1
        let geom.in_end = self.EndOfInput(geom.in_beg)
        " TLogVAR geom.in_beg, geom.in_end
        if !s:IsInputField(self, geom.in_beg)
            throw 'Worksheet: Cannot find input field'
        endif
        let input = getline(geom.in_beg, geom.in_end)
        let [geom.silent, geom.input] = self.SilentInput(input)
        let geom.prepared_input = copy(geom.input)
        let geom.prepared_input = filter(geom.prepared_input, 'v:val[0] != "%"')
        let geom.prepared_input = map(geom.prepared_input, 'self.PrepareInput(v:val)')
    finally
        call setpos('.', geom.pos)
    endtry
    return geom
endf


" Special syntax:
" Last character is ";" ... silent
" Leading character is "%" ... comment
function! s:prototype.Submit() dict "{{{3
    let pos = getpos('.')
    let s:processing = 1
    try
        let geom = self.CurrentItemGeometry()
        " TLogVAR geom.silent, geom.input
        if has_key(self, 'Evaluate')
            let output = self.Evaluate(geom.prepared_input)
            call self.SetOutput(geom, output)
        elseif has_key(self, 'EvaluateAsync')
            call self.EvaluateAsync(geom, geom.prepared_input)
        endif
    finally
        let s:processing = 0
        call setpos('.', pos)
    endtry
endf


function! s:prototype.SetOutputAsync(geom, output) dict "{{{3
    let pos = getpos('.')
    let geom0 = self.CurrentItemGeometry()
    try
        if (geom0.entry_id != a:geom.entry_id)
            call self.GotoEntry(a:geom.entry_id, 0, 0)
        endif
        let geom = self.CurrentItemGeometry()
        if geom.entry_id != a:geom.entry_id
            throw "Worksheet: Cannot move to item ". a:geom.entry_id
        endif
        call self.SetOutput(geom, a:output)
    finally
        call setpos('.', pos)
        if (geom0.entry_id != a:geom.entry_id)
            call self.GotoEntry(geom0.entry_id, 0, 0, geom0)
        endif
    endtry
endf


function! s:prototype.SetOutput(geom, output) dict "{{{3
    let out_beg = a:geom.in_end + 1
    if out_beg <= line('$')
        let out_end = self.EndOfOutput()
        " TLogVAR out_beg, out_end
        if out_end <= 0
            let out_end = line('$')
        endif
        if out_end >= out_beg
            silent exec out_beg .','. out_end .'delete'
        endif
    endif
    " TLogVAR a:output
    if type(a:output) == 4
        let [out_body, out_lines] = s:GetBodyLines(get(a:output, 'out', ''))
        let [err_body, err_lines] = s:GetBodyLines(get(a:output, 'err', ''))
    else
        let [out_body, out_lines] = s:GetBodyLines(a:output)
        let [err_body, err_lines] = s:GetBodyLines('')
    endif
    call map(out_lines, 'printf(self.fmt_output, v:val)')
    call map(err_lines, 'printf(self.fmt_error, v:val)')
    call append(a:geom.in_end, err_lines)
    if !a:geom.silent && !empty(out_lines)
        call append(a:geom.in_end, out_lines)
    endif
    let header = self.Header(a:geom.entry_id)
    call setline(a:geom.head_lno, header)
    let self.entries[a:geom.entry_id].header = header
    let self.entries[a:geom.entry_id].geom = a:geom
    let self.entries[a:geom.entry_id].input = a:geom.input
    let self.entries[a:geom.entry_id].string = join(a:geom.input, "\n")
    let self.entries[a:geom.entry_id].value = a:output
    let self.entries[a:geom.entry_id].output = out_body
    let self.entries[a:geom.entry_id].lines = out_lines
endf


function! s:GetBodyLines(output) "{{{3
    if type(a:output) <= 1
        let body  = a:output
        let lines = split(a:output, "\n")
    elseif type(a:output) == 3
        let body = join(a:output, "\n")
        let lines = a:output
    else
        throw 'Worksheet: Unexpected type: '. string(a:output)
    endif
    return [body, lines]
endf



" call TLogDBG(string(s:prototype))
