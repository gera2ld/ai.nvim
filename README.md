# ai.nvim

A Neovim plugin powered by AI.

Supported providers:

- Google Gemini: [get an API key](https://ai.google.dev/tutorials/setup) for free.
- OpenAI compatible APIs

https://github.com/gera2ld/ai.nvim/assets/3139113/539834ed-af80-4ded-81f4-26afa80ddfd3

## Installation

Using lazy.nvim:

```lua
{
  'gera2ld/ai.nvim',
  dependencies = 'nvim-lua/plenary.nvim',
  opts = {
    ---- AI's answer is displayed in a popup buffer
    ---- Default behaviour is not to give it the focus because it is seen as a kind of tooltip
    ---- But if you prefer it to get the focus, set to true.
    result_popup_gets_focus = false,
    ---- Override default prompts here, see below for more details
    -- prompts = {},
    ---- Default models for each prompt, can be overridden in the prompt definition
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

    --- API keys and relavant config
    gemini = {
      api_key = 'YOUR_GEMINI_API_KEY',
      -- model = 'gemini-pro',
      -- proxy = '',
    },
    openai = {
      api_key = 'YOUR_OPENAI_API_KEY',
      -- base_url = 'https://api.openai.com/v1',
      -- model = 'gpt-4',
      -- proxy = '',
    },
  },
  event = 'VeryLazy',
},
```

Alternatively, load API keys from an environment variable:

```bash
export AI_NVIM_PROVIDER_CONFIG='{
  "openai": {
    "api_key": "YOUR_OPENAI_API_KEY"
  }
}'
```

```lua
{
  'gera2ld/ai.nvim',
  dependencies = 'nvim-lua/plenary.nvim',
  config = function ()
    local ai = require('ai')
    local ok, opts = pcall(vim.fn.json_decode, os.getenv('AI_NVIM_PROVIDER_CONFIG'))
    opts = ok and opts or {}
    ai.setup(opts)
  end,
  event = 'VeryLazy',
},
```

## Usage

### Built-in Commands

```viml
" Define the word under cursor
:AIDefine

" Define the word or phrase selected or passed to the command
:'<,'>AIDefine
:AIDefine happy

" Translate content selected or passed to the commmand
:'<,'>AITranslate
:AITranslate I am happy.

" Improve content selected or passed to the command
" Useful to correct grammar mistakes and make the expressions more native.
:'<,'>AIImprove
:AIImprove Me is happy.

" Ask anything
:AskAI Tell a joke.
```

### Custom Prompts

```lua
{
  prompts = {
    rock = {
      -- Create a user command for this prompt
      command = 'GeminiRock',
      header_tpl = '## Rock\n\n{{input}}',
      prompt_tpl = 'Tell a joke',
      require_input = false,

      -- Optionally override the default models
      models = {
        {
          provider = 'gemini',
          model = 'gemini-1.5-pro',
          result_tpl = '## Joke from Gemini\n\n{{output}}',
        },
      },
    },
  },
}
```

The prompts will be merged into built-in prompts. Here are the available fields for each prompt:

| Fields          | Required | Description                                                                                  |
| --------------- | -------- | -------------------------------------------------------------------------------------------- |
| `command`       | No       | If defined, a user command will be created for this prompt.                                  |
| `loading_tpl`   | No       | Template for content shown when communicating with AI. See below for available placeholders. |
| `prompt_tpl`    | Yes      | Template for the prompt string passed to AI. See below for available placeholders.           |
| `result_tpl`    | No       | Template for the result shown in the popup. See below for available placeholders.            |
| `require_input` | No       | If set to `true`, the prompt will only be sent if text is selected or passed to the command. |

Placeholders can be used in templates. If not available, it will be left as is.

| Placeholders | Description                                 | Availability      |
| ------------ | ------------------------------------------- | ----------------- |
| `{{input}}`  | The text selected or passed to the command. | Always            |
| `{{output}}` | The result returned by AI.                  | After the request |

Placeholders can be used along with helpers to transform the values, in the form of `{{ input |> helper1 |> helper2 }}`. For example, `{{ input |> json_encode }}` will be replaced with `json_encode(input)`.

Possible helpers are:

| Helpers       | Description             |
| ------------- | ----------------------- |
| `json_encode` | Encode the data as JSON |

We can either call a prompt with the associated command:

```viml
:GeminiRock
```

or with its name:

```viml
:lua require('ai').handle('rock')
```

### Custom Keymaps

```lua
-- Add a keymap to enter the popup
vim.keymap.set('n', '<enter>', require('ai.util').enterPopup)
```

## Related Projects

- [coc-ai](https://github.com/gera2ld/coc-ai) - A coc.nvim plugin powered by AI
