local gemini = require('ai.gemini.query')
local chatgpt = require('ai.chatgpt.query')

local default_prompts = {
  define = {
    command = 'GeminiDefine',
    loading_tpl = 'Define:\n\n${input}\n\nAsking Gemini...',
    prompt_tpl =
      'Define the content below in locale ${locale}. The output is a bullet list of definitions grouped by parts of speech in plain text. Each item of the definition list contains pronunciation using IPA, meaning, and a list of usage examples with at most 2 items. Do not return anything else. Here is the content:\n\n${input_encoded}',
    result_tpl = 'Original Content:\n\n${input}\n\nDefinition:\n\n${output}',
    require_input = true,
  },
  translate = {
    command = 'GeminiTranslate',
    loading_tpl = 'Translating the content below:\n\n${input}\n\nAsking Gemini...',
    prompt_tpl =
      'Translate the content below into locale ${locale}. Translate into ${alternate_locale} instead if it is already in ${locale}. Do not return anything else. Here is the content:\n\n${input_encoded}',
    result_tpl = 'Original Content:\n\n${input}\n\nTranslation:\n\n${output}',
    require_input = true,
  },
  improve = {
    command = 'GeminiImprove',
    loading_tpl = 'Improve the content below:\n\n${input}\n\nAsking Gemini...',
    prompt_tpl = 'Improve the content below in the same locale. Do not return anything else. Here is the content:\n\n${input_encoded}',
    result_tpl = 'Original Content:\n\n${input}\n\nImproved Content:\n\n${output}',
    require_input = true,
  },
  freeStyle = {
    command = 'GeminiAsk',
    loading_tpl = 'Loading...',
    prompt_tpl = '${input}',
    result_tpl = '${output}',
    require_input = true,
  },
}

local M = {}
M.opts = {
  gemini_api_key = '',
  chargpt_api_key = '',
  locale = 'en',
  alternate_locale = 'zh',
  result_popup_gets_focus = false,
}
M.prompts = default_prompts
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

function M.hasLetters(text)
  return type(text) == 'string' and text:match('[a-zA-Z]') ~= nil
end

function M.getSelectedText(esc)
  if esc then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<esc>', true, false, true), 'n', false)
  end
  local vstart = vim.fn.getpos("'<")
  local vend = vim.fn.getpos("'>")
  -- If the selection has been made under VISUAL mode:
  local ok, lines = pcall(vim.api.nvim_buf_get_text, 0, vstart[2] - 1, vstart[3] - 1, vend[2] - 1, vend[3], {})
  if ok then
    return joinLines(lines)
  else
    -- If the selection has been made under VISUAL LINE mode:
    lines = vim.api.nvim_buf_get_lines(0, vstart[2] - 1, vend[2], false)
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

function M.createPopup(initialContent, width, height)
  M.close()

  local bufnr = vim.api.nvim_create_buf(false, true)

  local update = function(content)
    if content == nil then
      content = ''
    end
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
    width = width,
    height = height,
    row = 1,
    col = 0,
  })
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
  update(initialContent)
  if M.opts.result_popup_gets_focus then
    vim.api.nvim_set_current_win(win_id)
  end
  return update
end


-- Act as a Lua software developer.
-- Is there a more elegant way to write the M.handle function below?
-- 
function M.fill(tpl, args)
  if tpl == nil then
    tpl = ''
  else
    for key, value in pairs(args) do
      tpl = string.gsub(tpl, '%${' .. key .. '}', value)
    end
  end
  return tpl
end

function M.handle(name, input)
  local def = M.prompts[name]
  local width = vim.fn.winwidth(0)
  local height = vim.fn.winheight(0)
  local args = {
    locale = M.opts.locale,
    alternate_locale = M.opts.alternate_locale,
    input = input,
    input_encoded = vim.fn.json_encode(input),
  }
  local update = M.createPopup(M.fill(def.loading_tpl, args), width - 24, height - 16)
  local prompt = M.fill(def.prompt_tpl, args)

  gemini.askGemini(
    prompt,
    {
      handleResult = function(gemini_output)
        args.gemini_output = gemini_output
        chatgpt.askChatGPT(
          prompt,
          {
            handleResult = function(chatgpt_output)
              args.chatgpt_output = chatgpt_output
              args.output = args.gemini_output .. args.chatgpt_output
              return M.fill(def.result_tpl or '${output}', args)
            end,
            callback = update,
          },
          M.opts.chargpt_api_key
        )
      end,
      callback = update,
    },
    M.opts.gemini_api_key
  )
end


function M.assign(table, other)
  for k, v in pairs(other) do
    table[k] = v
  end
  return table
end

function M.setup(opts)
  for k, v in pairs(opts) do
    if k == 'prompts' then
      M.prompts = {}
      M.assign(M.prompts, default_prompts)
      M.assign(M.prompts, v)
    elseif M.opts[k] ~= nil then
      M.opts[k] = v
    end
  end
  assert(M.opts.api_key ~= nil and M.opts.api_key ~= '', 'api_key is required')

  for k, v in pairs(M.prompts) do
    if v.command then
      vim.api.nvim_create_user_command(v.command, function(args)
        local text = args['args']
        if isEmpty(text) then
          text = M.getSelectedText(true)
        end
        if not v.require_input or M.hasLetters(text) then
          -- delayed so the popup won't be closed immediately
          vim.schedule(function()
            M.handle(k, text)
          end)
        end
      end, { range = true, nargs = '?' })
    end
  end
end

vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
  callback = M.close,
})

vim.api.nvim_create_user_command('GeminiDefineCword', function()
  local text = vim.fn.expand('<cword>')
  if M.hasLetters(text) then
    M.handle('define', text)
  end
end, {})

return M
