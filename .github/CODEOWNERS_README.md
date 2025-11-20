# CODEOWNERS README

## Overview

When `backend-review-group` is assigned to directories (rather than specific files), **all new files created by other VFS teams** in those directories are automatically assigned to the backend-review-group for review. Assigning the correct files and directories helps prevent unintended automatic assignment of code reviews to the backend-review-group for new files created by other VFS teams.


## Problem Statement

Based on [PR #25237](https://github.com/department-of-veterans-affairs/vets-api/pull/25237), when `backend-review-group` is assigned to entire directories in CODEOWNERS, any new files created by other VFS teams within those directories are automatically assigned to the backend-review-group for review. This can:

- Overwhelm the backend-review-group with reviews for code they don't own
- Create confusion about code ownership
- Slow down the review process for teams that own the code

## How It Works

The Codeowner Check triggers on PRs that modify `.github/CODEOWNERS` and:

1. **Analyzes the diff** to find new assignments
2. **Identifies directory patterns** (paths without file extensions)

### ❌ Incorrect Ownership

```
app/models/claims_api @department-of-veterans-affairs/backend-review-group
lib/rx @department-of-veterans-affairs/mobile-api-team @department-of-veterans-affairs/backend-review-group
modules/appeals_api @department-of-veterans-affairs/lighthouse-banana-peels @department-of-veterans-affairs/backend-review-group
spec/models/saved_claim @department-of-veterans-affairs/backend-review-group
```

## Recommended Patterns

### Pattern 1: Assign to Owning Team Only (Exempt teams only)

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

### Recommendations:

1. **Assign to specific files** instead of directories
2. **Add the owning team first** with backend-review-group as secondary reviewer
3. **Use specific path patterns** to limit the scope

---

## Support

For issues or questions:
- Review the workflow logs in the Actions tab
- Check the PR that introduced this pattern: #25237
- Consult your team's CODEOWNERS documentation

## License

This workflow is provided as-is for use in the vets-api repository and related VA projects.