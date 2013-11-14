" worksheet.vim
" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     http://www.vim.org/account/profile.php?user_id=4037
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2008-07-15.
" @Last Change: 2013-11-14.
" @Revision:    0.0.83

if version < 600
    syntax clear
elseif exists("b:current_syntax")
    finish
endif

syntax match WorksheetId /\\\@!\zs@\w\+@/

try
    " exec 'runtime syntax/'. b:worksheet.mode .'.vim'
    exec 'syntax include @WorksheetInputSyntax syntax/'. b:worksheet.syntax .'.vim'
    " unlet b:current_syntax
    syntax match WorksheetInput /^[^%`_].*/ transparent contains=@WorksheetInputSyntax,WorksheetId
catch
    syntax match WorksheetInput /^[^%`_].*/ transparent contains=WorksheetId
endtry

syntax match WorksheetHead /^___\[@\d\{4,}@\]_________\[.\{-}\]___\+$/ contains=WorksheetId nextgroup=WorksheetInput
syntax match WorksheetBody /^`	.*/ contains=WorksheetBodyPrefix
syntax match WorksheetError /^!	.*/ contains=WorksheetErrorPrefix
if has('conceal')
    syntax match WorksheetBodyPrefix /^`	/ contained containedin=WorksheetBody conceal cchar=
    syntax match WorksheetErrorPrefix /^!	/ contained containedin=WorksheetError conceal cchar=
else
    syntax match WorksheetBodyPrefix /^`	/ contained containedin=WorksheetBody
    syntax match WorksheetErrorPrefix /^!	/ contained containedin=WorksheetError
endif
syntax match WorksheetComment /^%.*/


if version < 508
    command! -nargs=+ HiLink hi link <args>
else
    command! -nargs=+ HiLink hi def link <args>
endif
HiLink WorksheetHead Question
HiLink WorksheetId TagName
HiLink WorksheetBody Statement
HiLink WorksheetError ErrorMsg
HiLink WorksheetComment Comment


delcommand HiLink
let b:current_syntax = 'worksheet'
