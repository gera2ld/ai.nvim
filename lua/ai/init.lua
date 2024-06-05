local util = require('ai.util')
local gemini = require('ai.providers.gemini')
local openai = require('ai.providers.openai')
local default_prompts = require('ai.prompts')

local M = {}

M.util = util
M.default_prompts = default_prompts

M.opts = {
  result_popup_gets_focus = false,
  prompts = default_prompts,
  gemini = {
    api_key = '',
    proxy = '',
  },
  openai = {
    api_key = '',
    base_url = 'https://api.openai.com/v1',
    proxy = '',
  },
  -- can be overridden in prompts
  models = {
    {
      provider = 'gemini',
      model = 'gemini-pro',
      result_tpl = '## Gemini\n\n{{output}}',
    },
    {
      provider = 'openai',
      model = 'gpt-3.5-turbo',
      result_tpl = '## GPT-3.5\n\n{{output}}',
    },
  },
}

local providers = {
  gemini = gemini,
  openai = openai,
}

function M.handle(name, input)
  local def = M.opts.prompts[name]
  local models = def.models or M.opts.models
  local width = vim.fn.winwidth(0)
  local height = vim.fn.winheight(0)
  local args = {
    input = input,
  }
  local helpers = {
    json_encode = vim.fn.json_encode,
  }
  local header = util.fill(def.header_tpl, args, helpers)
  local update = util.createPopup(
    header,
    {
      width = width - 24,
      height = height - 16,
      result_popup_gets_focus = M.opts.result_popup_gets_focus,
    }
  )
  local results = {}
  local loading = 0
  local modelLen = 0
  local render = function()
    local contents = { header }
    for i = 1, modelLen do
      local output = results[i]
      if output ~= nil then
        table.insert(contents, output)
      end
    end
    if loading > 0 then
      table.insert(contents, '---\n\nLoading more...')
    end
    update(util.join(contents, '\n\n'))
  end
  local messages = util.buildMessages(def.prompt_tpl, args, helpers)
  for i, model in ipairs(models) do
    if modelLen < i then
      modelLen = i
    end
    local provider = providers[model.provider]
    local providerOpts = M.opts[model.provider]
    if provider and providerOpts and provider.precheck(providerOpts) then
      loading = loading + 1
      provider.request(messages, providerOpts, {
        model = model.model,
        callback = function(output)
          args.output = output
          output = util.fill(model.result_tpl or ('## ' .. model.model .. '\n\n{{output}}'), args, helpers)
          results[i] = output
          loading = loading - 1
          render()
        end,
      })
    end
  end
  render()
end

function M.setup(opts)
  M.opts = util.assign(M.opts, opts)

  for k, v in pairs(M.opts.prompts) do
    if v.command then
      vim.api.nvim_create_user_command(v.command, function(args)
        local text = args['args']
        if util.isEmpty(text) then
          text = util.getSelectedText(true)
        end
        if util.isEmpty(text) then
          text = vim.fn.expand('<cword>')
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
  callback = util.closePopupIfNotFocused,
})

return M
