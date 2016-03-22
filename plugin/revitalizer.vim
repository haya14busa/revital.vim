"=============================================================================
" FILE: plugin/revitalizer.vim
" AUTHOR: haya14busa
" License: MIT license
"=============================================================================
scriptencoding utf-8
if expand('%:p') ==# expand('<sfile>:p')
  unlet! g:loaded_revitalizer
endif
if exists('g:loaded_revitalizer')
  finish
endif
let g:loaded_revitalizer = 1
let s:save_cpo = &cpo
set cpo&vim

" :Revitalize {target-dir}
command! -nargs=1 -complete=dir Revitalize call revitalizer#command([<f-args>])

let &cpo = s:save_cpo
unlet s:save_cpo
" __END__
" vim: expandtab softtabstop=2 shiftwidth=2 foldmethod=marker
