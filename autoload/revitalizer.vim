let g:revitalizer#debug = get(g:, 'revitalizer#debug', 0)

let s:V = g:revitalizer#debug ? vital#of('vital') : vital#revital#of()
let s:File = s:V.import('System.File')
let s:Filepath = s:V.import('System.Filepath')
let s:ScriptLocal = s:V.import('Vim.ScriptLocal')
let s:Dict = s:V.import('Data.Dict')
let s:I = s:V.import('Data.String.Interpolation')
let s:Message = s:V.import('Vim.Message')

let s:REVITAL_FILE = s:Filepath.join(expand('<sfile>:h'), 'vital', 'revital.vim')
let s:DATA_DIR = s:Filepath.join(expand('<sfile>:h:h'), 'data', 'vital')
" Insert s:AUTOLOADABLIZE_TEMPLATE to each module files:)
let s:AUTOLOADABLIZE_TEMPLATE = readfile(s:Filepath.join(s:DATA_DIR, 'autoloadablize.vim'))

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
  let self.vital_files = sort(self.get_vital_files())
  " Load all vital files before calling s:ScriptLocal.scriptnames()
  " We cannot source files which aren't in runtimepath with `:runtime!`, so
  " `:source` the file later if the file is not found in self.path2sid
  let in_runtime_path = globpath(&rtp, self.vital_dir_rel) !=# ''
  if in_runtime_path
    execute 'runtime!' s:Filepath.join(self.vital_dir_rel, '/autoload/vital/**/*.vim')
  else
    call self.source_modules()
  endif
  let self.path2sid = s:Dict.swap(s:ScriptLocal.scriptnames())
endfunction

function! s:Revitalizer.source_modules() abort
  for f in self.vital_files
    call s:_source(f)
  endfor
endfunction

function! s:Revitalizer.revitalize() abort
  let module_data = {}
  for f in self.vital_files
    call extend(module_data, self.autoloadablize(f), 'error')
  endfor
  " TODO: embed module_data
  " TODO: gather self module data
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
  if !self.is_autoloadablized(a:vital_file)
    let save_module_lines = readfile(a:vital_file)
    call writefile(split(s:I.s(join(s:AUTOLOADABLIZE_TEMPLATE, "\n"), data), "\n"), a:vital_file)
    call writefile(save_module_lines, a:vital_file, 'a')
  endif
  return data.module
endfunction

function! s:Revitalizer.is_autoloadablized(vital_file) abort
  return get(readfile(a:vital_file, '', 1), 0, '') ==# s:AUTOLOADABLIZE_TEMPLATE[0]
endfunction

function! s:Revitalizer.autoloadablize_data(vital_file) abort
  let sid = self.sid(a:vital_file)
  let sfuncs = s:ScriptLocal.sid2sfuncs(sid)
  " It doesn't need to filter functions here because Vital.import() will
  " filter them after calling module._vital_loaded() and module._vital_created().
  " However, this line collects functions here including module._vital_*() to
  " reduce the size of autoloadablize code.
  " sort() functions not to generate unneeded diff.
  let functions = sort(keys(filter(sfuncs, 'v:key =~# "^\\a" || v:key =~# "^_vital_"')))
  " Create funcdict which key is function name and value is empty string.
  " map() values to create Funcref in template file.
  let funcdict = {}
  for funcname in functions
    let funcdict[funcname] = ''
  endfor
  let autoload_import = self.autoload_path(a:vital_file) . '#import'
  return {
  \   'autoload_import': autoload_import,
  \   'funcdict': string(funcdict),
  \   'module': {
  \     self.module_name(a:vital_file): {
  \       'autoload_import': autoload_import,
  \       'is_self_module': 0,
  \     }
  \   },
  \ }
endfunction

function! s:Revitalizer.sid(path) abort
  let sid = get(self.path2sid, a:path, -1)
  if sid is# -1
    " NOTE: s:ScriptLocal.sid() calls :scriptnames each times, so make sure
    " that almost all of vital_files is in :scriptnames
    let sid = s:ScriptLocal.sid(a:path)
    if sid is# -1
      call s:Revitalizer.throw(printf('Unexpected error: %s cannot be sourced', a:path))
    endif
  endif
  return sid
endfunction

function! s:Revitalizer.autoload_path(vital_file) abort
  let vital_file = s:Filepath.unixpath(a:vital_file)
  let prd = s:Filepath.unixpath(self.project_root_dir)
  return substitute(vital_file[len(s:Filepath.join(prd, 'autoload/')):], '/', '#', 'g')[:- (len('.vim') + 1)]
endfunction

function! s:Revitalizer.module_name(vital_file) abort
  let prd = s:Filepath.unixpath(self.project_root_dir)
  let tokens = s:Filepath.split(a:vital_file[len(prd):])[len(['autoload', 'vital', '_pluginname']):]
  return join(tokens, '.')[:- (len('.vim') + 1)]
endfunction

" s:Revitalizer.get_vital_files() lists all embedded vital viles of a project.
" a:project_root_dir is same as {target-dir} in :h :Vitalize
" @return {list<string>}
function! s:Revitalizer.get_vital_files() abort
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
