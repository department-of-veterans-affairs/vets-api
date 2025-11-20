# CODEOWNERS Backend Review Group Directory Check

## Overview

This GitHub Action automatically checks when `backend-review-group` is being assigned to directories (rather than specific files) in the CODEOWNERS file. This helps prevent unintended automatic assignment of code reviews to the backend-review-group for new files created by other VFS teams.

## Problem Statement

Based on [PR #25237](https://github.com/department-of-veterans-affairs/vets-api/pull/25237), when `backend-review-group` is assigned to entire directories in CODEOWNERS, any new files created by other VFS teams within those directories are automatically assigned to the backend-review-group for review. This can:

- Overwhelm the backend-review-group with reviews for code they don't own
- Create confusion about code ownership
- Slow down the review process for teams that own the code

## How It Works

The action triggers on PRs that modify `.github/CODEOWNERS` and:

1. **Analyzes the diff** to find new assignments
2. **Identifies directory patterns** (paths without file extensions)
3. **Detects backend-review-group assignments** to those directories
4. **Reports violations** in the CI check and comments on the PR
5. **Provides recommendations** for better CODEOWNERS patterns

## What Gets Flagged

### ❌ Flagged (Directory Assignments)

```
app/models/claims_api @department-of-veterans-affairs/backend-review-group
lib/rx @department-of-veterans-affairs/mobile-api-team @department-of-veterans-affairs/backend-review-group
modules/appeals_api @department-of-veterans-affairs/lighthouse-banana-peels @department-of-veterans-affairs/backend-review-group
spec/models/saved_claim @department-of-veterans-affairs/backend-review-group
```

### ✅ Not Flagged (File-Specific Assignments)

```
app/models/claims_api/claim_submission.rb @department-of-veterans-affairs/backend-review-group
config/form_profile_mappings/22-1990.yml @department-of-veterans-affairs/backend-review-group
spec/controllers/v0/documents_controller_spec.rb @department-of-veterans-affairs/backend-review-group
```

## Recommended Patterns

### Pattern 1: Assign to Owning Team Only

```
# Remove backend-review-group from directory, let owning team manage it
app/models/claims_api @department-of-veterans-affairs/lighthouse-dash
modules/appeals_api @department-of-veterans-affairs/lighthouse-banana-peels
```

### Pattern 2: Specific Files with Backend Review

```
# Assign backend-review-group only to specific legacy files
app/models/claims_api @department-of-veterans-affairs/lighthouse-dash
app/models/claims_api/legacy_model.rb @department-of-veterans-affairs/backend-review-group
```

### Pattern 3: Primary + Secondary Reviewers

```
# Owning team is primary, backend-review-group is secondary
app/models/power_of_attorney.rb @department-of-veterans-affairs/bah-mbs-selfserv @department-of-veterans-affairs/backend-review-group
```

## CI Behavior

### When No Violations Found

```
✅ No directory assignments to backend-review-group detected
All changes appear to be for specific files only
```

The check passes and the PR can proceed.

### When Violations Found

```
❌ Found 3 directory assignment(s) to backend-review-group:
  - app/models/claims_api
  - lib/rx
  - modules/appeals_api

⚠️  WARNING: Assigning backend-review-group to directories causes
automatic assignment for ALL new files created by other VFS teams
in those directories.
```

The check fails and a comment is posted to the PR explaining the issue.

## Customization

### Adjust Directory Detection

If you need to customize what counts as a "directory" vs a "file", modify the directory detection logic in the workflow:

```bash
# Current logic checks for:
# 1. Paths ending with /
# 2. Paths without file extensions
# 3. Paths with slashes but no dots

is_directory=false

if [[ "$path" =~ /$ ]]; then
  is_directory=true
elif [[ ! "$path" =~ \\.[a-zA-Z0-9]+$ ]]; then
  is_directory=true
elif [[ "$path" =~ ^[^.]+$ ]] && [[ "$path" =~ / ]]; then
  is_directory=true
fi
```

### Make Check Non-Blocking (Warning Only)

To make this check warn but not fail the CI:

1. Change `exit 1` to `exit 0` in the check step
2. Or add `continue-on-error: true` to the step

```yaml
- name: Check for backend-review-group directory assignments
  continue-on-error: true  # Add this line
  if: steps.changed-files.outputs.any_changed == 'true'
  run: |
    # ... rest of the script
```

## Testing

To test the workflow locally before deploying:

```bash
# Install act (GitHub Actions local runner)
brew install act  # macOS
# or
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run the workflow
act pull_request -W .github/workflows/check-codeowners.yml
```

## Example PR Output

When violations are detected, the PR will receive a comment like:

---

## ⚠️ CODEOWNERS Directory Assignment Warning

This PR modifies the CODEOWNERS file and assigns `backend-review-group` to **3 directories**:

- `app/models/claims_api`
- `lib/rx`
- `modules/appeals_api`

### Why is this a concern?

When `backend-review-group` is assigned to directories (rather than specific files), **all new files created by other VFS teams** in those directories are automatically assigned to the backend-review-group for review.

### Recommendations:

1. **Assign to specific files** instead of directories
2. **Add the owning team first** with backend-review-group as secondary reviewer
3. **Use specific path patterns** to limit the scope

---

## Troubleshooting

### Action Not Running

- Verify the workflow file is in `.github/workflows/`
- Check that the workflow is enabled in repository settings
- Ensure PRs are modifying `.github/CODEOWNERS`

### False Positives

If legitimate directory assignments are flagged, you can:

1. Add specific file patterns instead
2. Modify the directory detection logic
3. Add exemptions to the script

### Permissions Issues

The workflow requires:
- `contents: read` - to checkout code
- `pull-requests: write` - to comment on PRs

These are granted by default in most repositories.

## Support

For issues or questions:
- Review the workflow logs in the Actions tab
- Check the PR that introduced this pattern: #25237
- Consult your team's CODEOWNERS documentation

## License

This workflow is provided as-is for use in the vets-api repository and related VA projects.