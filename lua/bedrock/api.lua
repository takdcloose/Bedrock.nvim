local job = require("plenary.job")
local Config = require("bedrock.config")
local logger = require("bedrock.common.logger")
local Utils = require("bedrock.utils")

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
  local modelid = Config.options.model_id
  local region = Config.options.region
  local URL = string.format("https://bedrock-runtime.%s.amazonaws.com/model/%s/converse", region, modelid)
  local raw_chunks = ""

  cb = vim.schedule_wrap(cb)
  local inferenceConfig = Config.options.bedrock_params
  local bedrock_params = vim.tbl_extend("keep", params, inferenceConfig)

  local args = {
    URL,
    "--service",
    "bedrock",
    "--region",
    region,
    "-H",
    "Content-Type: application/json",
    "-X",
    "POST",
    "-d",
    vim.json.encode(bedrock_params),
  }

  Api.exec(
    "awscurl",
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
        if ok and json.output ~= nil then
          cb(json.output.message.content[1].text, "END")
        else
          cb("some error occur", "ERROR")
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
end

function Api.chat_action(custom_params, cb)
  local params = custom_params
  local modelid = Api.modelid or Config.options.model_id
  local region = Config.options.region

  local URL = string.format("https://bedrock-runtime.%s.amazonaws.com/model/%s/converse", region, modelid)

  cb = vim.schedule_wrap(cb)
  Api.make_call(URL, params, cb)
end

function Api.edits(custom_params, cb)
  local params = custom_params
  local modelid = Api.modelid or Config.options.model_id
  local region = Config.options.region
  local URL = string.format("https://bedrock-runtime.%s.amazonaws.com/model/%s/converse", region, modelid)
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

  local region = Config.options.region
  local args = {
    url,
    "--service",
    "bedrock",
    "--region",
    region,
    "-H",
    "Content-Type: application/json",
    "-X",
    "POST",
    "-d",
    "@" .. TMP_MSG_FILENAME,
  }

  Api.job = job
    :new({
      command = "awscurl",
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

function Api.setup()
  loadRequiredConfig("modelid", "modelid", function(modelid)
    Api.modelid = modelid
  end)
  loadRequiredConfig("KEY", "KEY", function(access_key)
    Api.KEY = access_key
  end)
  loadRequiredConfig("SECRET_KEY", "SECRET_KEY", function(secret_key)
    Api.SECRET_KEY = secret_key
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
      vim.schedule(function()
        print("stderr: " .. chunk) -- 標準エラー出力を表示
      end)
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
