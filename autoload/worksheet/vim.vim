" vim.vim
" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     http://www.vim.org/account/profile.php?user_id=4037
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2008-07-15.
" @Last Change: 2010-09-19.
" @Revision:    0.0.99

let s:prototype = {'syntax': 'vim'}


" If the first character is "|", the input string will be processed with 
" |:execute|. Otherwise |eval()| will be used.
function! s:prototype.Evaluate(lines) dict "{{{3
    let lines = copy(a:lines)
    call filter(lines, 'v:val !~ ''^\s*"''')
    " call map(lines, 'substitute(v:val, ''^\([^"]*\|\\.\|"\(\\.\|[^"\]*\)"\)\+\zs".*$'', "", "")')
    call map(lines, '":". v:val')
    let vim = join(lines, "\n") ."\n"
    " TLogVAR vim
    redir => out
    exec 'silent normal' vim
    redir END
    return out
endf


function! worksheet#vim#InitializeInterpreter(worksheet) "{{{3
endf


function! worksheet#vim#InitializeBuffer(worksheet) "{{{3
    call extend(a:worksheet, s:prototype)
    runtime indent/vim.vim
    runtime ftplugin/vim.vim
endf

