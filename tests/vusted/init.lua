local root = vim.fn.getcwd()

local function append_rtp(path)
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.runtimepath:append(path)
  end
end

append_rtp(root)
append_rtp(root .. "/tmp/plenary.nvim")

-- Support local luarocks installations such as `luarocks --tree tmp/.luarocks install vusted`.
local luarocks_tree = root .. "/tmp/.luarocks"
local share_lua = luarocks_tree .. "/share/lua/5.1/?.lua"
local share_init = luarocks_tree .. "/share/lua/5.1/?/init.lua"
local lib_lua = luarocks_tree .. "/lib/lua/5.1/?.so"
if vim.fn.isdirectory(luarocks_tree) == 1 then
  package.path = table.concat({ share_lua, share_init, package.path }, ";")
  package.cpath = table.concat({ lib_lua, package.cpath }, ";")
end

vim.g.cmt_log_level = "error"
