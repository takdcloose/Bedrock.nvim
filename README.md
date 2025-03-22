# Bedrock.nvim

![Image](https://github.com/user-attachments/assets/dd92ee89-05f1-4aae-97dc-3ecae2d79d73)

This is a fork of ChatGPT.nvim, a plugin that has been enhanced to use Amazon Bedrock.
Most of the code uses the same as ChatGPT.nvim, with some code modified to use Amazon Bedrock.

Similar to ChatGPT.nvim, the following commands can be used.

- Bedrock 
- BedrockActAs
- BedrockEditWithInstructions
- BedrockRun

However, currently, it is not output in streaming format, so you need to wait a little while.

## Installation

This plugin uses [awscurl](https://github.com/okigan/awscurl). Therefore, you need to install it in advance.
This is because curl version below 8.10.0 doesn't work properly when the model id in the URL contains a colon (":"). [issue](https://github.com/curl/curl/issues/13754)

You need to set up credentials to access Amazon Bedrock.
Set the authentication information in environment variables as follows.

```shell
$ export AWS_ACCESS_KEY_ID=XXXXXXX
$ export AWS_SECRET_ACCESS_KEY=XXXXXXX
```

You can also write credentials to ~/.aws/credentials in the default profile of the AWS CLI.

```
[default]
aws_access_key_id = XXXXXXX
aws_secret_access_key = XXXXXXX
```

Or, you can also configure it in the plugin settings options.

```
    config = function()
        local config = {
            AWS_ACCESS_KEY_ID = "XXXXXXX",
            AWS_SECRET_ACCESS_KEY = "XXXXXXX"
        }
        require("bedrock").setup(config)
    end,
```

If you are using lazy.nvim:

```
{
  "takdcloose/Bedrock.nvim",
    event = "VeryLazy",
    config = function()
      require("bedrock").setup()
    end,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "folke/trouble.nvim", -- optional
      "nvim-telescope/telescope.nvim"
    }
}
```

## Configuration

Similar to ChatGPT.nvim, you can configure the [model ID](https://docs.aws.amazon.com/bedrock/latest/userguide/models-supported.html), region and [other parameters](https://docs.aws.amazon.com/ja_jp/bedrock/latest/APIReference/API_runtime_InferenceConfiguration.html) (maxTokens, temperature, topP).
By default, it uses the us-west-2 region. This can also be changed in the configuration.


**Example**

```
{
  "takdcloose/Bedrock.nvim",
  event = "VeryLazy",
  config = function()
    require("bedrock").setup({
        model_id = "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
        region = "us-west-2",
        bedrock_params = {
          inferenceConfig = {
            maxTokens = 4096,
            temperature = 0.5,
            topP = 0.9,
          },
        },
    })
  end,
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
      "folke/trouble.nvim", -- optional
    "nvim-telescope/telescope.nvim"
  }
}
```

Off course, you need to grant access to the model you will use in advance. [doc](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html) (**By default, it uses Claude 3.7 Sonnet in us-west-2 region**)

## Future work

- Output in streaming format
When outputting in streaming format with Amazon Bedrock (ConverseStream API), it is returned as an eventstream object instead of json, so it needs to be parsed.
