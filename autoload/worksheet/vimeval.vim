" vim.vim
" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     http://www.vim.org/account/profile.php?user_id=4037
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2008-07-15.
" @Last Change: 2010-04-23.
" @Revision:    0.0.62

let s:prototype = {'syntax': 'vimeval'}


" If the first character is "|", the input string will be processed with 
" |:execute|. Otherwise |eval()| will be used.
function! s:prototype.Evaluate(lines) dict "{{{3
    let vim = join(a:lines, "\n")
    return string(eval(vim))
endf


function! worksheet#vimeval#InitializeInterpreter(worksheet) "{{{3
    call worksheet#vim#InitializeInterpreter(a:worksheet)
endf


function! worksheet#vimeval#InitializeBuffer(worksheet) "{{{3
    call worksheet#vim#InitializeBuffer(a:worksheet)
    call extend(a:worksheet, s:prototype)
endf

