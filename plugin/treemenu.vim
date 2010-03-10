" vim:fdm=marker:
"
" TreeMenu {{{
" Version: 0.3
" Author:  Cornelius <cornelius.howl@gmail.com>
" ScriptType: plugin

if exists('g:treemenu_loaded')
  "finish
endif
let g:treemenu_loaded = 1

fun! s:FoundNode(node)
  if type(a:node) == type({}) && has_key(a:node,'id')
    return 1
  else
    return 0
  endif
endf

" MenuBuffer Class {{{
let g:MenuBuffer = { 'buf_nr' : -1 , 'root': {}  }

fun! g:MenuBuffer.create(options)
  let menu_obj = copy(self)
  let menu_obj.root = g:MenuItem.create({ 'label': 'root' })
  cal extend(menu_obj,a:options)
  cal menu_obj.init_buffer()
  return menu_obj
endf

fun! g:MenuBuffer.init_buffer()
  let win = self.findWindow(1)
  setfiletype MenuBuffer
  setlocal buftype=nofile bufhidden=hide nonu nohls
  setlocal fdc=0
  setlocal cursorline

  syn match MenuId +\[\d\+\]$+
  syn match MenuPre  "^[-+~|]\+"
  syn match MenuLabelExecutable +\(^[-]-*\)\@<=[a-zA-Z0-9-()._/ ]*+
  syn match MenuLabelExpanded   +\(^[~]-*\)\@<=[a-zA-Z0-9-()._/ ]*+
  syn match MenuLabelCollapsed  +\(^[+]-*\)\@<=[a-zA-Z0-9-()._/ ]*+

  hi MenuId ctermfg=black ctermbg=black
  hi MenuPre ctermfg=darkblue
  hi CursorLine cterm=underline

  hi MenuLabelExpanded ctermfg=blue
  hi MenuLabelCollapsed ctermfg=yellow
  hi MenuLabelExecutable ctermfg=white

  let b:_menu = self

  nnoremap <silent><buffer> o :cal b:_menu.toggleCurrent()<CR>
  nnoremap <silent><buffer> O :cal b:_menu.toggleCurrentR()<CR>
  nnoremap <silent><buffer> <Enter>  :cal b:_menu.execCurrent()<CR>
endf

fun! g:MenuBuffer.setBufNr(nr)
  let self.buf_nr = a:nr
endf

fun! g:MenuBuffer.addItem(item)
  return self.root.createChild(a:item)
endf

fun! g:MenuBuffer.addPath(path,args)
  let labels = split(a:path,'\.')
  let last_label = labels[ len( labels ) - 1 ]
  let node = self.root

  while s:FoundNode(node) && len(labels) > 0
    let label = remove( labels , 0 )
    let next_node = node.findChildByLabel( label )

    if ! s:FoundNode(next_node) 
      let next_node = node.createChild({ 'label': label })
    endif

    let node = next_node
    unlet label
  endwhile


  if s:FoundNode(node) && node.label == last_label
    cal extend(node,a:args)
  else
    echoerr "addPath Error"
    echoerr a:path
    echoerr a:args
    echoerr node
  endif
endf

fun! g:MenuBuffer.findWindow(switch)
  let win = bufwinnr( self.buf_nr )
  if win != -1 && a:switch
    exec (win-1) . 'wincmd w'
  endif
  return win
endf




" 'cmd_inputs': [  
" \  {'label': '', 'default_value': '', 'completion', ''},
" ]

fun! g:mb_input(...)
  let arg = { 'label': a:1, 'default_value': a:2 }
  if strlen(a:3) > 0
    let arg.completion = a:3
  endif
  return arg
endf

fun! s:take_input_args(inputs)
  let args = []
  for input in a:inputs
    call inputsave()

    let l:default_value = ""
    if type(input.default_value) == type(function('tr'))
      " XXX: provide callback arguments
      let l:default_value = call( input.default_value , [] )
    else
      let l:default_value = input.default_value
    endif

    if has_key(input,'completion')
      let arg = input( input.label , l:default_value , input.completion )
    else
      let arg = input( input.label , l:default_value )
    endif
    call inputrestore()
    call add(args,arg)
  endfor
  return args
endf

" New Synopsis:
"  { label: ... , exe: function('FunctionName') , args: [ ... ]
"  { label: ... , exe: function('FunctionName') , inputs: [ .. ]
"  { label: ... , exe: 'Command', args: [ ... ]
"  { label: ... , exe: 'Command', inputs: [ .. ]
" 
" Current Interface:
"  { label: ... , exec_cmd: 'Command' , cmd_inputs: [ ... ]
fun! g:MenuBuffer.execCurrent()
  let id = self.getCurrentMenuId()
  let item = self.findItem(id)
  if type(item) == type({})

    " if exe is a function reference
    if has_key(item,'exe') && type(item.exe) == type(function('tr'))
      if has_key(item,'args')
        cal call(item.exe,item.args)
      elseif has_key(item,'inputs')
        cal call(item.exe,s:take_input_args(item.inputs))
      else
        cal call(item.exe,[])
      endif

    " if exe is a string , then this should be a command.
    elseif has_key(item,'exe') && type(item.exe) == type("")
      if has_key(item,'args')
        exec item.exe . ' ' . join(item.args,' ')
      elseif has_key(item,'inputs')
        exec item.exe . ' ' . join(s:take_input_args(item.inputs),' ')
      else
        exec item.exe
      endif

    " XXX:
    " old api, should be deprecated.
    elseif has_key(item,'exec_cmd')
      if has_key(item,'cmd_inputs')
        exec item.exec_cmd . ' ' . join(s:take_input_args( 
          item.cmd_inputs ),' ')
      else
        exec item.exec_cmd
      endif
      if item.close
        close
      endif
    elseif has_key(item,'exec_func')
      exec 'cal ' . item.exec_func . '()' 
      if item.close
        close
      endif
    else
      redraw
      echo "Can't execute."
    endif

  endif
endf

fun! g:MenuBuffer.toggleCurrent()
  let id = self.getCurrentMenuId()
  let item = self.findItem(id)
  if type(item) == 4
    cal item.toggle()
  endif
  cal self.render()
endf

" FIXME:
fun! g:MenuBuffer.toggleCurrentR()
  let id = self.getCurrentMenuId()
  let item = self.findItem(id)
  if type(item) == 4
    cal item.toggleR()
  endif
  cal self.render()
endf

fun! g:MenuBuffer.render()
  let cur = getpos('.')
  let win = self.findWindow(1)
  let out = [  ]
  cal add(out,self.root.render())

  setlocal modifiable
  if line('$') > 1 
    silent 1,$delete _
  endif
  let outstr=join(out,"\n")

  if has_key(self,'before_render')
    cal self.before_render()
  endif

  silent 0put=outstr

  if has_key(self,'after_render')
    cal self.after_render()
  endif

  cal setpos('.',cur)
  setlocal nomodifiable
endf

fun! g:MenuBuffer.getCurrentLevel()
  let line = getline('.')
  let idx = stridx(line,' [')
  return idx - 1
endf

fun! g:MenuBuffer.getCurrentMenuId()
  let id = matchstr(getline('.'),'\( \[\)\@<=\d\+\(\)\@>')
  return str2nr(id)
endf

fun! g:MenuBuffer.findItem(id)
  return self.root.findItem(a:id)
endf
" }}}
" MenuItem Class {{{

let g:MenuItem = {'id':0, 'expanded':0 , 'close':1 }

" Factory method
fun! g:MenuItem.create(options)
  let opt = a:options
  let self.id += 1
  let item = copy(self)

  if has_key(opt,'childs')
    let child_options = remove(opt,'childs' )
  else
    let child_options = [ ]
  endif

  cal extend(item,opt)
  if has_key(item,'parent')
    if has_key(item.parent,'childs')
      cal add(item.parent.childs,item)
    else
      let item.parent.childs = [ ]
      cal add(item.parent.childs,item)
    endif
  endif

  for ch in child_options
    cal item.createChild(ch)
  endfor
  return item
endf

fun! g:MenuItem.appendSeperator(text)
  cal self.createChild({ 'label' : '--- ' . a:text . ' ---' })
endf

" Object method
fun! g:MenuItem.createChild(options)
  let opt = a:options
  let child = g:MenuItem.create({ 'parent': self })

  if has_key(opt,'childs')
    let child_options = remove(opt,'childs' )
  else
    let child_options = [ ]
  endif

  cal extend(child,opt)

  for ch in child_options
    cal child.createChild(ch)
  endfor
  return child
endf

fun! g:MenuItem.findChildByLabel(name)
  if has_key(self,'childs')
    for ch in self.childs 
      if ch.label == a:name
        return ch
      endif
    endfor
  endif
  return {}
endf

fun! g:MenuItem.findItem(id)
  if self.id == a:id
    return self
  else 
    if has_key(self,'childs')
      for ch in self.childs 
        let l:ret = ch.findItem(a:id)
        if type(l:ret) == 4
          return l:ret
        endif
        unlet l:ret
      endfor
    endif
    return -1
  endif
endf

fun! g:MenuItem.getLevel(lev)
  let level = a:lev
  if has_key(self,'parent')
    let level +=1
    return self.parent.getLevel(level)
  else 
    return level
  endif
endf

fun! g:MenuItem.idString()
  return ' [' . self.id . ']'
endf

fun! g:MenuItem.displayString()
  let lev = self.getLevel(0)

  if has_key(self,'childs')
    if self.expanded 
      let op = '~'
    else
      let op = '+'
    endif
    let indent = repeat('-', lev)
    return op . indent . self.label . self.idString()
  elseif has_key(self,'parent')
    let indent = repeat(' ', lev-2) . '|-'
    " let indent = repeat('-', lev-1) . '|'
    return indent . self.label . self.idString()
  else
    let indent = repeat('-', lev)
    return '-' . indent . self.label . self.idString()
  endif
endf

fun! g:MenuItem.expandR()
  let self.expanded = 1
  if has_key(self,'childs')
    for ch in self.childs
      cal ch.expandR()
    endfor
  endif
endf

fun! g:MenuItem.collapseR()
  let self.expanded = 0
  if has_key(self,'childs')
    for ch in self.childs
      cal ch.collapseR()
    endfor
  endif
endf

fun! g:MenuItem.expand()
  let self.expanded = 1
endf

fun! g:MenuItem.collapse()
  let self.expanded = 0
endf

fun! g:MenuItem.toggle()
  if self.expanded == 1
    cal self.collapse()
  else
    cal self.expand()
  endif
endf

fun! g:MenuItem.toggleR()
  if self.expanded == 1
    cal self.collapseR()
  else
    cal self.expandR()
  endif
endf

fun! g:MenuItem.render( )
  let printlines = [ self.displayString()  ]
  if has_key(self,'childs') && self.expanded 
    for ch in self.childs 
      cal add( printlines, ch.render() )
    endfor
  endif
  return join(printlines,"\n")
endf

" }}}


" Test Code {{{
" ========================================================
finish
" addPath Test {{{
new
unlet m
let m = g:MenuBuffer.create({ 'buf_nr': bufnr('.') })
cal m.addPath( 'Tree.Node1',      { 'exe': 'echo' , 'args': [ '"YES"' ] , 'close': 0 })
cal m.addPath( 'Tree.Node2.zxcv', { 'exe': 'echo' , 'args': [ '"YES"' ] , 'close': 0 })
cal m.addPath( 'Tree.Ah Space.A1', { 'exe': 'echo' , 'args': [ '"YES"' ] , 'close': 0 })
cal m.addPath( 'Tree.Ah Space.A2', { 'exe': 'echo' , 'args': [ '"YES"' ] , 'close': 0 })
cal m.render()
finish
" }}}

" Find Node by label {{{
new
let m = g:MenuBuffer.create({ 'buf_nr': bufnr('.') })
cal m.addItem({ 
      \ 'label': 'Test' , 'expanded': 1 , 'childs': [
      \  { 'label': 'A1' }
      \ ,{ 'label': 'A2' }
      \ ,{ 'label': 'B3', 'childs': [ 
      \         g:MenuItem.create({ 'label': 'CC'  })  ]}
      \ ]} )

let node = m.root.findChildByLabel( 'Test' ).findChildByLabel('B3').findChildByLabel('CC')
echo node.label
unlet m
unlet node
finish
" }}}
" The original Way to create menu {{{
finish
vnew
"set verbose=12
unlet m

fun! MenuExeTest()
  echo 'MenuExeTest!!!'
endf
let m = g:MenuBuffer.create({ 'buf_nr': bufnr('.') })

cal m.addItem( g:MenuItem.create({ 
    \ 'label': 'Edit' , 'expanded': 1 , 'childs': [
      \ g:MenuItem.create({
      \   'label': 'Echo YES'  , 
      \   'close': 0 ,  
      \   'exe': 'echo' , 'args': [ '"YES"' ] })
      \ ,g:MenuItem.create({
      \   'label': 'Echo with arguments'  , 
      \   'close': 0 ,  
      \   'exe': 'echo' , 'inputs': [ g:mb_input('Test:','123','') ]   })
      \ ,g:MenuItem.create({
      \   'label': 'Menu Exe Test', 
      \   'close': 0,  
      \   'exe': function('MenuExeTest') })
    \ ]   }) 
    \ )

cal m.render()
set verbose=0
" }}}

" }}}