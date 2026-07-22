if vim.g.loaded_obsidian_para_flow == 1 then
  return
end
vim.g.loaded_obsidian_para_flow = 1

require("obsidian-para-flow")._register_commands()
