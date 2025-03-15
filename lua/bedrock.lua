-- main module file
local api = require("bedrock.api")
local module = require("bedrock.module")
local config = require("bedrock.config")
local signs = require("bedrock.signs")

local M = {}

M.setup = function(options)
  -- set custom highlights
  vim.api.nvim_set_hl(0, "BedrockQuestion", { fg = "#b4befe", italic = true, bold = false, default = true })

  vim.api.nvim_set_hl(0, "BedrockWelcome", { fg = "#9399b2", italic = true, bold = false, default = true })

  vim.api.nvim_set_hl(0, "BedrockTotalTokens", { fg = "#ffffff", bg = "#444444", default = true })
  vim.api.nvim_set_hl(0, "BedrockTotalTokensBorder", { fg = "#444444", default = true })

  vim.api.nvim_set_hl(0, "BedrockMessageAction", { fg = "#ffffff", bg = "#1d4c61", italic = true, default = true })

  vim.api.nvim_set_hl(0, "BedrockCompletion", { fg = "#9399b2", italic = true, bold = false, default = true })

  vim.cmd("highlight default link BedrockSelectedMessage ColorColumn")

  config.setup(options)
  api.setup()
  signs.setup()
end

--
-- public methods for the plugin
--

M.openChat = function()
  module.open_chat()
end

M.selectAwesomePrompt = function()
  module.open_chat_with_awesome_prompt()
end

M.open_chat_with = function(opts)
  module.open_chat_with(opts)
end

M.edit_with_instructions = function()
  module.edit_with_instructions()
end

M.run_action = function(opts)
  module.run_action(opts)
end

M.complete_code = module.complete_code

return M
