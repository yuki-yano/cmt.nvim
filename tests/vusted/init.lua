local root = vim.fn.getcwd()

local function append_rtp(path)
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.runtimepath:append(path)
  end
end

append_rtp(root)

-- Support custom LuaRocks trees via CMT_VUSTED_ROCKS (useful with `luarocks --tree`).
local luarocks_tree = vim.env.CMT_VUSTED_ROCKS
if luarocks_tree and luarocks_tree ~= "" and vim.fn.isdirectory(luarocks_tree) == 1 then
  local share_lua = luarocks_tree .. "/share/lua/5.1/?.lua"
  local share_init = luarocks_tree .. "/share/lua/5.1/?/init.lua"
  local lib_lua = luarocks_tree .. "/lib/lua/5.1/?.so"
  package.path = table.concat({ share_lua, share_init, package.path }, ";")
  package.cpath = table.concat({ lib_lua, package.cpath }, ";")
end

vim.g.cmt_log_level = "error"
