# frozen_string_literal: true

require 'bigdecimal'

module LocaleAudit
  # Money is an Integer count of minor units plus an ISO 4217 code. Nothing here
  # touches Float: formatting is integer divmod, parsing back is BigDecimal.
  module Money
    module_function

    def exponent(currency)
      CURRENCY_EXPONENT.fetch(currency) { raise ArgumentError, "unknown currency #{currency}" }
    end

    def format(minor, currency, locale)
      raise TypeError, "money must be Integer minor units, got #{minor.inspect}" unless minor.is_a?(Integer)

      l = LocaleAudit.locale(locale)
      exp = exponent(currency)
      major, fraction = minor.abs.divmod(10**exp)
      number = group(major.to_s, l)
      number += l[:decimal] + fraction.to_s.rjust(exp, '0') if exp.positive?
      (minor.negative? ? '-' : '') + Kernel.format(l[:money], code: currency, number: number)
    end

    # Reads a formatted amount back into minor units. Used by the audit to prove
    # every rendered amount round-trips without losing or inventing precision.
    def parse(text, currency, locale)
      l = LocaleAudit.locale(locale)
      number = text.delete(NBSP).sub(currency, '').delete(l[:group]).tr(l[:decimal], '.')
      minor = BigDecimal(number) * (10**exponent(currency))
      raise ArgumentError, "#{text.inspect} is more precise than #{currency} allows" unless minor.frac.zero?

      minor.to_i
    end

    def group(digits, loc)
      return digits if digits.length < 3 + loc[:min_grouping]

      digits.reverse.scan(/\d{1,3}/).join(loc[:group]).reverse
    end
  end
end
