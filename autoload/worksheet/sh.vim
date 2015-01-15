" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     http://www.vim.org/account/profile.php?user_id=4037
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Revision:    14


let s:prototype = {'syntax': 'sh'}


function! s:prototype.Evaluate(lines) dict "{{{3
    return system(join(a:lines, "\n"))
endf


function! worksheet#sh#InitializeInterpreter(worksheet) "{{{3
endf


function! worksheet#sh#InitializeBuffer(worksheet) "{{{3
    call extend(a:worksheet, s:prototype)
    runtime indent/sh.vim
    runtime ftplugin/sh.vim
endf


