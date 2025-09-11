# TEST 4: Migration with Controller/Service Changes
## Expected: ❌ ERROR (Blocked)

This test validates that business logic changes are NOT allowed with migrations.

## Files to commit together (THIS SHOULD FAIL):
1. `db/migrate/20250111120004_add_processing_status_to_claims.rb`
2. `app/controllers/v0/claims_controller_test.rb` (new business logic)
3. `app/services/claims/status_updater_test.rb` (new service)

## How to test:
```bash
git checkout -b test-migration-should-fail
git add db/migrate/20250111120004_add_processing_status_to_claims.rb
git add app/controllers/v0/claims_controller_test.rb
git add app/services/claims/status_updater_test.rb
git commit -m "Add processing status to claims with controller changes"
git push origin test-migration-should-fail
```

Create PR and verify Danger shows ERROR and blocks merge