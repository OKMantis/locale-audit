# frozen_string_literal: true

RSpec.describe LocaleAudit::LlmTranslator do
  root = File.expand_path('..', __dir__)
  catalogue = { 'fee.applied' => { 'source' => 'A fee of %{fee} was deducted.' } }

  # Stands in for Anthropic::Client#messages; records the request it was given.
  fake_client = Class.new do
    attr_reader :request

    def initialize(reply, stop_reason: :end_turn)
      @reply = reply
      @stop_reason = stop_reason
    end

    def messages = self

    def create(**request)
      @request = request
      block = Struct.new(:type, :text)
      Struct.new(:content, :stop_reason, :stop_details)
            .new([block.new(:thinking, nil), block.new(:text, @reply)], @stop_reason, nil)
    end
  end

  it 'asks for one JSON string per catalogue key and returns them' do
    client = fake_client.new('{"fee.applied":"Eine Gebühr von %{fee} wurde abgezogen."}')
    expect(described_class.new(client:).translate(catalogue, 'de-DE'))
      .to eq('fee.applied' => 'Eine Gebühr von %{fee} wurde abgezogen.')
    expect(client.request[:model]).to eq('claude-opus-5-5')
    expect(client.request.dig(:output_config, :format_, :schema, :required)).to eq(['fee.applied'])
    expect(client.request[:messages].first[:content]).to include('de-DE', 'A fee of %{fee} was deducted.')
  end

  it 'raises on a refusal rather than auditing an empty set' do
    client = fake_client.new('', stop_reason: :refusal)
    expect { described_class.new(client:).translate(catalogue, 'ja-JP') }.to raise_error(/declined/)
  end

  describe 'the recorded LLM candidate set' do
    path = "#{root}/fixtures/translations/llm.yml"

    it 'passes every control, or the build fails with the exception report' do
      audit = LocaleAudit::Audit.new(catalogue: LocaleAudit.load_yaml("#{root}/fixtures/catalogue.yml"),
                                     translations: LocaleAudit.load_yaml(path).fetch('translations'), label: path)
      expect(audit).to be_passed, audit.report
    end
  end
end
