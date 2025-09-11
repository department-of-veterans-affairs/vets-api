# TEST 1: Remove Column with ignored_columns
## Expected: ⚠️ WARNING (Allowed)

This test validates that the MigrationIsolator allows model changes when removing columns,
following Strong Migrations best practices.

## Files to commit together:
1. `db/migrate/20250111120001_remove_deprecated_fields_from_form_submissions.rb`
2. `app/models/form_submission.rb` (add ignored_columns)
3. `spec/models/form_submission_spec.rb` (remove tests for deprecated fields)
4. `spec/factories/form_submissions.rb` (remove deprecated attributes)

## How to test:
```bash
git checkout -b test-migration-remove-column
git add db/migrate/20250111120001_remove_deprecated_fields_from_form_submissions.rb
git add app/models/form_submission.rb
git add spec/models/form_submission_spec.rb
git add spec/factories/form_submissions.rb
git commit -m "Remove deprecated fields from form_submissions"
git push origin test-migration-remove-column
```

Create PR and verify Danger shows WARNING (not error)