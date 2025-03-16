vim.api.nvim_create_user_command("Bedrock", function()
  require("bedrock").openChat()
end, {})

vim.api.nvim_create_user_command("BedrockActAs", function()
  require("bedrock").selectAwesomePrompt()
end, {})

vim.api.nvim_create_user_command("BedrockEditWithInstructions", function()
  require("bedrock").edit_with_instructions()
end, {
  range = true,
})

vim.api.nvim_create_user_command("BedrockRun", function(opts)
  require("bedrock").run_action(opts)
end, {
  nargs = "*",
  range = true,
  complete = function()
    local ActionFlow = require("bedrock.flows.actions")
    local action_definitions = ActionFlow.read_actions()

    local actions = {}
    for key, _ in pairs(action_definitions) do
      table.insert(actions, key)
    end
    table.sort(actions)

    return actions
  end,
})
