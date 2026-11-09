# frozen_string_literal: true

require 'json'

module LocaleAudit
  # Machine translation in the loop: asks Claude to translate the catalogue
  # into one locale. The output is a candidate set for the audit and is never trusted.
  class LlmTranslator
    MODEL = 'claude-opus-5-5'
    SYSTEM = <<~PROMPT
      You translate UI strings for a payments product. Each value is a template.
      Keep every %{name} placeholder exactly as written: same names, no translation, no additions.
      Never write an amount, currency, date or number yourself; the platform fills placeholders at render time.
    PROMPT

    def initialize(client: nil)
      @client = client || begin
        require 'anthropic'
        Anthropic::Client.new # reads ANTHROPIC_API_KEY
      end
    end

    def translate(catalogue, locale)
      sources = catalogue.transform_values { |entry| entry.fetch('source') }
      message = @client.messages.create(**request(sources, locale))
      if message.stop_reason == :refusal
        raise "Claude declined to translate into #{locale}: #{message.stop_details&.explanation}"
      end

      JSON.parse(message.content.find { |block| block.type == :text }.text)
    end

    private

    def request(sources, locale)
      {
        model: MODEL,
        max_tokens: 16_000,
        system_: SYSTEM,
        messages: [{ role: 'user', content: "Translate into #{locale}:\n#{JSON.pretty_generate(sources)}" }],
        output_config: { effort: :low, format_: { type: :json_schema, schema: schema(sources.keys) } }
      }
    end

    def schema(keys)
      { type: 'object', additionalProperties: false, required: keys,
        properties: keys.to_h { |key| [key, { type: 'string' }] } }
    end
  end
end
