if exists('g:loaded_cmt_vim')
  finish
endif
let g:loaded_cmt_vim = 1

if !exists('g:cmt_mixed_mode_policy')
  let g:cmt_mixed_mode_policy = {
        \ 'typescriptreact': 'block',
        \ 'javascriptreact': 'block',
        \ 'default': 'mixed',
        \ }
endif

let s:cmt_root = expand('<sfile>:p:h:h')
function! s:cmt_register() abort
  if exists('*denops#plugin#register')
    call denops#plugin#register('cmt', s:cmt_root . '/denops/cmt/main.ts')
  endif
endfunction

if exists('*denops#plugin#register')
  call s:cmt_register()
else
  augroup cmt-denops-register
    autocmd!
    autocmd User DenopsReady ++once call s:cmt_register()
  augroup END
endif

nnoremap <silent> <expr> <Plug>(cmt:line:toggle:operator) luaeval("require('cmt.ops').operator_expr('line')")
xmap <silent> <Plug>(cmt:line:toggle:visual) <Cmd>lua require('cmt.ops').visual_entry('line')<CR>
nnoremap <silent> <expr> <Plug>(cmt:block:toggle:operator) luaeval("require('cmt.ops').operator_expr('block')")
xmap <silent> <Plug>(cmt:block:toggle:visual) <Cmd>lua require('cmt.ops').visual_entry('block')<CR>

nmap <silent> <Plug>(cmt:line:toggle) <Plug>(cmt:line:toggle:operator)
xmap <silent> <Plug>(cmt:line:toggle) <Plug>(cmt:line:toggle:visual)
nmap <silent> <Plug>(cmt:block:toggle) <Plug>(cmt:block:toggle:operator)
xmap <silent> <Plug>(cmt:block:toggle) <Plug>(cmt:block:toggle:visual)

nmap <silent> <Plug>(cmt:line:toggle:current) <Cmd>lua require('cmt.ops').current_entry('line')<CR>
nmap <silent> <Plug>(cmt:block:toggle:current) <Cmd>lua require('cmt.ops').current_entry('block')<CR>

nmap <silent> <Plug>(cmt:open-below-comment) <Cmd>lua require('cmt.ops').open('below')<CR>
nmap <silent> <Plug>(cmt:open-above-comment) <Cmd>lua require('cmt.ops').open('above')<CR>

command! CmtInfo lua require('cmt.ops').info()
