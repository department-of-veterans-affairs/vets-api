# Testing MigrationIsolator Dangerfile Changes

This directory contains test files to validate the improved MigrationIsolator behavior.

## Test Files Created

### Migrations
- `db/migrate/20250111120001_remove_deprecated_fields_from_form_submissions.rb` - Remove columns
- `db/migrate/20250111120002_add_retry_count_to_form_submission_attempts.rb` - Add column
- `db/migrate/20250111120003_rename_user_uuid_to_user_account_uuid.rb` - Rename column
- `db/migrate/20250111120004_add_processing_status_to_claims.rb` - Add multiple columns

### Model Files (Allowed with migrations)
- `app/models/form_submission_test.rb` - Model with ignored_columns (TEST 1)
- `app/models/saved_claim_test.rb` - Model with alias_attribute (TEST 3)

### Controller/Service Files (NOT allowed with migrations)
- `app/controllers/v0/claims_controller_test.rb` - Controller changes (TEST 4)
- `app/services/claims/status_updater_test.rb` - Service changes (TEST 4)

## How to Test Each Scenario

### TEST 1: Remove Column with Model Changes (Should WARN)
```bash
git checkout -b test-remove-column-warn
git add db/migrate/20250111120001_remove_deprecated_fields_from_form_submissions.rb
git add app/models/form_submission_test.rb
git commit -m "Test: Remove columns with ignored_columns"
git push origin test-remove-column-warn
```
**Expected**: ⚠️ WARNING message but allows merge

### TEST 2: Add Column Only (Should PASS)
```bash
git checkout -b test-add-column-pass
git add db/migrate/20250111120002_add_retry_count_to_form_submission_attempts.rb
git commit -m "Test: Add column migration only"
git push origin test-add-column-pass
```
**Expected**: ✅ PASS with no warnings

### TEST 3: Rename Column with Model (Should WARN)
```bash
git checkout -b test-rename-column-warn
git add db/migrate/20250111120003_rename_user_uuid_to_user_account_uuid.rb
git add app/models/saved_claim_test.rb
git commit -m "Test: Rename column with alias_attribute"
git push origin test-rename-column-warn
```
**Expected**: ⚠️ WARNING message but allows merge

### TEST 4: Migration with Business Logic (Should ERROR)
```bash
git checkout -b test-controller-error
git add db/migrate/20250111120004_add_processing_status_to_claims.rb
git add app/controllers/v0/claims_controller_test.rb
git add app/services/claims/status_updater_test.rb
git commit -m "Test: Migration with controller/service changes"
git push origin test-controller-error
```
**Expected**: ❌ ERROR message and blocks merge

## Expected Danger Outputs

### WARNING Output (Tests 1 & 3):
```
⚠️ This PR contains both migration and application code changes.

The following files were modified alongside migrations:
- app/models/form_submission_test.rb

These changes appear to follow Strong Migrations patterns for safe deployments...
```

### ERROR Output (Test 4):
```
❌ This PR contains migrations with disallowed application code changes.

Disallowed App File(s):
- app/controllers/v0/claims_controller_test.rb
- app/services/claims/status_updater_test.rb

Not allowed:
- Controller changes
- Service object changes
- Background job changes
```

## Clean Up After Testing

After testing, remove the test files:
```bash
git checkout master
rm db/migrate/20250111120*.rb
rm app/models/*_test.rb
rm app/controllers/v0/claims_controller_test.rb
rm app/services/claims/status_updater_test.rb
rm -rf test_dangerfile_migrations/
```

## Important Notes

1. **DO NOT MERGE** any of the test files ending in `_test.rb`
2. These files are for testing the Dangerfile behavior only
3. After validating the Dangerfile works correctly, delete all test files
4. The actual PR with the Dangerfile changes should only contain the Dangerfile modification