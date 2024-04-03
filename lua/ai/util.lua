local M = {}

function M.split(input, sep)
  local parts = {}
  local offset = 1
  while offset > 0 do
    local i = string.find(input, sep, offset)
    if i == nil then
      table.insert(parts, string.sub(input, offset, -1))
      offset = 0
    else
      table.insert(parts, string.sub(input, offset, i - 1))
      offset = i + 1
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

function M.assign(table, other)
  for k, v in pairs(other) do
    table[k] = v
  end
  return table
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
    local value = args[params[1]]
    table.remove(params, 1)
    for k, pipe in ipairs(params) do
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

function M.createPopup(initialContent, width, height, opts)
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
    width = width,
    height = height,
    row = 1,
    col = 0,
  })
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
  update(initialContent)
  if opts.result_popup_gets_focus then
    vim.api.nvim_set_current_win(win_id)
  end
  return update
end

function M.closePopup()
  if win_id == nil or win_id == vim.api.nvim_get_current_win() then
    return
  end
  pcall(vim.api.nvim_win_close, win_id, true)
  win_id = nil
end

return M
