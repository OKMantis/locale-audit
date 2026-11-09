# frozen_string_literal: true

module LocaleAudit
  Finding = Data.define(:control, :key, :locale, :detail)

  # Runs every control over every (key, locale) pair, the en-US source
  # included, and states an opinion the way a working-paper review does.
  class Audit
    LIB = File.expand_path('..', __dir__)

    attr_reader :findings

    def initialize(catalogue:, translations:, label:, code_root: LIB)
      unsupported = translations.keys - LOCALES.keys
      raise ArgumentError, "unsupported locales: #{unsupported.join(', ')}" if unsupported.any?

      @catalogue = catalogue
      @label = label
      @findings = audit_strings(translations) + Controls.float_scan(code_root).map do |where|
        Finding.new('I18N-04', where, 'code', 'float arithmetic in the money path')
      end
    end

    def passed? = findings.empty?

    def report
      sections = [header, control_summary, ['', opinion]]
      sections << exception_report unless passed?
      sections.flatten.join("\n")
    end

    private

    def header
      ['LOCALE-CORRECTNESS AUDIT', "Candidate set: #{@label}",
       "Population:    #{@catalogue.size} keys x #{LOCALES.size} locales = " \
       "#{@catalogue.size * LOCALES.size} strings", '']
    end

    def control_summary
      Controls::ALL.map do |c|
        n = findings.count { |f| f.control == c.id }
        format('%-8s %-68s %s', c.id, c.description, n.zero? ? 'PASS' : "FAIL  #{n}")
      end
    end

    def exception_report
      width = findings.map { |f| f.key.length }.max
      ['', 'EXCEPTION REPORT'] +
        findings.map { |f| format("%-8s %-6s %-#{width}s  %s", f.control, f.locale, f.key, f.detail) }
    end

    def opinion
      return "OPINION: UNQUALIFIED. No exceptions across #{Controls::ALL.size} controls." if passed?

      failed = findings.map(&:control).uniq.size
      "OPINION: ADVERSE. #{findings.size} exceptions across #{failed} of #{Controls::ALL.size} controls " \
        "in #{findings.map(&:key).uniq.size} keys. Build fails."
    end

    def audit_strings(translations)
      @catalogue.flat_map do |key, entry|
        LOCALES.keys.flat_map do |locale|
          text = locale == SOURCE_LOCALE ? entry['source'] : translations.dig(locale, key)
          next [Finding.new('I18N-01', key, locale, 'no translation')] if text.nil?

          Controls::ALL.flat_map { |c| c.check.call(text, entry, locale).map { |d| Finding.new(c.id, key, locale, d) } }
        end
      end
    end
  end
end
