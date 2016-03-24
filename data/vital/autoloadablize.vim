" ___vital___
" NOTE: lines between '" ___vital___' is generated by :Vitalize.
" Do not mofidify the code nor insert new lines before '" ___vital___'
let s:___vital_function___ = 'function'
if !(v:version > 703 || v:version == 703 && has('patch1170'))
  let s:___vital_function___ = 's:___vital_function___'
  function! s:_SID() abort
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze__SID$')
  endfunction
  let s:___vital_sfunc_prefix___ = '<SNR>' . s:_SID() . '_'
  delfunction s:_SID

  function! s:___vital_function___(fstr) abort
    return function(substitute(a:fstr, '^s:', s:___vital_sfunc_prefix___, ''))
  endfunction
endif

function! ${autoload_import}() abort
  return map(${funcdict},  printf("{%s}('s:%s')", s:___vital_function___, v:key))
endfunction
" ___vital___
