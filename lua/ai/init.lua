local curl = require('plenary.curl')

local M = {}
M.opts = {
  api_key = '',
  locale = 'en',
  alternate_locale = 'zh',
}
local win_id

local function splitLines(input)
  local lines = {}
  local offset = 1
  while offset > 0 do
    local i = string.find(input, '\n', offset)
    if i == nil then
      table.insert(lines, string.sub(input, offset, -1))
      offset = 0
    else
      table.insert(lines, string.sub(input, offset, i - 1))
      offset = i + 1
    end
  end
  return lines
end

local function joinLines(lines)
  local result = ''
  for _, line in ipairs(lines) do
    result = result .. line
  end
  return result
end

local function isEmpty(text)
  return text == nil or text == ''
end

local function hasLetters(text)
  return type(text) == 'string' and text:match('[a-zA-Z]') ~= nil
end

function M.getSelectedText()
  local vstart = vim.fn.getpos("'<")
  local vend = vim.fn.getpos("'>")
  local lines = vim.api.nvim_buf_get_text(0, vstart[2] - 1, vstart[3] - 1, vend[2] - 1, vend[3], {})
  if lines ~= nil then
    return joinLines(lines)
  end
end

function M.close()
  if win_id == nil or win_id == vim.api.nvim_get_current_win() then
    return
  end
  pcall(vim.api.nvim_win_close, win_id, true)
  win_id = nil
end

function M.askGemini(prompt, opts)
  curl.post('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=' .. M.opts.api_key, {
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
      vim.schedule(function()
        local result
        if res.status ~= 200 then
          if opts.handleError ~= nil then
            result = opts.handleError(res.status, res.body)
          else
            result = 'Error: ' .. tostring(res.status) .. '\n\n' .. res.body
          end
        else
          local data = vim.fn.json_decode(res.body)
          result = data['candidates'][1]['content']['parts'][1]['text']
          if opts.handleResult ~= nil then
            result = opts.handleResult(result)
          end
        end
        opts.callback(result)
      end)
    end,
  })
end

function M.createPopup(initialContent)
  M.close()

  local bufnr = vim.api.nvim_create_buf(false, true)

  local update = function(content)
    local lines = splitLines(content)
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
    vim.bo[bufnr].modifiable = false
  end

  win_id = vim.api.nvim_open_win(bufnr, false, {
    relative = 'cursor',
    border = 'single',
    title = 'ai.nvim',
    style = 'minimal',
    width = 60,
    height = 20,
    row = 1,
    col = 0,
  })

  update(initialContent)
  return update
end

function M.define(text)
  local update = M.createPopup(text .. '\n\nAsking Gemini...')
  local prompt = 'Define the content below in locale ' .. M.opts.locale .. '. The output is a bullet list of definitions grouped by parts of speech in plain text. Each item of the definition list contains pronunciation using IPA, meaning, and a list of usage examples with at most 2 items. Do not return anything else. Here is the content:\n\n"' .. vim.fn.json_encode(text) .. '"'
  M.askGemini(prompt, {
    handleResult = function(result)
      return text .. '\n\n' .. result
    end,
    callback = update,
  })
end

function M.translate(text)
  local update = M.createPopup('Translating the content below:\n\n' .. text .. '\n\nAsking Gemini...')
  local prompt = 'Translate the content below into locale ' .. M.opts.locale .. '. Translate into ' .. M.opts.alternate_locale .. ' instead if it is already in ' .. M.opts.locale .. '. Do not return anything else. Here is the content:\n\n' .. vim.fn.json_encode(text)
  M.askGemini(prompt, {
    handleResult = function(result)
      return 'Source:\n\n' .. text .. '\n\nResult:\n\n' .. result
    end,
    callback = update,
  })
end

function M.improve(text)
  local update = M.createPopup('Improving the content below:\n\n' .. text .. '\n\nAsking Gemini...')
  local prompt = 'Improve the content below with the same locale. Do not return anything else. Here is the content:\n\n' .. vim.fn.json_encode(text)
  M.askGemini(prompt, {
    handleResult = function(result)
      return 'Original content:\n\n' .. text .. '\n\nImprovements:\n\n' .. result
    end,
    callback = update,
  })
end

function M.freeStyle(prompt)
  local update = M.createPopup('Asking Gemini...\n\n' .. prompt)
  M.askGemini(prompt, {
    handleResult = function(result)
      return 'Question:\n\n' .. prompt .. '\n\n' .. result
    end,
    callback = update,
  })
end

function M.setup(opts)
  for k, v in pairs(opts) do
    if M.opts[k] ~= nil then
      M.opts[k] = v
    end
  end
  assert(M.opts.api_key ~= nil and M.opts.api_key ~= '', 'api_key is required')
end

vim.api.nvim_create_autocmd({'CursorMoved', 'CursorMovedI'}, {
  callback = M.close,
})

vim.api.nvim_create_user_command('GeminiDefine', function(args)
  local text = args['args']
  if isEmpty(text) then
    text = vim.fn.expand('<cword>')
  end
  if hasLetters(text) then
    M.define(text)
  end
end, { nargs = '?' })

vim.api.nvim_create_user_command('GeminiDefineV', function()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<esc>', true, false, true), 'n', false)
  local text = M.getSelectedText()
  if hasLetters(text) then
    -- delayed so the popup won't be closed immediately
    vim.schedule(function()
      M.define(text)
    end)
  end
end, { range = true })

vim.api.nvim_create_user_command('GeminiTranslate', function(args)
  local text = args['args']
  if isEmpty(text) then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<esc>', true, false, true), 'n', false)
    text = M.getSelectedText()
  end
  if hasLetters(text) then
    -- delayed so the popup won't be closed immediately
    vim.schedule(function()
      M.translate(text)
    end)
  end
end, { range = true, nargs = '?' })

vim.api.nvim_create_user_command('GeminiImprove', function(args)
  local text = args['args']
  if isEmpty(text) then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<esc>', true, false, true), 'n', false)
    text = M.getSelectedText()
  end
  if hasLetters(text) then
    -- delayed so the popup won't be closed immediately
    vim.schedule(function()
      M.improve(text)
    end)
  end
end, { range = true, nargs = '?' })

vim.api.nvim_create_user_command('GeminiAsk', function(args)
  local text = args['args']
  if isEmpty(text) then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<esc>', true, false, true), 'n', false)
    text = M.getSelectedText()
  end
  if hasLetters(text) then
    -- delayed so the popup won't be closed immediately
    vim.schedule(function()
      M.freeStyle(text)
    end)
  end
end, { range = true, nargs = '?' })

return M
