if exists('g:loaded_cmt_textobj_line')
  finish
endif
let g:loaded_cmt_textobj_line = 1

function! s:cmt_textobj_line_i() abort
  if v:count1 <= 1
    return 'v^og_'
  endif
  return 'v^o' . (v:count1 - 1) . 'jg_'
endfunction

function! s:cmt_textobj_line_a() abort
  if v:count1 <= 1
    return 'v0o$'
  endif
  return 'v0o' . (v:count1 - 1) . 'j$'
endfunction

omap <expr> <Plug>(cmt:textobj-line-i) <SID>cmt_textobj_line_i()
omap <expr> <Plug>(cmt:textobj-line-a) <SID>cmt_textobj_line_a()
