local curl = require('plenary.curl')
local util = require('ai.util')

local M = {}

local function askOpenAICallback(res, callback)
  local result
  if res.status ~= 200 then
    result = 'Error: OpenAI API responded with the status ' .. tostring(res.status) .. '\n\n' .. res.body
  else
    local data = vim.fn.json_decode(res.body)
    result = util.get(data, { 'choices', 1, 'message', 'content' })
    if not result and data.error then
      result = vim.fn.json_encode(data.error)
    end
  end
  callback(result)
end

function M.precheck(providerOpts)
  if util.isEmpty(providerOpts.api_key) then
    print('opts.openai.api_key is required')
    return false
  end
  return true
end

function M.request(messages, providerOpts, opts)
  curl.post(providerOpts.base_url .. '/chat/completions',
    {
      raw = {
        { '-H', 'Content-type: application/json' },
        { '-H', 'Authorization: Bearer ' .. providerOpts.api_key }
      },
      proxy = providerOpts.proxy,
      body = vim.fn.json_encode(
        {
          model = opts.model,
          messages = messages,
          temperature = 0.7
        }
      ),
      callback = function(res)
        vim.schedule(function() askOpenAICallback(res, opts.callback) end)
      end
    })
end

return M
