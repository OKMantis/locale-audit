Gem::Specification.new do |s|
  s.name = "locale_audit"
  s.version = "0.1.0"
  s.summary = "Locale-correctness audit harness for financial strings"
  s.authors = ["Owen Moss"]
  s.license = "MIT"
  s.required_ruby_version = ">= 3.3"
  s.files = Dir["lib/**/*.rb", "exe/*"]
  s.bindir = "exe"
  s.executables = ["locale-audit"]
  s.add_dependency "anthropic", "~> 1.68" # the one external dependency: the LLM call
  s.add_dependency "bigdecimal" # stdlib, declared so Ruby 3.4+ doesn't warn
end
