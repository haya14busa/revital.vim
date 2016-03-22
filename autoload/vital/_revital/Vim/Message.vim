let s:save_cpo = &cpo
set cpo&vim



function! s:echo(hl, msg) abort
  execute 'echohl' a:hl
  try
    echo a:msg
  finally
    echohl None
  endtry
endfunction

function! s:echomsg(hl, msg) abort
  execute 'echohl' a:hl
  try
    for m in split(a:msg, "\n")
      echomsg m
    endfor
  finally
    echohl None
  endtry
endfunction

function! s:error(msg) abort
  call s:echomsg('ErrorMsg', a:msg)
endfunction

function! s:warn(msg) abort
  call s:echomsg('WarningMsg', a:msg)
endfunction

function! s:capture(command) abort
  try
    redir => out
    silent execute a:command
  finally
    redir END
  endtry
  return out
endfunction

" * Get max length of |hit-enter|.
"   If a string length of a message is greater than the max length,
"   Vim waits for user input according to |hit-enter|.
" XXX: Those fixed values may be different between different OSes?
"      Currently tested on only Windows.
function! s:get_hit_enter_max_length() abort
  let maxlen = &columns * &cmdheight - 1
  if &ruler
    " TODO
  endif
  if &showcmd
    let maxlen -= 11
  endif
  return maxlen
endfunction



let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:
" ___Revitalizer___
" NOTE: below code is generated by :Revitalize.
" Do not mofidify the code nor append new lines
if v:version > 703 || v:version == 703 && has('patch1170')
  function! s:___revitalizer_function___(fstr) abort
    return function(a:fstr)
  endfunction
else
  function! s:___revitalizer_SID() abort
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze____revitalizer_SID$')
  endfunction
  let s:___revitalizer_sid = '<SNR>' . s:___revitalizer_SID() . '_'
  function! s:___revitalizer_function___(fstr) abort
    return function(substitute(a:fstr, 's:', s:___revitalizer_sid, 'g'))
  endfunction
endif

let s:___revitalizer_functions___ = {'capture': s:___revitalizer_function___('s:capture'),'echomsg': s:___revitalizer_function___('s:echomsg'),'get_hit_enter_max_length': s:___revitalizer_function___('s:get_hit_enter_max_length'),'echo': s:___revitalizer_function___('s:echo'),'warn': s:___revitalizer_function___('s:warn'),'error': s:___revitalizer_function___('s:error')}

unlet! s:___revitalizer_sid
delfunction s:___revitalizer_function___

function! vital#_revital#Vim#Message#import() abort
  return s:___revitalizer_functions___
endfunction
" ___Revitalizer___
