# frozen_string_literal: true

require 'tmpdir'

RSpec.describe LocaleAudit::Audit do
  root = File.expand_path('..', __dir__)
  catalogue = LocaleAudit.load_yaml("#{root}/fixtures/catalogue.yml")
  # A set that cannot have translation defects: every locale echoes the source.
  echo = (LocaleAudit::LOCALES.keys - [LocaleAudit::SOURCE_LOCALE]).to_h do |l|
    [l, catalogue.transform_values { |e| e['source'] }]
  end

  def audit(catalogue, translations, **opts) = described_class.new(catalogue:, translations:, label: 'spec', **opts)

  it 'gives an unqualified opinion when nothing is wrong, the source strings and the code included' do
    result = audit(catalogue, echo)
    expect(result.findings).to be_empty, result.report
    expect(result.report).to include('OPINION: UNQUALIFIED')
  end

  describe 'the seeded-defect fixture' do
    result = described_class.new(
      catalogue:, label: 'defective',
      translations: LocaleAudit.load_yaml("#{root}/fixtures/translations/defective.yml").fetch('translations')
    )
    expected = File.readlines("#{root}/fixtures/translations/defective.yml", encoding: 'UTF-8').flat_map do |line|
      key = line[/^\s+([\w.]+):/, 1]
      line.scan(/I18N-\d\d/).map { |id| [id, key] }
    end

    it 'is caught on every seeded defect and nowhere else' do
      expect(result.findings.map { |f| [f.control, f.key] }.uniq).to match_array(expected)
    end

    it 'fails with an adverse opinion and an exception report naming every offending key' do
      expect(result).not_to be_passed
      expect(result.report).to include('OPINION: ADVERSE')
      expected.map(&:last).uniq.each { |key| expect(result.report).to include(key) }
    end
  end

  it 'reports a missing translation against I18N-01' do
    translations = echo.merge('de-DE' => echo['de-DE'].except('fee.applied'))
    expect(audit(catalogue, translations).findings).to contain_exactly(
      LocaleAudit::Finding.new('I18N-01', 'fee.applied', 'de-DE', 'no translation')
    )
  end

  it 'reports a Float amount in the catalogue once, against the source, under I18N-04' do
    float_fee = { 'fee' => { 'minor' => 1.5, 'currency' => 'EUR' } }
    bad = catalogue.merge('fee.applied' => catalogue['fee.applied'].merge('args' => float_fee))
    expect(audit(bad, echo).findings).to contain_exactly(
      LocaleAudit::Finding.new('I18N-04', 'fee.applied', 'en-US', '%{fee} is Float 1.5, not Integer minor units')
    )
  end

  it 'audits the en-US source too, because product teams ship US-first' do
    bad = catalogue.merge('fee.applied' => { 'source' => 'A fee of $1.50 was deducted.', 'args' => {} })
    source_findings = audit(bad, echo).findings.select { |f| f.locale == 'en-US' }
    expect(source_findings.map(&:detail)).to eq(['literal currency "$"; currency comes from the money argument',
                                                 'literal amount "1.50"; amounts render from minor units'])
  end

  it 'rejects locales the platform has no tables for rather than skipping them' do
    expect { audit(catalogue, echo.merge('fr-FR' => {})) }.to raise_error(ArgumentError, /fr-FR/)
  end

  describe 'the float scan in I18N-04' do
    it 'finds no float anywhere in lib/' do
      expect(LocaleAudit::Controls.float_scan("#{root}/lib")).to be_empty
    end

    it 'names the file and line where float creeps in' do
      Dir.mktmpdir do |dir|
        File.write("#{dir}/fx.rb", "# 1.5 in a comment is fine\nrate = amount.to_f * 1.1\n")
        result = audit(catalogue, echo, code_root: dir)
        expect(result.findings).to contain_exactly(
          LocaleAudit::Finding.new('I18N-04', "#{File.basename(dir)}/fx.rb:2", 'code',
                                   'float arithmetic in the money path')
        )
      end
    end
  end
end
