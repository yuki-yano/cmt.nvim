if exists('g:loaded_cmt_vim')
  finish
endif
let g:loaded_cmt_vim = 1

if !exists('g:cmt_mixed_mode_policy')
  let g:cmt_mixed_mode_policy = {
        \ 'typescriptreact': 'first-line',
        \ 'javascriptreact': 'first-line',
        \ 'default': 'mixed',
        \ }
endif

if has('nvim')
  highlight default link CmtToggleCommented DiffAdd
  highlight default link CmtToggleUncommented DiffDelete
endif

function! s:cmt_call_expr(kind, with_blank) abort
  if a:with_blank
    return printf("{ kind = '%s', include_blank_lines = true }", a:kind)
  endif
  return printf("'%s'", a:kind)
endfunction

function! s:cmt_define_toggle(kind, with_blank) abort
  let l:extra = a:with_blank ? ':with-blank' : ''
  let l:call = s:cmt_call_expr(a:kind, a:with_blank)

  execute printf("nnoremap <silent> <expr> <Plug>(cmt:%s:toggle%s:operator) luaeval(\"require('cmt.ops').operator_expr(%s)\")", a:kind, l:extra, l:call)
  execute printf("xmap <silent> <Plug>(cmt:%s:toggle%s:visual) <Cmd>lua require('cmt.ops').visual_entry(%s)<CR>", a:kind, l:extra, l:call)

  execute printf("nmap <silent> <Plug>(cmt:%s:toggle%s) <Plug>(cmt:%s:toggle%s:operator)", a:kind, l:extra, a:kind, l:extra)
  execute printf("xmap <silent> <Plug>(cmt:%s:toggle%s) <Plug>(cmt:%s:toggle%s:visual)", a:kind, l:extra, a:kind, l:extra)

  execute printf("nnoremap <silent> <Plug>(cmt:%s:toggle%s:current) <Cmd>lua require('cmt.ops').current_entry(%s)<CR>", a:kind, l:extra, l:call)
endfunction

call s:cmt_define_toggle('line', v:false)
call s:cmt_define_toggle('block', v:false)
call s:cmt_define_toggle('line', v:true)
call s:cmt_define_toggle('block', v:true)

nmap <silent> <Plug>(cmt:open-below-comment) <Cmd>lua require('cmt.ops').open('below')<CR>
nmap <silent> <Plug>(cmt:open-above-comment) <Cmd>lua require('cmt.ops').open('above')<CR>

command! CmtInfo lua require('cmt.ops').info()
