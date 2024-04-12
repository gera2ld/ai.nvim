local util = require('ai.util')
local gemini = require('ai.providers.gemini')
local openai = require('ai.providers.openai')
local default_prompts = require('ai.prompts')

local M = {}
M.opts = {
  locale = 'en',
  alternate_locale = 'zh',
  result_popup_gets_focus = false,
  prompts = default_prompts,
  gemini = {
    api_key = '',
    model = 'gemini-pro',
    proxy = '',
  },
  openai = {
    api_key = '',
    base_url = 'https://api.openai.com/v1',
    model = 'gpt-4',
    proxy = '',
  },
}

local providers = {
  gemini = gemini,
  openai = openai,
}

function M.handle(name, input)
  local def = M.opts.prompts[name]
  local provider = providers[def.provider]
  assert(provider, 'Provider is not available: ' .. def.provider)
  local providerOpts = M.opts[def.provider]
  if def.model then
    providerOpts.model = def.model
  end
  provider.precheck(providerOpts)
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
  local update = util.createPopup(
    util.fill(def.loading_tpl, args, helpers),
    {
      width = width - 24,
      height = height - 16,
      result_popup_gets_focus = M.opts.result_popup_gets_focus,
    }
  )
  local prompt = util.fill(def.prompt_tpl, args, helpers)
  provider.request(prompt, providerOpts, {
    handleResult = function(output)
      args.output = output
      return util.fill(def.result_tpl or '{{output}}', args, helpers)
    end,
    callback = update,
  })
end

function M.setup(opts)
  M.opts = util.merge(M.opts, opts)

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
  callback = util.closePopup,
})

return M
