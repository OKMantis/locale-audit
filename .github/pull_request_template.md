## What and why

## Review checklist
- [ ] New strings use named `%{placeholders}`, never positional `%s` / `{0}`
- [ ] Money passes as integer minor units plus an ISO 4217 code; no floats, no pre-formatted amounts
- [ ] Dates pass as `Date`, never as pre-formatted strings
- [ ] New control has an ID, a one-line description, and a seeded defect in `fixtures/translations/defective.yml` that it catches
- [ ] `bundle exec rspec` is green; the exception report reads clearly to someone who didn't write the code
