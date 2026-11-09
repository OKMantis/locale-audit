# frozen_string_literal: true

module LocaleAudit
  # A control takes one candidate string (the en-US source or a translation)
  # and returns one line per exception. No exceptions means the string passes.
  Control = Data.define(:id, :description, :check)

  module Controls
    POSITIONAL = /%(?:\d+\$)?[sdif]|\{\d+\}/
    DATE_LITERAL = %r{\p{Nd}{1,4}[/.-]\p{Nd}{1,2}[/.-]\p{Nd}{1,4}}
    AMOUNT_LITERAL = /\p{Nd}+(?:[.,\u00A0 ]\p{Nd}+)+/
    CURRENCY_LITERAL = /[$€£¥￥]|(?<![A-Za-z])(?:#{CURRENCY_EXPONENT.keys.join('|')})(?![A-Za-z])/
    # Written so this file does not match its own patterns.
    FLOAT_USE = /\w\.to_f\b|\bFloat\(|\w\.fdiv\b|(?<![\w.])\d+\.\d+(?![\w.])/

    module_function

    def placeholders(text) = text.scan(PLACEHOLDER).flatten
    def bare(text) = text.gsub(PLACEHOLDER, '')

    def placeholder_set(text, entry, _locale)
      want = placeholders(entry['source']).tally
      got = placeholders(text).tally
      (want.keys | got.keys).filter_map do |name|
        "%{#{name}}: expected #{want.fetch(name, 0)}, found #{got.fetch(name, 0)}" if want[name] != got[name]
      end
    end

    def order(text, entry, _locale)
      found = bare(text).scan(POSITIONAL).map { |t| "positional token #{t} rebinds silently if a translator reorders" }
      return found unless entry['order_locked']

      want = placeholders(entry['source'])
      got = placeholders(text) & want
      if got.sort == want.sort && got != want
        found << "order #{got.join(', ')} reverses source order #{want.join(', ')}"
      end
      found
    end

    def money_literals(text, _entry, _locale)
      b = bare(text).gsub(DATE_LITERAL, '')
      b.scan(CURRENCY_LITERAL).map { |c| "literal currency #{c.inspect}; currency comes from the money argument" } +
        b.scan(AMOUNT_LITERAL).map { |a| "literal amount #{a.inspect}; amounts render from minor units" }
    end

    def minor_units(_text, entry, locale)
      entry.fetch('args', {}).select { |_, v| v.is_a?(Hash) }.filter_map do |name, money|
        minor, currency = money.values_at('minor', 'currency')
        # Args belong to the key, not the locale: report a bad type once, against the source.
        unless minor.is_a?(Integer)
          next locale == SOURCE_LOCALE ? "%{#{name}} is #{minor.class} #{minor.inspect}, not Integer minor units" : nil
        end

        rendered = Money.format(minor, currency, locale)
        read_back = Money.parse(rendered, currency, locale)
        "%{#{name}} rendered #{rendered.inspect} but reads back as #{read_back}" unless read_back == minor
      end
    end

    def date_and_number_literals(text, entry, _locale)
      b = bare(text)
      dates = b.scan(DATE_LITERAL)
      digits = b.gsub(DATE_LITERAL, '').gsub(AMOUNT_LITERAL, '').scan(/\p{Nd}+/) - bare(entry['source']).scan(/\p{Nd}+/)
      dates.map { |d| "literal date #{d.inspect}; dates render per locale from a Date argument" } +
        digits.map { |d| "literal number #{d.inspect} not in source" }
    end

    # Exceptions are "file:line" for any Float in the shipped money path.
    def float_scan(root)
      Dir[File.join(root, '**/*.rb')].flat_map do |file|
        File.readlines(file, encoding: 'UTF-8').each_with_index.filter_map do |line, i|
          if !line.lstrip.start_with?('#') && line.match?(FLOAT_USE)
            "#{File.basename(root)}/#{file.delete_prefix("#{root}/")}:#{i + 1}"
          end
        end
      end
    end

    ALL = [
      Control.new('I18N-01', 'Placeholder set preserved exactly', method(:placeholder_set)),
      Control.new('I18N-02', 'No reordering that changes meaning', method(:order)),
      Control.new('I18N-03', 'Money only via a placeholder; no literal amount or currency', method(:money_literals)),
      Control.new('I18N-04', 'Integer minor units in, exact round-trip out; no float in the path',
                  method(:minor_units)),
      Control.new('I18N-05', 'Dates and numbers come from the locale formatter, not the string',
                  method(:date_and_number_literals))
    ].freeze
  end
end
