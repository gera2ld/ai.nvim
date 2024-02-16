local curl = require('plenary.curl')
local query = {}

function query.formatChatGPTResult(data)
  local result = 'Error: Unknown error' 

  if data.choices == nil then
    return 'Error: data.choices is nil'
  end

  if data.choices[0].message == nil then
    result = 'Error: data.choices[0].message is nil'
  end
  
  if data.choices[0].message.content == nil then
    result = 'Error: data.choices[0].message.content is nil'
  end

  result = data.choices[0].message.content

  return result
end

function query.askChatGPTCallback(res, prompt, opts)
  local result
  if res.status ~= 200 then
    if opts.handleError ~= nil then
      result = opts.handleError(res.status, res.body)
    else
      result = 'Error: ChatGPT API responded with the status ' .. tostring(res.status) .. '\n\n' .. res.body
    end
  else
    local data = vim.fn.json_decode(res.body)
    result = query.formatChatGPTResult(data)
    if opts.handleResult ~= nil then
      result = opts.handleResult(result)
    end
  end
  opts.callback(result)
end

function query.askChatGPT(prompt, opts, api_key)
  curl.post('https://api.openai.com/v1/chat/completions',
    {
      raw = {
        { '-H', 'Content-type: application/json' },
        { '-H', 'Authorization: Bearer ' .. api_key }
      },
      body = vim.fn.json_encode(
          {
            model = 'gpt-4',
            messages = {
              { role = 'user', content = prompt}},
            temperature = 0.7
          }
      ), 
      callback = function(res)
        vim.schedule(function() query.askChatGPTCallback(res, prompt, opts) end)
      end
    })
end

return query
