# TEST 3: Rename Column with Model Updates
## Expected: ⚠️ WARNING (Allowed)

This test validates that column renames with appropriate model changes are allowed.

## Files to commit together:
1. `db/migrate/20250111120003_rename_user_uuid_to_user_account_uuid.rb`
2. `app/models/saved_claim_test.rb` (with alias_attribute)
3. `spec/models/saved_claim_spec.rb` (updated tests)

## How to test:
```bash
git checkout -b test-migration-rename-column
git add db/migrate/20250111120003_rename_user_uuid_to_user_account_uuid.rb
git add app/models/saved_claim_test.rb
git add spec/models/saved_claim_spec.rb
git commit -m "Rename user_uuid to user_account_uuid"
git push origin test-migration-rename-column
```

Create PR and verify Danger shows WARNING (not error)