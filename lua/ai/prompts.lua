local prompts = {
  define = {
    command = 'AIDefine',
    header_tpl = '## Define\n\n{{input}}',
    prompt_tpl = {
      {
        role = "system",
        content =
        "You act as a dictionary. Define anything I provide in English. The output is a bullet list of definitions grouped by parts of speech in plain text. Each item of the definition list contains pronunciation using IPA, meaning, and a list of usage examples with at most 2 items. Do not return anything else."
      },
      { role = "user", content = "{{input}}" }
    },
    require_input = true,
  },
  translate = {
    command = 'AITranslate',
    header_tpl = "## AI Powered Translation\n\n### Source\n\n{{input}}",
    prompt_tpl = {
      {
        role = "system",
        content =
        "You are a translator. You detect the language of the content I provide and translate it into English. If the content is already in this language, translate it into Chinese. Only return the translation. Do not return anything else."
      },
      { role = "user", content = "{{input}}" }
    },
    require_input = true,
  },
  improve = {
    command = 'AIImprove',
    header_tpl = "## AI Improvement\n\n{{input}}",
    prompt_tpl = {
      {
        role = "system",
        content =
        "You are a native speaker. Make the content I provide more native, correcting grammar while keeping the same locale. Do not return anything else."
      },
      { role = "user", content = "{{input}}" }
    },
    require_input = true,
  },
  freeStyle = {
    command = 'AIAsk',
    header_tpl = '## Question:\n\n{{input}}',
    prompt_tpl = '{{input}}',
    require_input = true,
  },
}

return prompts
