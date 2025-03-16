# Bedrock.nvim

This is a fork of ChatGPT.nvim, a plugin that has been enhanced to use Amazon Bedrock.
Most of the code uses the same as ChatGPT.nvim, with some code modified to use Amazon Bedrock.

Similar to ChatGPT.nvim, the following commands can be used.

- Bedrock 
- BedrockActAs
- BedrockEditWithInstructions
- BedrockRun

## Installation

This plugin uses [awscurl](https://github.com/okigan/awscurl). Therefore, you need to install it in advance.
This is because curl version below 8.10.0 doesn't work properly when the model id in the URL contains a colon (":"). [issue](https://github.com/curl/curl/issues/13754)






