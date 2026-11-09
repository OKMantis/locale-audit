# frozen_string_literal: true

require 'date'
require 'yaml'
require_relative 'locale_audit/locales'
require_relative 'locale_audit/money'

module LocaleAudit
  PLACEHOLDER = /%\{(\w+)\}/

  module_function

  def load_yaml(path) = YAML.safe_load_file(path, permitted_classes: [Date])
end

require_relative 'locale_audit/controls'
require_relative 'locale_audit/audit'
require_relative 'locale_audit/llm_translator'
