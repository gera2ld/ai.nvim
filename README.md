# ai.nvim

A Neovim plugin powered by Google Gemini.

https://github.com/gera2ld/ai.nvim/assets/3139113/539834ed-af80-4ded-81f4-26afa80ddfd3

## Installation

First [get an API key](https://ai.google.dev/tutorials/setup) from Gemini. It's free!

Using lazy.nvim:

```lua
{
  'gera2ld/ai.nvim',
  dependencies = 'nvim-lua/plenary.nvim',
  opts = {
    api_key = 'YOUR_GEMINI_API_KEY', -- or read from env: `os.getenv('GEMINI_API_KEY')`
    -- The locale for the content to be defined/translated into
    locale = 'en',
    -- The locale for the content in the locale above to be translated into
    alternate_locale = 'zh',
    -- Gemini's answer is displayed in a popup buffer
    -- Default behaviour is not to give it the focus because it is seen as a kind of tooltip
    -- But if you prefer it to get the focus, set to true.
    result_popup_gets_focus = false,
    -- Define custom prompts here, see below for more details
    prompts = {},
  },
  event = 'VeryLazy',
},
```

## Usage

### Built-in Commands

```viml
" Define the word under cursor
:GeminiDefineCword

" Define the word or phrase selected or passed to the command
:'<,'>GeminiDefine
:GeminiDefine happy

" Translate content selected or passed to the commmand
:'<,'>GeminiTranslate
:GeminiTranslate I am happy.

" Improve content selected or passed to the command
" Useful to correct grammar mistakes and make the expressions more native.
:'<,'>GeminiImprove
:GeminiTranslate Me is happy.

" Ask anything
:GeminiAsk Tell a joke.
```

### Custom Prompts

```lua
opts = {
  prompts = {
    rock = {
      -- Create a user command for this prompt
      command = 'GeminiRock',
      loading_tpl = 'Loading...',
      prompt_tpl = 'Tell a joke',
      result_tpl = 'Here is your joke:\n\n$output',
      require_input = false,
    },
  },
}
```

The prompts will be merged into built-in prompts. Here are the available fields for each prompt:

| Fields          | Required | Description                                                                                      |
| --------------- | -------- | ------------------------------------------------------------------------------------------------ |
| `command`       | No       | If defined, a user command will be created for this prompt.                                      |
| `loading_tpl`   | No       | Template for content shown when communicating with Gemini. See below for available placeholders. |
| `prompt_tpl`    | Yes      | Template for the prompt string passed to Gemini. See below for available placeholders.           |
| `result_tpl`    | No       | Template for the result shown in the popup. See below for available placeholders.                |
| `require_input` | No       | If set to `true`, the prompt will only be sent if text is selected or passed to the command.     |

Placeholders can be used in templates. If not available, it will be left as is.

| Placeholders          | Description                                                                                | Availability      |
| --------------------- | ------------------------------------------------------------------------------------------ | ----------------- |
| `${locale}`           | `opts.locale`                                                                              | Always            |
| `${alternate_locale}` | `opts.alternate_locale`                                                                    | Always            |
| `${input}`            | The text selected or passed to the command.                                                | Always            |
| `${input_encoded}`    | The text encoded with JSON so that Gemini will take it as literal instead of a new prompt. | Always            |
| `${output}`           | The result returned by Gemini.                                                             | After the request |

We can either call a prompt with the associated command:

```viml
:GeminiRock
```

or with its name:

```viml
:lua require('ai').handle('rock')
```

## Related Projects

- [coc-ai](https://github.com/gera2ld/coc-ai) - A coc.nvim plugin powered by Gemini
