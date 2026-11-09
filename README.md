# locale_audit

Every Stripe product team ships US-first: English strings, `$1,234.56`, month-first dates. An internationalisation platform has to make locale correctness a property of the platform, not something each team remembers. With an LLM now doing the translating, the failures are quiet: a dropped `%{amount}`, a `€` typed straight into the string, a deadline paraphrased as "within 7 days". Nobody notices until a merchant does.

This gem audits a string catalogue the way an auditor reviews a working paper: a set of controls, each with an ID, an exception report naming every offending key, and an opinion.

| ID | Control |
|---|---|
| I18N-01 | Placeholder set preserved exactly |
| I18N-02 | No reordering that changes meaning |
| I18N-03 | Money only via a placeholder; no literal amount or currency |
| I18N-04 | Integer minor units in, exact round-trip out; no float in the path |
| I18N-05 | Dates and numbers come from the locale formatter |

Locales: en-US, es-ES, de-DE (`1.234,56 EUR`), ja-JP (zero-decimal yen).

```sh
bundle exec rspec
bundle exec exe/locale-audit fixtures/catalogue.yml fixtures/translations/defective.yml   # exits 1
ANTHROPIC_API_KEY=... bin/record-llm   # Claude translates; CI audits the recording offline
```
