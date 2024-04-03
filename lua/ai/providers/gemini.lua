local curl = require('plenary.curl')
local util = require('ai.util')

local M = {}

local function formatResult(data)
  local result = ''
  -- blocked
  -- {"promptFeedback": {"blockReason": "SAFETY", "safetyRatings": [{"probability": "NEGLIGIBLE", "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT"}, {"probability": "NEGLIGIBLE", "category": "HARM_CATEGORY_HATE_SPEECH"}, {"probability": "MEDIUM", "category": "HARM_CATEGORY_HARASSMENT"}, {"probability": "NEGLIGIBLE", "category": "HARM_CATEGORY_DANGEROUS_CONTENT"}]}}
  if data['promptFeedback']['blockReason'] then
    return 'Blocked: ' .. data['promptFeedback']['blockReason']
  end
  if data['candidates'] then
    for i, candidate in ipairs(data['candidates']) do
      local text = candidate['content']['parts'][1]['text']
      result = result .. '## Answer ' .. i .. '\n\n' .. text .. '\n'
    end
  end
  return result
end

local function askGeminiCallback(res, ctx)
  local result
  if res.status ~= 200 then
    if ctx.handleError ~= nil then
      result = ctx.handleError(res.status, res.body)
    else
      result = 'Error: Gemini API responded with the status ' .. tostring(res.status) .. '\n\n' .. res.body
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
  assert(not util.isEmpty(opts.api_key), 'opts.gemini.api_key is required')
end

function M.request(prompt, opts, ctx)
  curl.post(
    'https://generativelanguage.googleapis.com/v1beta/models/' .. opts.model .. ':generateContent?key=' .. opts.api_key,
    {
      raw = { '-H', 'Content-type: application/json' },
      proxy = opts.proxy,
      body = vim.fn.json_encode({
        contents = {
          {
            parts = {
              text = prompt,
            },
          },
        },
        safetySettings = {
          { category = 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold = 'BLOCK_ONLY_HIGH' },
          { category = 'HARM_CATEGORY_HATE_SPEECH',       threshold = 'BLOCK_ONLY_HIGH' },
          { category = 'HARM_CATEGORY_HARASSMENT',        threshold = 'BLOCK_ONLY_HIGH' },
          { category = 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold = 'BLOCK_ONLY_HIGH' }
        }
      }),
      callback = function(res)
        vim.schedule(function() askGeminiCallback(res, ctx) end)
      end
    })
end

return M
