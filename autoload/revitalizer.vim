let g:revitalizer#debug = get(g:, 'revitalizer#debug', 0)

let s:V = g:revitalizer#debug ? vital#of('vital') : vital#revital#of()
let s:File = s:V.import('System.File')
let s:Filepath = s:V.import('System.Filepath')
let s:ScriptLocal = s:V.import('Vim.ScriptLocal')
let s:Dict = s:V.import('Data.Dict')
let s:I = s:V.import('Data.String.Interpolation')
let s:Message = s:V.import('Vim.Message')

let s:REVITAL_FILE = s:Filepath.join(expand('<sfile>:h'), 'vital', 'revital.vim')
let s:build_vital_data = s:ScriptLocal.sfuncs('autoload/vitalizer.vim').build_vital_data

function! revitalizer#command(args) abort
  let target_dir = fnamemodify(a:args[0], ':p')
  try
    let revitalizer = s:new(target_dir)
    call revitalizer.revitalize()
  catch /Revitalizer:/
    call s:Message.error(v:exception)
    return
  endtry
  call s:Message.echomsg('MoreMsg', printf('succeeded to revitalize %s', target_dir))
endfunction

" s:Revitalizer re-:Vitalize vital modules to call them via autoload function.
" 1. replace vital#of({vital-name}) with vital#_{vital-name}#of()
" 2. mock vital object's methods. NOTE: .import() and .load() have to call
"    module._vital_created(V) and module._vital_loaded(V).
"   - :h Vital-Vital.import()
"   - :h Vital-Vital.load()
"   - :h Vital-Vital.exists()
"   - :h Vital-Vital.search()
let s:Revitalizer = {}

function! s:new(...) abort
  let base = deepcopy(s:Revitalizer)
  call call(base.__init__, a:000, base)
  return base
endfunction

function! s:Revitalizer.__init__(project_root_dir) abort
  let self.project_root_dir = fnamemodify(a:project_root_dir, ':p')
  let self.vital_data = s:build_vital_data(self.project_root_dir, '')
  if !filereadable(self.vital_data.vital_file)
    call self.throw(printf('%s not found. Please :Vitalize before :Revitalize', self.vital_data.vital_file))
  endif
  let self.vital_dir_rel = s:Filepath.join('autoload', 'vital', '_' . self.vital_data.name)
  let self.vital_dir = s:Filepath.join([self.project_root_dir, self.vital_dir_rel])
  " Load all vital files before calling s:ScriptLocal.scriptnames()
  " We cannot source files which aren't in runtimepath with `:runtime!`, so
  " `:source` the file later if the file is not found in self.path2sid
  let in_runtime_path = globpath(&rtp, self.vital_dir_rel) !=# ''
  if in_runtime_path
    execute 'runtime!' s:Filepath.join(self.vital_dir_rel, '/**/*.vim')
  else
    call self.source_modules()
  endif
  let self.path2sid = s:Dict.swap(s:ScriptLocal.scriptnames())
endfunction

function! s:Revitalizer.source_modules() abort
  for f in self.vital_files()
    call s:_source(f)
  endfor
endfunction

function! s:Revitalizer.revitalize() abort
  for f in filter(self.vital_files(), '!self.is_autoloadablized(v:val)')
    call self.autoloadablize(f)
  endfor
  call self.copy_revital_of()
endfunction

function! s:Revitalizer.copy_revital_of() abort
  let dest = s:Filepath.join(fnamemodify(self.vital_dir, ':h'), printf('%s.vim', self.vital_data.name))
  call s:File.copy(s:REVITAL_FILE, dest)
endfunction

" Use s:ScriptLocal.sid2sfuncs(sid) and s:ScriptLocal.scriptnames() in .new()
" instead of s:ScriptLocal.sfuncs(path) not to execute `:scriptnames` for each
" time.
" @param {string} vital_file vital_file is a fullpath of vital modules
function! s:Revitalizer.autoloadablize(vital_file) abort
  let data = self.autoloadablize_data(a:vital_file)
  call writefile(split(s:I.s(join(s:auto_loadable_template, "\n"), data), "\n"), a:vital_file, 'a')
endfunction

function! s:Revitalizer.is_autoloadablized(vital_file) abort
  return get(readfile(a:vital_file, '', -1), 0, '') ==# s:auto_loadable_template[-1]
endfunction

function! s:Revitalizer.autoloadablize_data(vital_file) abort
  let sid = get(self.path2sid, a:vital_file, -1)
  if sid is# -1
    " NOTE: s:ScriptLocal.sid() calls :scriptnames each times, so make sure
    " that almost all of vital_files is in :scriptnames
    let sid = s:ScriptLocal.sid(a:vital_file)
    if sid is# -1
      call s:Revitalizer.throw(printf('Unexpected error: %s cannot be sourced', a:vital_file))
    endif
  endif
  " It doesn't need to filter functions here because Vital.import() will
  " filter them after calling module._vital_loaded() and module._vital_created().
  " However, this line collects functions here including module._vital_*() to
  " reduce the size of autoloadablize code.
  " sort() functions not to generate unneeded diff.
  let functions = sort(keys(filter(s:ScriptLocal.sid2sfuncs(sid), 'v:key =~# "^\\a" || v:key =~# "^_vital_"')))
  return {
  \   'autoload_path': self.autoload_path(a:vital_file),
  \   'key_to_function': '{' . join(map(functions, "printf(\"'%s': s:___revitalizer_function___('s:%s')\", v:val, v:val)"), ',') . '}'
  \ }
endfunction

function! s:Revitalizer.autoload_path(vital_file) abort
  return substitute(a:vital_file[len(s:Filepath.join(self.project_root_dir . 'autoload/')):], '/', '#', 'g')[:- (len('.vim') + 1)]
endfunction

" NOTE: it doesn't support `:finish` statement in module files
let s:auto_loadable_template = [
\ '" ___Revitalizer___',
\ '" NOTE: below code is generated by :Revitalize.',
\ '" Do not mofidify the code nor append new lines',
\ "if v:version > 703 || v:version == 703 && has('patch1170')",
\ "  function! s:___revitalizer_function___(fstr) abort",
\ "    return function(a:fstr)",
\ "  endfunction",
\ "else",
\ "  function! s:___revitalizer_SID() abort",
\ "    return matchstr(expand('<sfile>'), '<SNR>\\zs\\d\\+\\ze____revitalizer_SID$')",
\ "  endfunction",
\ "  let s:___revitalizer_sid = '<SNR>' . s:___revitalizer_SID() . '_'",
\ "  function! s:___revitalizer_function___(fstr) abort",
\ "    return function(substitute(a:fstr, 's:', s:___revitalizer_sid, 'g'))",
\ "  endfunction",
\ "endif",
\ "",
\ "let s:___revitalizer_functions___ = ${key_to_function}",
\ "",
\ "unlet! s:___revitalizer_sid",
\ "delfunction s:___revitalizer_function___",
\ "",
\ "function! ${autoload_path}#import() abort",
\ "  return s:___revitalizer_functions___",
\ "endfunction",
\ '" ___Revitalizer___',
\ ]

" s:Revitalizer.vital_files() lists all embedded vital viles of a project.
" a:project_root_dir is same as {target-dir} in :h :Vitalize
" @return {list<string>}
function! s:Revitalizer.vital_files() abort
  let vital_name = self.vital_data.name
  let path = s:Filepath.join(self.vital_dir)
  return s:ls_R_vimfiles(path)
endfunctio

function! s:Revitalizer.throw(message) abort
  throw printf('Revitalizer: %s', a:message)
endfunction

" -- helper

" s:ls_R_vimfiles() returns list of vim files under given a:path recursively.
" @param {string} path
" @return {list<string>}
function! s:ls_R_vimfiles(path) abort
  return split(glob(s:Filepath.join(a:path, '/**/*.vim'), 1), "\n")
endfunction

function! s:_source(path) abort
  try
    execute ':source' fnameescape(a:path)
  catch /^Vim\%((\a\+)\)\=:E121/
    " NOTE: workaround for `E121: Undefined variable: s:save_cpo`
    execute ':source' fnameescape(a:path)
  endtry
endfunction
