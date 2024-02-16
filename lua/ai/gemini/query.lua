local curl = require('plenary.curl')
local query = {}

function query.formatGeminiResult(data)
  local result = ''
  local candidates_number = #data['candidates']
  if candidates_number == 1 then
    if data['candidates'][1]['content'] == nil then
      result = 'Gemini stoped with the reason:' .. data['candidates'][1]['finishReason'] .. '\n'
      return result
    else
      result = '# There is only 1 Gemini candidate\n'
      result = result .. data['candidates'][1]['content']['parts'][1]['text'] .. '\n'
    end
  else
    result = '# There are ' .. candidates_number .. ' Gemini candidates\n'
    for i = 1, candidates_number do
      result = result .. '## Gemini Candidate number ' .. i .. '\n'
      result = result .. data['candidates'][i]['content']['parts'][1]['text'] .. '\n'
    end
  end
  return result
end

function query.askGeminiCallback(res, prompt, opts)
  local result
  if res.status ~= 200 then
    if opts.handleError ~= nil then
      result = opts.handleError(res.status, res.body)
    else
      result = 'Error: Gemini API responded with the status ' .. tostring(res.status) .. '\n\n' .. res.body
    end
  else
    local data = vim.fn.json_decode(res.body)
    result = query.formatGeminiResult(data)
    if opts.handleResult ~= nil then
      result = opts.handleResult(result)
    end
  end
  opts.callback(result)
end

function query.askGemini(prompt, opts)
  curl.post('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=' .. query.opts.api_key,
    {
      raw = { '-H', 'Content-type: application/json' },
      body = vim.fn.json_encode({
        contents = {
          {
            parts = {
              text = prompt,
            },
          },
        },
      }),
      callback = function(res)
        vim.schedule(function() query.askGeminiCallback(res, prompt, opts) end)
      end
    })
end

return query
