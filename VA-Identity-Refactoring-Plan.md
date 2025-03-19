# VA.gov Identity Refactoring Plan: Removing User UUID Identity Provider Assumptions

## Overview
This document outlines the refactoring work needed to remove the assumption that `user_uuid` is always equivalent to `idme_uuid` throughout the VA.gov API codebase. This change is critical to support delegate users with separate credentials and to improve the flexibility of the identity management system to work with multiple identity providers.

Each section below outlines a specific component that requires refactoring, detailing:
- **Why**: The reason this component needs refactoring
- **Where**: The specific files that need changes  
- **How**: A high-level approach for implementing the necessary changes

## Core Identity Components

### 1. User Model
**Why**: The User Model has high-impact logic that explicitly checks for `idme_uuid` and `backing_idme_uuid` when working with UserVerification, making direct assumptions about ID.me being the identity provider.

**Where**:
- `vets-api/app/models/user.rb`

**How**:
- Refactor the delegation to UserVerification to use `user_account_uuid` instead of `idme_uuid`
- Modify the lookup logic to prioritize `user_account_uuid` over provider-specific UUIDs
- Update any methods that directly reference `idme_uuid` to use a more generic approach

### 2. User Identity
**Why**: This component explicitly uses `idme_uuid` and `logingov_uuid` to create and look up UserIdentity objects, creating a direct dependency on specific identity providers.

**Where**:
- `vets-api/app/services/sign_in/user_loader.rb`
- `vets-api/lib/saml/user_attributes/base.rb`

**How**:
- Refactor to use `user_account_uuid` as the primary identifier
- Modify creation and lookup methods to work with any identity provider
- Update references to specific provider UUIDs to use a provider-agnostic approach

### 3. SignIn AttributeValidator
**Why**: The validator explicitly checks for presence of `logingov_uuid`, `idme_uuid`, `mhv_uuid`, `dslogon_uuid`, making assumptions about which providers are valid.

**Where**:
- `vets-api/app/services/sign_in/attribute_validator.rb`

**How**:
- Refactor to validate the presence of any valid user identifier
- Implement a provider-agnostic validation approach
- Add support for validating delegate user scenarios

### 4. SignIn CredentialLevelCreator
**Why**: The component checks for `idme_uuid`/`logingov_uuid` for `auto_uplevel` purposes, assuming specific provider behavior.

**Where**:
- `vets-api/app/services/sign_in/credential_level_creator.rb`

**How**:
- Refactor `auto_uplevel` logic to work with `user_account_uuid`
- Remove direct dependencies on specific provider UUIDs
- Ensure logic works correctly regardless of the identity provider used

### 5. User Verification
**Why**: This is a critical component that explicitly requires and uses provider-specific UUIDs across multiple files and modules.

**Where**:
- `vets-api/rakelib/prod/backfill_user_account_id_for_in_progress_forms.rake`
- `vets-api/modules/debts_api/app/models/debts_api/v0/form5655_submission.rb`
- `vets-api/app/services/sign_in/user_code_map_creator.rb`
- `vets-api/app/services/sign_in/session_spawner.rb`
- `vets-api/app/models/user_verification.rb`
- `vets-api/app/models/form526_submission.rb`

**How**:
- Add `user_account_uuid` field to UserVerification model
- Update lookups to prioritize `user_account_uuid`
- Refactor code that depends on provider-specific UUIDs
- Ensure backward compatibility during the transition period

### 6. User Verifier
**Why**: The verifier explicitly deals with different identity provider UUIDs, making assumptions about identity verification methods.

**Where**:
- `vets-api/app/services/login/user_verifier.rb`

**How**:
- Refactor to use a provider-agnostic approach to user verification
- Modify logic to support delegate users
- Update checks for provider-specific UUIDs to use `user_account_uuid` when available

### 7. SAML UserAttributes SSOe
**Why**: This component explicitly assumes and enforces that `user_uuid` should be derived from identity provider UUIDs, raising errors if no `idme_uuid`/`logingov_uuid` is present.

**Where**:
- `vets-api/lib/saml/user_attributes/ssoe.rb`

**How**:
- Remove the requirement for specific provider UUIDs
- Update the logic for setting the user's uuid
- Implement support for delegate users
- Ensure backward compatibility with existing authentication flows

### 8. Account
**Why**: The Account model explicitly relies on provider-specific UUIDs like `idme_uuid`, `logingov_uuid`, or `sec_id`.

**Where**:
- `vets-api/app/models/account.rb`

**How**:
- Add `user_account_uuid` field
- Update lookup logic to prioritize `user_account_uuid`
- Refactor code that relies on specific provider UUIDs
- Consider whether to continue refactoring or prioritize deprecation (if still marked for deprecation)

### 9. User Session Form
**Why**: The form runs MPI updating logic to set `idme_uuid` and attempts to pull `idme_uuid` in case of errors, assuming ID.me as the identity provider.

**Where**:
- `vets-api/app/models/user_session_form.rb`

**How**:
- Refactor MPI updating logic to work with `user_account_uuid`
- Update error handling to be provider-agnostic
- Ensure compatibility with delegate users

### 10. User Acceptable Verified Credential Updator
**Why**: This component depends on `idme_uuid` or `logingov_uuid` and likely contains logic that differentiates between identity providers.

**Where**:
- `vets-api/app/services/login/user_acceptable_verified_credential_updater.rb`
- `vets-api/app/services/login/user_acceptable_verified_credential_updater_logger.rb`

**How**:
- Refactor to use `user_account_uuid` instead of provider-specific UUIDs
- Update logic to work correctly with any identity provider
- Ensure proper logging for all credential update scenarios

## Class, Form, and Job Submissions

### 11. AccountCreator
**Why**: The AccountCreator component checks for `sec_id`/`idme_uuid`/`logingov_uuid`, making assumptions about identity sources.

**Where**:
Files not specified in the input, but likely in the identity module

**How**:
- Add support for `user_account_uuid` field for delegate users
- Update account creation logic to work with separate credentials
- Ensure backward compatibility with existing accounts

### 12. DebtsAPI
**Why**: The DebtsAPI uses `user_uuid` to look up UserAccount and has InProgressForms dependency.

**Where**:
Files not explicitly listed, but likely in the debts_api module

**How**:
- Update user lookups to use `user_account_uuid`
- Refactor any assumptions about `user_uuid` being from a specific provider
- Ensure proper handling of delegate user scenarios

### 13. MHVLoggingService
**Why**: Uses `current_user.uuid` directly in Sidekiq jobs for user lookups, incorrectly assuming this equals the identity provider UUID.

**Where**:
- `app/services/mhv_logging_service.rb`
- `app/sidekiq/mhv/audit_login_job.rb`
- `app/sidekiq/mhv/audit_logout_job.rb`

**How**:
- Refactor to use appropriate user identifiers in Sidekiq jobs
- Update user lookup logic to properly handle delegate users
- Ensure accurate auditing for MHV login/logout events regardless of the user type

### 14. AppealSubmissions
**Why**: Creates AppealSubmission with `user_uuid`, which needs update to support delegate users.

**Where**:
- `app/models/appeal_submission.rb`
- `app/controllers/v1/supplemental_claims_controller.rb`
- `app/controllers/v1/higher_level_reviews_controller.rb`

**How**:
- Update AppealSubmission creation to work with delegate users
- Refactor controllers to properly handle user identifiers
- Ensure proper association between submissions and user accounts

### 15. Supplemental Claims
**Why**: Related to AppealSubmissions, creates submissions with `user_uuid` assumptions.

**Where**:
Controller likely in `app/controllers/v1/supplemental_claims_controller.rb`

**How**:
- Coordinate with AppealSubmissions refactoring
- Update user identifier usage to support delegate users
- Ensure proper submission attribution regardless of user type

### 16. InProgressForm
**Why**: Uses `user_uuid` to save and query forms, with obsolete ID.me uuid validation to be removed.

**Where**:
Files not explicitly listed, but likely in the forms module

**How**:
- Update form saving/querying to use `user_account_uuid`
- Remove obsolete ID.me uuid validation
- Ensure forms can be accessed by appropriate users regardless of identity provider

### 17. Form526
**Why**: Uses `user.uuid` to look up UserVerifications & Account records.

**Where**:
Files not explicitly listed, but likely related to Form526 submissions

**How**:
- Refactor lookups to use `user_account_uuid`
- Update user verification logic to work with delegate users
- Ensure proper form submission regardless of user type

### 18. EVSSClaim
**Why**: Creates EVSS classes with `user_uuid` across multiple files, which requires moderate refactoring for delegate support.

**Where**:
- `app/models/evss_claim.rb`
- `app/services/evss_claim_service.rb`
- `app/services/evss_claim_service_async.rb`
- `app/controllers/v0/benefits_claims_controller.rb`
- `app/sidekiq/evss/document_upload.rb`
- `app/sidekiq/evss/retrieve_claims_from_remote_job.rb`
- `app/sidekiq/evss/update_claim_from_remote_job.rb`
- `app/sidekiq/evss/disability_compensation_form/submit_form526_cleanup.rb`

**How**:
- Update EVSS class creation to use appropriate user identifiers
- Refactor services and controllers to handle delegate users
- Ensure Sidekiq jobs correctly process user identifiers
- Maintain backward compatibility with existing claims

## Implementation Approach

For all refactoring work, consider the following general guidelines:

- **Database Migrations**: Add new fields to models before changing code to ensure backward compatibility
- **Dual Support Period**: Implement code that supports both old and new patterns during the transition
- **Testing**: Add comprehensive tests for all refactored components, especially focusing on delegate user scenarios
- **Documentation**: Update documentation to reflect the new architecture and identity management approach
- **Rollout Strategy**: Plan for gradual rollout to minimize user impact, with appropriate feature flags
- **Monitoring**: Add monitoring to detect any issues with the refactored components

## Prioritization

Components are prioritized based on their impact and dependency relationships:

### High Priority:
- User Model (core component with high impact)
- SAML UserAttributes SSOe (high impact, core of authentication flow)
- User Verification (high impact, used across multiple components)
- User Verifier (high impact, critical for authentication)

### Medium Priority:
- User Identity (moderate impact, but fundamental to user management)
- SignIn AttributeValidator (moderate impact, affects authentication flow)
- InProgressForm (actively being worked on)
- DebtsAPI (actively being worked on)

### Lower Priority:
- SignIn CredentialLevelCreator (low impact)
- Account (if still slated for deprecation)
- Components with fewer dependencies

This document serves as a guide for the refactoring effort and should be updated as implementation progresses and new insights are gained.