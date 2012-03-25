" vim.vim
" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     http://www.vim.org/account/profile.php?user_id=4037
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2008-07-15.
" @Last Change: 2012-03-25.
" @Revision:    0.0.101

let s:prototype = {'syntax': 'vim'}


" If the first character is "|", the input string will be processed with 
" |:execute|. Otherwise |eval()| will be used.
function! s:prototype.Evaluate(lines) dict "{{{3
    return worksheet#vim#Evaluate(a:lines)
endf


function! worksheet#vim#Evaluate(lines) "{{{3
    let t = @t
    try
        let @t = join(a:lines, "\n")
        redir => out
        @t
        redir END
        return out
    finally
        let @t = t
    endtry
endf


function! worksheet#vim#InitializeInterpreter(worksheet) "{{{3
endf


function! worksheet#vim#InitializeBuffer(worksheet) "{{{3
    call extend(a:worksheet, s:prototype)
    runtime indent/vim.vim
    runtime ftplugin/vim.vim
endf

