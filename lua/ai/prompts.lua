local prompts = {
  define = {
    command = 'GeminiDefine',
    provider = 'gemini',
    loading_tpl = 'Define:\n\n{{input}}\n\nAsking Gemini...',
    prompt_tpl =
    'Define the given content in locale {{locale}}. The output is a bullet list of definitions grouped by parts of speech in plain text. Each item of the definition list contains pronunciation using IPA, meaning, and a list of usage examples with at most 2 items. Do not return anything else. Here is the content:\n\n{{input |> json_encode}}',
    result_tpl = 'Original Content:\n\n{{input}}\n\nDefinition:\n\n{{output}}',
    require_input = true,
  },
  translate = {
    command = 'GeminiTranslate',
    provider = 'gemini',
    loading_tpl = 'Translating the content below:\n\n{{input}}\n\nAsking Gemini...',
    prompt_tpl =
    'Translate the given content into locale {{locale}}. Translate into {{alternate_locale}} instead if it is already in {{locale}}. Do not return anything else. Here is the content:\n\n{{input |> json_encode}}',
    result_tpl = 'Original Content:\n\n{{input}}\n\nTranslation:\n\n{{output}}',
    require_input = true,
  },
  improve = {
    command = 'GeminiImprove',
    provider = 'gemini',
    loading_tpl = 'Improve the content below:\n\n{{input}}\n\nAsking Gemini...',
    prompt_tpl =
    'Make the given content more native, correcting grammar while keeping the same locale. Do not return anything else. Here is the content:\n{{input |> json_encode}}',
    result_tpl = 'Original Content:\n\n{{input}}\n\nImproved Content:\n\n{{output}}',
    require_input = true,
  },
  freeStyle = {
    command = 'GeminiAsk',
    provider = 'gemini',
    loading_tpl = '# Question:\n\n{{input}}\n\nAsking Gemini...',
    prompt_tpl = '{{input}}',
    result_tpl = '# Question:\n\n{{input}}\n\n# Answer:\n\n{{output}}',
    require_input = true,
  },
  freeStyleOpenAI = {
    command = 'OpenAIAsk',
    provider = 'openai',
    loading_tpl = '# Question:\n\n{{input}}\n\nAsking OpenAI...',
    prompt_tpl = '{{input}}',
    result_tpl = '# Question:\n\n{{input}}\n\n# Answer:\n\n{{output}}',
    require_input = true,
  },
}

return prompts
