local job = require("plenary.job")
local Config = require("chatgpt.config")
local logger = require("chatgpt.common.logger")
local Utils = require("chatgpt.utils")

local Api = {}

function print_table(tbl, indent)
  indent = indent or 0 -- インデントの初期値
  if type(tbl) ~= "table" then
    return
  end

  for k, v in pairs(tbl) do
    local key_str = tostring(k)
    local value_type = type(v)

    if value_type == "table" then
      print(string.rep("  ", indent) .. key_str .. " = {")
      print_table(v, indent + 1)
      print(string.rep("  ", indent) .. "}")
    else
      print(string.rep("  ", indent) .. key_str .. " = " .. tostring(v))
    end
  end
end

function Api.chat_completions(custom_params, cb, should_stop)
  local params = custom_params
  local stream = params.stream or false
  local modelid = "anthropic.claude-v2"
  local URL = string.format("https://bedrock-runtime.us-west-2.amazonaws.com/model/%s/converse", modelid)
  local USER_ID = Api.AWS_ACCESS_KEY_ID .. ":" .. Api.AWS_SECRET_ACCESS_KEY
  if stream then
    local raw_chunks = ""
    local state = "START"

    cb = vim.schedule_wrap(cb)
    local last_content = params.messages[#params.messages].content or nil
    local inferenceConfig = {
      temperature = 0.5,
      topP = 1,
      maxTokenCount = 4096,
      stopSequences = {},
    }
    local bedrock_params = vim.tbl_extend("keep", params, inferenceConfig)
    print_table(bedrock_params)

    local args = {
      "-v",
      "--show-error",
      "--no-buffer",
      "--aws-sigv4",
      "aws:amz:us-west-2:bedrock",
      "--user",
      USER_ID,
      URL,
      "-H",
      "Content-Type: application/json",
      "-X",
      "POST",
      "-d",
      vim.json.encode(bedrock_params),
    }

    Api.exec(
      "curl",
      args,
      function(chunk)
        local ok, json = pcall(vim.json.decode, chunk)
        if ok and json ~= nil then
          if json.error ~= nil then
            cb(json.error.message, "ERROR")
            return
          end
        end
        for line in chunk:gmatch("[^\n]+") do
          local raw_json = string.gsub(line, "^data: ", "")
          ok, json = pcall(vim.json.decode, raw_json, {
            luanil = {
              object = true,
              array = true,
            },
          })
          if ok and json ~= nil then
            state = "END"
            cb(json.output.message.content[1].text, state)
            --raw_chunks = raw_chunks .. json.choices[1].delta.content
          end
        end
      end,
      function(err, _)
        cb(err, "ERROR")
      end,
      should_stop,
      function()
        cb(raw_chunks, "END")
      end
    )
  else
    Api.make_call(URL, params, cb)
  end
end

--[[
function Api.chat_completions(custom_params, cb, should_stop)
  local openai_params = Utils.collapsed_openai_params(Config.options.openai_params)
  local params = vim.tbl_extend("keep", custom_params, openai_params)
  -- the custom params contains <dynamic> if model is not constant but function
  -- therefore, use collapsed openai params (with function evaluated to get model) if that is the case
  if params.model == "<dynamic>" then
    params.model = openai_params.model
  end
  local stream = params.stream or false
  if stream then
    local raw_chunks = ""
    local state = "START"

    cb = vim.schedule_wrap(cb)

    local extra_curl_params = Config.options.extra_curl_params
    local args = {
      "--silent",
      "--show-error",
      "--no-buffer",
      Api.CHAT_COMPLETIONS_URL,
      "-H",
      "Content-Type: application/json",
      "-H",
      Api.AUTHORIZATION_HEADER,
      "-d",
      vim.json.encode(params),
    }

    if extra_curl_params ~= nil then
      for _, param in ipairs(extra_curl_params) do
        table.insert(args, param)
      end
    end

    Api.exec(
      "curl",
      args,
      function(chunk)
        local ok, json = pcall(vim.json.decode, chunk)
        if ok and json ~= nil then
          if json.error ~= nil then
            cb(json.error.message, "ERROR")
            return
          end
        end
        for line in chunk:gmatch("[^\n]+") do
          local raw_json = string.gsub(line, "^data: ", "")
          if raw_json == "[DONE]" then
            cb(raw_chunks, "END")
          else
            ok, json = pcall(vim.json.decode, raw_json, {
              luanil = {
                object = true,
                array = true,
              },
            })
            if ok and json ~= nil then
              if
                json
                and json.choices
                and json.choices[1]
                and json.choices[1].delta
                and json.choices[1].delta.content
              then
                cb(json.choices[1].delta.content, state)
                raw_chunks = raw_chunks .. json.choices[1].delta.content
                state = "CONTINUE"
              end
            end
          end
        end
      end,
      function(err, _)
        cb(err, "ERROR")
      end,
      should_stop,
      function()
        cb(raw_chunks, "END")
      end
    )
  else
    Api.make_call(Api.CHAT_COMPLETIONS_URL, params, cb)
  end
end
]]

function Api.edits(custom_params, cb)
  local params = custom_params
  local modelid = "anthropic.claude-v2"
  local URL = string.format("https://bedrock-runtime.us-west-2.amazonaws.com/model/%s/converse", modelid)
  local USER_ID = Api.AWS_ACCESS_KEY_ID .. ":" .. Api.AWS_SECRET_ACCESS_KEY
  Api.make_call(URL, params, cb)
end

function Api.make_call(url, params, cb)
  TMP_MSG_FILENAME = os.tmpname()
  local f = io.open(TMP_MSG_FILENAME, "w+")
  if f == nil then
    vim.notify("Cannot open temporary message file: " .. TMP_MSG_FILENAME, vim.log.levels.ERROR)
    return
  end
  f:write(vim.fn.json_encode(params))
  f:close()

  local USER_ID = Api.AWS_ACCESS_KEY_ID .. ":" .. Api.AWS_SECRET_ACCESS_KEY
  local args = {
    url,
    "--show-error",
    "--no-buffer",
    "--aws-sigv4",
    "aws:amz:us-west-2:bedrock",
    "--user",
    USER_ID,
    "-H",
    "Content-Type: application/json",
    "-X",
    "POST",
    "-d",
    "@" .. TMP_MSG_FILENAME,
  }

  local extra_curl_params = Config.options.extra_curl_params
  if extra_curl_params ~= nil then
    for _, param in ipairs(extra_curl_params) do
      table.insert(args, param)
    end
  end

  Api.job = job
    :new({
      command = "curl",
      args = args,
      on_exit = vim.schedule_wrap(function(response, exit_code)
        Api.handle_response(response, exit_code, cb)
      end),
    })
    :start()
end

Api.handle_response = vim.schedule_wrap(function(response, exit_code, cb)
  os.remove(TMP_MSG_FILENAME)
  if exit_code ~= 0 then
    vim.notify("An Error Occurred ...", vim.log.levels.ERROR)
    cb("ERROR: API Error")
  end

  if response == nil then
    cb("No Response")
  end
  local result = table.concat(response:result(), "\n")
  local json = vim.fn.json_decode(result)
  if json == nil then
    cb("No Response.")
  elseif json.error then
    cb("// API ERROR: " .. json.error.message)
  else
    local message = json.output.message.content[1]
    if message ~= nil then
      local message_response = message.text
      if (type(message_response) == "string" and message_response ~= "") or type(message_response) == "table" then
        cb(message_response, json.usage)
      else
        cb("...")
      end
    else
      logger.warn("no message")
    end
  end
end)

function Api.close()
  if Api.job then
    job:shutdown()
  end
end

local function loadConfigFromEnv(envName, configName, callback)
  local variable = os.getenv(envName)
  if not variable then
    return
  end
  local value = variable:gsub("%s+$", "")
  Api[configName] = value
  if callback then
    callback(value)
  end
end

local function loadRequiredConfig(envName, configName, callback)
  loadConfigFromEnv(envName, configName, callback)
  if not Api[configName] then
    logger.warn(configName .. " variable not set")
  end
end

local function startsWith(str, start)
  return string.sub(str, 1, string.len(start)) == start
end

local function ensureUrlProtocol(str)
  if startsWith(str, "https://") or startsWith(str, "http://") then
    return str
  end

  return "https://" .. str
end

function Api.setup()
  loadRequiredConfig("AWS_ACCESS_KEY_ID", "AWS_ACCESS_KEY_ID", function(access_key)
    Api.AWS_ACCESS_KEY_ID = access_key
  end)
  loadRequiredConfig("AWS_SECRET_ACCESS_KEY", "AWS_SECRET_ACCESS_KEY", function(secret_key)
    Api.AWS_SECRET_ACCESS_KEY = secret_key
  end)
end

function Api.exec(cmd, args, on_stdout_chunk, on_complete, should_stop, on_stop)
  local stdout = vim.loop.new_pipe()
  local stderr = vim.loop.new_pipe()
  local stderr_chunks = {}

  local handle, err
  local function on_stdout_read(_, chunk)
    if chunk then
      vim.schedule(function()
        if should_stop and should_stop() then
          if handle ~= nil then
            handle:kill(2) -- send SIGINT
            stdout:close()
            stderr:close()
            handle:close()
            on_stop()
          end
          return
        end
        on_stdout_chunk(chunk)
      end)
    end
  end

  local function on_stderr_read(_, chunk)
    if chunk then
      table.insert(stderr_chunks, chunk)
    end
  end

  handle, err = vim.loop.spawn(cmd, {
    args = args,
    stdio = { nil, stdout, stderr },
  }, function(code)
    stdout:close()
    stderr:close()
    if handle ~= nil then
      handle:close()
    end

    vim.schedule(function()
      if code ~= 0 then
        on_complete(vim.trim(table.concat(stderr_chunks, "")))
      end
    end)
  end)

  if not handle then
    on_complete(cmd .. " could not be started: " .. err)
  else
    stdout:read_start(on_stdout_read)
    stderr:read_start(on_stderr_read)
  end
end

return Api
