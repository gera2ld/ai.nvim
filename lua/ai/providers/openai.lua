local curl = require('plenary.curl')
local util = require('ai.util')

local M = {}

local function formatResult(data)
  local text = data.choices[1].message.content
  local result = '## Answer\n\n' .. text .. '\n'
  return result
end

local function askOpenAICallback(res, ctx)
  local result
  if res.status ~= 200 then
    if ctx.handleError ~= nil then
      result = ctx.handleError(res.status, res.body)
    else
      result = 'Error: OpenAI API responded with the status ' .. tostring(res.status) .. '\n\n' .. res.body
    end
  else
    local data = vim.fn.json_decode(res.body)
    result = formatResult(data)
    if ctx.handleResult ~= nil then
      result = ctx.handleResult(result)
    end
  end
  ctx.callback(result)
end

function M.precheck(opts)
  assert(not util.isEmpty(opts.api_key), 'opts.openai.api_key is required')
end

function M.request(prompt, opts, ctx)
  curl.post(opts.base_url .. '/chat/completions',
    {
      raw = {
        { '-H', 'Content-type: application/json' },
        { '-H', 'Authorization: Bearer ' .. opts.api_key }
      },
      proxy = opts.proxy,
      body = vim.fn.json_encode(
        {
          model = opts.model,
          messages = {
            { role = 'user', content = prompt } },
          temperature = 0.7
        }
      ),
      callback = function(res)
        vim.schedule(function() askOpenAICallback(res, ctx) end)
      end
    })
end

return M
