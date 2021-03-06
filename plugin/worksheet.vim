" worksheet.vim Worksheets (Log of interaction with an interpreter)
" @Author:      Tom Link (micathom AT gmail com?subject=[vim])
" @Website:     http://www.vim.org/account/profile.php?user_id=4037
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2008-07-15.
" @Last Change: 2013-11-14.
" @Revision:    111
" GetLatestVimScripts: 0 0 worksheet.vim

if &cp || exists("loaded_worksheet")
    finish
endif
if !exists('g:loaded_hookcursormoved') || g:loaded_hookcursormoved < 9
    echoerr 'hookcursormoved >= 0.9 is required'
    finish
endif
let loaded_worksheet = 1

let s:save_cpo = &cpo
set cpo&vim


if !exists('g:worksheet_suffix')
    " The suffix for saved worksheets.
    " TODO: If non-empty, this will also add a line to the filetypedetect 
    " autogroup.
    let g:worksheet_suffix = '.vwks'   "{{{2
endif
if !empty(g:worksheet_suffix) && exists('tml_vimfiles')
    " exec 'au filetypedetect BufNewFile,BufRead *'. g:worksheet_suffix .' call worksheet#Setfiletype(matchstr(expand("<afile>"), "\\V_\\zs\\.\\{-}\\ze". g:worksheet_suffix ."\\$"))'
    exec 'au filetypedetect BufNewFile,BufRead *'. g:worksheet_suffix .' call worksheet#RestoreBuffer()'
endif


" @TPluginInclude
if !exists('g:worksheet_map')
    let g:worksheet_map = '<Leader>x'   "{{{2
endif
if !empty(g:worksheet_map)
    exec 'nnoremap '. g:worksheet_map .'x :<c-u>call worksheet#EvaluateLinesInWorksheet(&filetype, getline(line("."), line(".") + v:count))<cr>'
    exec 'xnoremap '. g:worksheet_map .'x :call worksheet#EvaluateLinesInWorksheet(&filetype, getline(line("''<"), line("''>")))<cr>'
    exec 'nnoremap '. g:worksheet_map .' :set opfunc=worksheet#Operator<cr>g@'
endif


" :display: :Worksheet [TYPE]
" Open a new worksheet.
command! -narg=* -complete=customlist,worksheet#Complete Worksheet call worksheet#UseWorksheet(<f-args>)


let &cpo = s:save_cpo
unlet s:save_cpo
