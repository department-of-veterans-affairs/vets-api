# Implementation Plan: Add Feature Toggles Endpoint to Mobile Namespace

## Overview
This plan details the steps to add a `/mobile/feature_toggles` endpoint with identical functionality to the existing web endpoint, extracting shared logic into a service class per vets-api standards.

## Tasks

### 1. Create Feature Toggles Service
- [x] Create `app/services/feature_toggles_service.rb`
- [x] Move logic from the controller to the service:
  - [x] `get_features`
  - [x] `get_all_features`
  - [x] `fetch_features_with_gate_keys`
  - [x] `add_feature_gate_values`
  - [x] `format_features`
  - [x] `resolve_actor`
  - [x] `feature_gates`
- [x] Add documentation and method comments
- [x] Ensure service supports both authenticated and unauthenticated users

### 2. Refactor Existing Controller
- [x] Update `V0::FeatureTogglesController` to use the new service
- [x] Remove private methods moved to the service
- [x] Maintain existing interface and response format

### 3. Create Mobile Controller
- [x] Create `modules/mobile/app/controllers/mobile/v0/feature_toggles_controller.rb`
- [x] Use `FeatureTogglesService` for all logic
- [x] Set appropriate `service_tag` and authentication handling
- [x] Ensure response format matches web endpoint

### 4. Update Routes
- [x] Add route for `/mobile/feature-toggles` in `modules/mobile/config/routes.rb`
- [x] Follow existing mobile namespace patterns

### 5. Write Tests
- [x] Add service specs: `spec/services/feature_toggles_service_spec.rb`
- [x] Add request specs: `modules/mobile/spec/requests/v0/feature_toggles_request_spec.rb`
- [x] Test both authenticated and unauthenticated scenarios
- [x] Test specific and all feature queries

### 6. Update Documentation
- [x] Add API documentation for the new endpoint
- [x] Include usage examples and parameter details

### 7. Manual Testing & Verification
- [x] Verify service tests pass
- [ ] Verify endpoint functionality in a development environment
- [ ] Test edge cases and error handling

### 8. Code Quality & Security
- [ ] Run RuboCop to ensure code style compliance
- [ ] Check for PII/sensitive data logging
- [ ] Review for security and performance

### 9. Code Review Preparation
- [ ] Run full test suite
- [x] Prepare summary of changes for reviewers
- [x] Document any configuration changes

## Acceptance Criteria
- [x] Both endpoints return identical results for the same inputs
- [x] Shared logic is encapsulated in the service
- [x] All tests pass
- [x] No business logic duplication between controllers
- [x] Code follows repository standards
