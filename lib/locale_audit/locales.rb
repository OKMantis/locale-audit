# frozen_string_literal: true

module LocaleAudit
  NBSP = ' '
  SOURCE_LOCALE = 'en-US'

  # Hand-rolled from CLDR number and currency data. Currency is shown as its
  # ISO code: "$" means USD, CAD, AUD and MXN, which is no good in a payout email.
  # min_grouping is CLDR's minimumGroupingDigits: es-ES writes 1234,56 but 12.345,67.
  # Scope: four locales; load CLDR data when the list grows.
  LOCALES = {
    'en-US' => { group: ',', decimal: '.', min_grouping: 1, money: "%<code>s#{NBSP}%<number>s" },
    'es-ES' => { group: '.', decimal: ',', min_grouping: 2, money: "%<number>s#{NBSP}%<code>s" },
    'de-DE' => { group: '.', decimal: ',', min_grouping: 1, money: "%<number>s#{NBSP}%<code>s" },
    'ja-JP' => { group: ',', decimal: '.', min_grouping: 1, money: "%<code>s#{NBSP}%<number>s" }
  }.freeze

  # ISO 4217 minor-unit exponents: how many minor units make one major unit, as a power of ten.
  CURRENCY_EXPONENT = { 'USD' => 2, 'EUR' => 2, 'GBP' => 2, 'JPY' => 0, 'KWD' => 3 }.freeze

  def self.locale(code) = LOCALES.fetch(code) { raise ArgumentError, "unsupported locale #{code}" }
end
