local util = require('ai.util')
local gemini = require('ai.gemini')
local default_prompts = require('ai.prompts')

local M = {}
M.opts = {
  api_key = '',
  locale = 'en',
  alternate_locale = 'zh',
  result_popup_gets_focus = false,
}
M.prompts = default_prompts

function M.handle(name, input)
  local def = M.prompts[name]
  local width = vim.fn.winwidth(0)
  local height = vim.fn.winheight(0)
  local args = {
    locale = M.opts.locale,
    alternate_locale = M.opts.alternate_locale,
    input = input,
  }
  local helpers = {
    json_encode = vim.fn.json_encode,
  }
  local update = util.createPopup(util.fill(def.loading_tpl, args, helpers), width - 24, height - 16, M.opts)
  local prompt = util.fill(def.prompt_tpl, args, helpers)
  gemini.request(prompt, {
    apiKey = M.opts.api_key,
    handleResult = function(output)
      args.output = output
      return util.fill(def.result_tpl or '${output}', args, helpers)
    end,
    callback = update,
  })
end

function M.setup(opts)
  for k, v in pairs(opts) do
    if k == 'prompts' then
      M.prompts = {}
      util.assign(M.prompts, default_prompts)
      util.assign(M.prompts, v)
    elseif M.opts[k] ~= nil then
      M.opts[k] = v
    end
  end
  assert(not util.isEmpty(M.opts.api_key), 'api_key is required')

  for k, v in pairs(M.prompts) do
    if v.command then
      vim.api.nvim_create_user_command(v.command, function(args)
        local text = args['args']
        if util.isEmpty(text) then
          text = util.getSelectedText(true)
        end
        if not v.require_input or not util.isEmpty(text) then
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
  callback = util.closePopup,
})

vim.api.nvim_create_user_command('GeminiDefineCword', function()
  local text = vim.fn.expand('<cword>')
  if not util.isEmpty(text) then
    M.handle('define', text)
  end
end, {})

return M
