# locale_audit

[![CI](https://github.com/OKMantis/locale-audit/actions/workflows/ci.yml/badge.svg)](https://github.com/OKMantis/locale-audit/actions/workflows/ci.yml)

**A deterministic gate that sits in front of an LLM translation quality estimator.** A quality estimator gives a probabilistic score for fluency and meaning. Some failures should never get as far as a score: a dropped `%{amount}`, a `€` typed straight into the string, a deadline paraphrased as "within 7 days". Those are structural, so they can be checked exactly, and a translation that fails one should fail the build before any model scores it.

Product teams ship US-first: English strings, `$1,234.56`, month-first dates. With an LLM doing the translating, these failures are quiet, and nobody notices until a merchant does. This gem audits a string catalogue the way an auditor reviews a working paper: a set of controls, each with an ID, an exception report naming every offending key, and an opinion.

| ID | Control |
|---|---|
| I18N-01 | Placeholder set preserved exactly |
| I18N-02 | No reordering that changes meaning |
| I18N-03 | Money only via a placeholder; no literal amount or currency |
| I18N-04 | Integer minor units in, exact round-trip out; no float in the path |
| I18N-05 | Dates and numbers come from the locale formatter, not the string |

## What a failing audit looks like

The run below uses `fixtures/translations/defective.yml`, a hand-written set with one known defect per line. The spec checks that every defect is caught and nothing else is flagged.

```
LOCALE-CORRECTNESS AUDIT
Candidate set: fixtures/translations/defective.yml (hand-written, seeded defects)
Population:    9 keys x 4 locales = 36 strings

I18N-01  Placeholder set preserved exactly                                    FAIL  7
I18N-02  No reordering that changes meaning                                   FAIL  2
I18N-03  Money only via a placeholder; no literal amount or currency          FAIL  3
I18N-04  Integer minor units in, exact round-trip out; no float in the path   PASS
I18N-05  Dates and numbers come from the locale formatter, not the string     FAIL  2

OPINION: ADVERSE. 14 exceptions across 4 of 5 controls in 8 keys. Build fails.

EXCEPTION REPORT
I18N-01  de-DE  payout.scheduled     %{date}: expected 1, found 0
I18N-01  es-ES  refund.partial       %{refund}: expected 1, found 0
I18N-01  es-ES  refund.partial       %{reembolso}: expected 0, found 1
I18N-01  es-ES  invoice.due          %{due_date}: expected 1, found 0
I18N-05  es-ES  invoice.due          literal date "04/01/2026"; dates render per locale from a Date argument
I18N-01  ja-JP  dispute.opened       %{respond_by}: expected 1, found 0
I18N-05  ja-JP  dispute.opened       literal number "7" not in source
I18N-01  de-DE  fee.applied          %{fee}: expected 1, found 0
I18N-02  de-DE  fee.applied          positional token %s rebinds silently if a translator reorders
I18N-03  de-DE  balance.available    literal currency "€"; currency comes from the money argument
I18N-01  ja-JP  subscription.renews  %{amount}: expected 1, found 0
I18N-03  ja-JP  subscription.renews  literal currency "￥"; currency comes from the money argument
I18N-03  ja-JP  subscription.renews  literal amount "4,980"; amounts render from minor units
I18N-02  es-ES  statement.period     order period_end, period_start reverses source order period_start, period_end
```

## What Claude produced

`bin/record-llm` asked `claude-opus-5-5` to translate the catalogue into es-ES, de-DE and ja-JP. Its output is committed unedited in `fixtures/translations/llm.yml`, and CI audits that file offline on every push.

```
LOCALE-CORRECTNESS AUDIT
Candidate set: fixtures/translations/llm.yml (claude-opus-5-5, recorded 2026-11-09, unedited)
Population:    9 keys x 4 locales = 36 strings

I18N-01  Placeholder set preserved exactly                                    PASS
I18N-02  No reordering that changes meaning                                   PASS
I18N-03  Money only via a placeholder; no literal amount or currency          PASS
I18N-04  Integer minor units in, exact round-trip out; no float in the path   PASS
I18N-05  Dates and numbers come from the locale formatter, not the string     PASS

OPINION: UNQUALIFIED. No exceptions across 5 controls.
```

A clean pass on one recording is not a guarantee. Change the prompt, the model or the catalogue and the next run can fail. The gate turns "the model usually gets this right" into a check that runs on every recording. The run also shows I18N-02 doing its job. In ja-JP, `refund.partial` puts `%{charge}` before `%{refund}` (元の請求額%{charge}のうち%{refund}), which Japanese grammar requires, and the control allows it because that key is not `order_locked`. On `transfer.converted`, where order is the meaning, any swap fails.

The gate does not judge fluency, tone or terminology. That is the quality estimator's job, and it only sees strings that passed here.

## Locale decisions

Locales: en-US, es-ES, de-DE, ja-JP. Number formats are hand-rolled from CLDR.

- **Amounts use the ISO code, not the symbol.** de-DE renders `1.234,56 EUR`, not `1.234,56 €`. This is deliberate. `$` means USD, CAD, AUD or MXN, and in a payout email the merchant has to know which one. The ISO code is never ambiguous.
- **es-ES groups thousands only from five digits.** CLDR's `minimumGroupingDigits` is 2 for Spanish, so it is `1234,56 EUR` but `12.345,67 EUR`. Applying de-DE's rule to es-ES is a common mistake.
- **Money is integer minor units plus a currency.** JPY has no minor unit and KWD has three. Every rendered amount is parsed back and must equal the input exactly.

## Run it

```sh
bundle exec rspec
bundle exec exe/locale-audit fixtures/catalogue.yml fixtures/translations/defective.yml   # exits 1
ANTHROPIC_API_KEY=... bin/record-llm   # Claude translates; CI audits the recording offline
```
