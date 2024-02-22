local curl = require('plenary.curl')
local query = {}

function query.formatResult(data)
  local result = ''
  local candidates_number = #data['candidates']
  if candidates_number == 1 then
    if data['candidates'][1]['content'] == nil then
      result = '\n#Gemini error\n\nGemini stoped with the reason:' .. data['candidates'][1]['finishReason'] .. '\n'
      return result
    else
      result = '\n# This is Gemini answer\n\n'
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

function query.askCallback(res, prompt, opts)
  local result
  if res.status ~= 200 then
    if opts.handleError ~= nil then
      result = opts.handleError(res.status, res.body)
    else
      result = 'Error: Gemini API responded with the status ' .. tostring(res.status) .. '\n\n' .. res.body
    end
  else
    local data = vim.fn.json_decode(res.body)
    result = query.formatResult(data)
    if opts.handleResult ~= nil then
      result = opts.handleResult(result)
    end
  end
  opts.callback(result)
end

function query.ask(prompt, opts, api_key)
  curl.post('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=' .. api_key,
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
        vim.schedule(function() query.askCallback(res, prompt, opts) end)
      end
    })
end

return query
