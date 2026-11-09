require "date"
require "yaml"
require_relative "locale_audit/locales"
require_relative "locale_audit/money"

module LocaleAudit
  PLACEHOLDER = /%\{(\w+)\}/

  module_function

  # The platform's one rendering path: money from minor units, dates from Date,
  # both formatted by the locale tables, never by the string's author.
  def render(template, args, locale)
    template.gsub(PLACEHOLDER) do
      value = args.fetch(Regexp.last_match(1)) { raise KeyError, "no argument for %{#{Regexp.last_match(1)}}" }
      case value
      when Hash then Money.format(value.fetch("minor"), value.fetch("currency"), locale)
      when Date then value.strftime(locale(locale)[:date])
      else value.to_s
      end
    end
  end

  def load_yaml(path) = YAML.safe_load_file(path, permitted_classes: [Date])
end
