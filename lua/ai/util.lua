local M = {}

function M.get(target, path)
  local value = target
  for _, key in ipairs(path) do
    if value == nil then
      break
    end
    value = value[key]
  end
  return value
end

function M.split(input, sep)
  local parts = {}
  local offset = 1
  local lsep = string.len(sep)
  while offset > 0 do
    local i = string.find(input, sep, offset)
    if i == nil then
      table.insert(parts, string.sub(input, offset, -1))
      offset = 0
    else
      table.insert(parts, string.sub(input, offset, i - 1))
      offset = i + lsep
    end
  end
  return parts
end

function M.join(parts, sep)
  local result = ''
  for i, part in ipairs(parts) do
    if i > 1 then
      result = result .. sep
    end
    result = result .. part
  end
  return result
end

function M.assign(target, ...)
  for _, other in ipairs { ... } do
    for k, v in pairs(other) do
      target[k] = v
    end
  end
  return target
end

function M.merge(target, ...)
  target = M.assign({}, target)
  for _, other in ipairs { ... } do
    for key, value in pairs(other) do
      local original = target[key]
      if type(original) == 'table' and type(value) == 'table' then
        target[key] = M.merge(original, value)
      else
        target[key] = value
      end
    end
  end
  return target
end

function M.isEmpty(text)
  return text == nil or type(text) == 'string' and text:find('%S') == nil
end

function M.fill(tpl, args, helpers)
  if tpl == nil then
    tpl = ''
  end
  local parts = {}
  local offset = 1
  while offset > 0 do
    local i = string.find(tpl, '{{', offset)
    if i == nil then
      table.insert(parts, string.sub(tpl, offset, -1))
      break
    end
    table.insert(parts, string.sub(tpl, offset, i - 1))
    local j = string.find(tpl, '}}', i)
    local params = M.split(string.sub(tpl, i + 2, j - 1), '|>')
    for k, param in ipairs(params) do
      params[k] = string.gsub(param, '%s+', '')
    end
    local value = args[params[1]]
    table.remove(params, 1)
    for _, pipe in ipairs(params) do
      local pipe_handler = helpers[pipe]
      assert(pipe_handler ~= nil, 'Invalid pipe: ' .. pipe)
      value = pipe_handler(value)
    end
    table.insert(parts, value or '')
    offset = j + 2
  end
  return M.join(parts, '')
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
    return M.join(lines, '\n')
  else
    -- If the selection has been made under VISUAL LINE mode:
    lines = vim.api.nvim_buf_get_lines(0, vstart[2] - 1, vend[2], false)
    return M.join(lines, '\n')
  end
end

local win_id

function M.createPopup(initialContent, opts)
  M.closePopup()

  local bufnr = vim.api.nvim_create_buf(false, true)

  local update = function(content)
    if content == nil then
      content = ''
    end
    local lines = M.split(content, '\n')
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
    vim.bo[bufnr].modifiable = false
  end

  win_id = vim.api.nvim_open_win(bufnr, false, {
    relative = 'cursor',
    border = 'single',
    title = 'ai.nvim',
    style = 'minimal',
    width = opts.width,
    height = opts.height,
    row = 1,
    col = 0,
  })
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
  vim.keymap.set('n', 'q', M.closePopup, { buffer = bufnr })
  update(initialContent)
  if opts.result_popup_gets_focus then
    M.enterPopup()
  end
  return update
end

function M.enterPopup()
  if win_id == nil then
    return
  end
  vim.api.nvim_set_current_win(win_id)
end

function M.closePopup()
  if win_id == nil then
    return
  end
  pcall(vim.api.nvim_win_close, win_id, true)
  win_id = nil
end

function M.closePopupIfNotFocused()
  if win_id == vim.api.nvim_get_current_win() then
    return
  end
  M.closePopup()
end

function M.buildMessages(promptTpl, args, helpers)
  if type(promptTpl) == 'string' then
    promptTpl = { { role = 'user', content = promptTpl } }
  end
  local messages = {}
  for _, message in ipairs(promptTpl) do
    message = M.assign({}, message)
    message['content'] = M.fill(message['content'], args, helpers)
    table.insert(messages, message)
  end
  return messages
end

return M
