" vim.vim
" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     http://www.vim.org/account/profile.php?user_id=4037
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2008-07-15.
" @Last Change: 2013-11-14.
" @Revision:    0.0.75

let s:prototype = {'syntax': 'vimeval'}


function! s:prototype.Evaluate(lines) dict "{{{3
    let lines = []
    for line in a:lines
        if !empty(lines) && line =~ '^\s*\\'
            let lines[-1] .= substitute(line, '^\s*\\', '', '')
        else
            call add(lines, line)
        endif
    endfor
    try
        let rv = []
        for line in lines
            if line =~ '^\s*:'
                call worksheet#vim#Evaluate([line])
            elseif line =~ '^\s*\([bwgsl]:\)\?\w\+\s*='
                call worksheet#vim#Evaluate([':let '. line])
            elseif line =~ '^\s*\(s:\)\?\u\w*(.\{-})\s*='
                let m = matchlist(line, '^\s*\(\(s:\)\?\u\w*(.\{-})\)\s*=\(.\+\)$')
                if !empty(m)
                    call worksheet#vim#Evaluate(['function! '. m[1], m[3], 'endf'])
                endif
            else
                let val = string(eval(line))
                call add(rv, val)
            endif
        endfor
        return join(rv, "\n")
    catch
        return {'err': v:exception}
    endtry
endf


function! worksheet#vimeval#InitializeInterpreter(worksheet) "{{{3
    call worksheet#vim#InitializeInterpreter(a:worksheet)
endf


function! worksheet#vimeval#InitializeBuffer(worksheet) "{{{3
    call worksheet#vim#InitializeBuffer(a:worksheet)
    call extend(a:worksheet, s:prototype)
endf

