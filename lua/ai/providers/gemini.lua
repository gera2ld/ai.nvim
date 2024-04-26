local curl = require('plenary.curl')
local util = require('ai.util')

local M = {}

local function formatResult(data)
  local result = ''
  -- blocked
  -- {"promptFeedback": {"blockReason": "SAFETY", "safetyRatings": [{"probability": "NEGLIGIBLE", "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT"}, {"probability": "NEGLIGIBLE", "category": "HARM_CATEGORY_HATE_SPEECH"}, {"probability": "MEDIUM", "category": "HARM_CATEGORY_HARASSMENT"}, {"probability": "NEGLIGIBLE", "category": "HARM_CATEGORY_DANGEROUS_CONTENT"}]}}
  local blockReason = util.get(data, { 'promptFeedback', 'blockReason' })
  if blockReason then
    return 'Blocked: ' .. blockReason
  end
  if data['candidates'] then
    for i, candidate in ipairs(data['candidates']) do
      local text = util.get(candidate, { 'content', 'parts', 1, 'text' })
      result = result .. '### Answer ' .. i .. '\n\n' .. text .. '\n'
    end
  end
  return result
end

local function askGeminiCallback(res, callback)
  local result
  if res.status ~= 200 then
    result = 'Error: Gemini API responded with the status ' .. tostring(res.status) .. '\n\n' .. res.body
  else
    local data = vim.fn.json_decode(res.body)
    result = formatResult(data)
  end
  callback(result)
end

function M.precheck(providerOpts)
  if util.isEmpty(providerOpts.api_key) then
    print('opts.gemini.api_key is required')
    return false
  end
  return true
end

function M.request(messages, providerOpts, opts)
  local contents = {}
  for _, message in ipairs(messages) do
    local item = {
      parts = {
        text = message.content,
      },
    }
    if message.role == 'user' then
      item.parts.role = 'user'
    else
      item.parts.role = 'model'
    end
    table.insert(contents, item)
  end
  curl.post(
    'https://generativelanguage.googleapis.com/v1beta/models/' .. opts.model .. ':generateContent?key=' .. providerOpts.api_key,
    {
      raw = { '-H', 'Content-type: application/json' },
      proxy = providerOpts.proxy,
      body = vim.fn.json_encode({
        contents = contents,
        safetySettings = {
          { category = 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold = 'BLOCK_ONLY_HIGH' },
          { category = 'HARM_CATEGORY_HATE_SPEECH',       threshold = 'BLOCK_ONLY_HIGH' },
          { category = 'HARM_CATEGORY_HARASSMENT',        threshold = 'BLOCK_ONLY_HIGH' },
          { category = 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold = 'BLOCK_ONLY_HIGH' }
        }
      }),
      callback = function(res)
        vim.schedule(function() askGeminiCallback(res, opts.callback) end)
      end
    })
end

return M
