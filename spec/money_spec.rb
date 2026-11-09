# frozen_string_literal: true

RSpec.describe LocaleAudit::Money do
  nbsp = LocaleAudit::NBSP

  {
    ['en-US', 123_456, 'EUR'] => "EUR#{nbsp}1,234.56",
    ['de-DE', 123_456, 'EUR'] => "1.234,56#{nbsp}EUR",
    ['es-ES', 123_456, 'EUR'] => "1234,56#{nbsp}EUR",
    ['es-ES', 1_234_567, 'EUR'] => "12.345,67#{nbsp}EUR",
    ['ja-JP', 123_456, 'JPY'] => "JPY#{nbsp}123,456",
    ['de-DE', 1_234_567, 'KWD'] => "1.234,567#{nbsp}KWD",
    ['en-US', 5, 'USD'] => "USD#{nbsp}0.05",
    ['de-DE', -2_500, 'EUR'] => "-25,00#{nbsp}EUR",
    ['ja-JP', 0, 'JPY'] => "JPY#{nbsp}0"
  }.each do |(locale, minor, currency), expected|
    it "formats #{minor} #{currency} minor units in #{locale} as #{expected.inspect}" do
      expect(described_class.format(minor, currency, locale)).to eq(expected)
    end

    it "parses #{expected.inspect} back to exactly #{minor}" do
      expect(described_class.parse(expected, currency, locale)).to eq(minor)
    end
  end

  it 'refuses a Float, because 1234.56 is not a number of cents' do
    expect { described_class.format(1234.56, 'EUR', 'en-US') }.to raise_error(TypeError, /Integer minor units/)
  end

  it 'refuses a parse that is more precise than the currency allows' do
    expect { described_class.parse("JPY#{nbsp}12.5", 'JPY', 'ja-JP') }.to raise_error(ArgumentError, /more precise/)
  end

  it 'refuses currencies it has no exponent for' do
    expect { described_class.format(100, 'XYZ', 'en-US') }.to raise_error(ArgumentError, /unknown currency/)
  end
end

RSpec.describe LocaleAudit, '.render' do
  args = { 'amount' => { 'minor' => 123_456, 'currency' => 'EUR' }, 'date' => Date.new(2026, 3, 7) }

  {
    'en-US' => 'EUR 1,234.56 on 03/07/2026',
    'es-ES' => '1234,56 EUR on 07/03/2026',
    'de-DE' => '1.234,56 EUR on 07.03.2026',
    'ja-JP' => 'EUR 1,234.56 on 2026/03/07'
  }.each do |locale, expected|
    it "renders money and date per #{locale}" do
      expect(described_class.render('%{amount} on %{date}', args, locale)).to eq(expected)
    end
  end

  it 'raises when a placeholder has no argument' do
    expect { described_class.render('%{fee}', args, 'en-US') }.to raise_error(KeyError, /%\{fee\}/)
  end
end
