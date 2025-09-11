# TEST 2: Add Column - Migration Only
## Expected: ✅ PASS (No warnings)

This test validates that migrations without any app code changes pass without issues.

## Files to commit:
1. `db/migrate/20250111120002_add_retry_count_to_form_submission_attempts.rb`
2. `db/schema.rb` (auto-generated change)

## How to test:
```bash
git checkout -b test-migration-add-column
git add db/migrate/20250111120002_add_retry_count_to_form_submission_attempts.rb
git commit -m "Add retry_count to form_submission_attempts"
git push origin test-migration-add-column
```

Create PR and verify Danger passes without warnings