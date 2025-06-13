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
- [ ] Update `V0::FeatureTogglesController` to use the new service
- [ ] Remove private methods moved to the service
- [ ] Maintain existing interface and response format

### 3. Create Mobile Controller
- [ ] Create `app/controllers/mobile/feature_toggles_controller.rb`
- [ ] Use `FeatureTogglesService` for all logic
- [ ] Set appropriate `service_tag` and authentication handling
- [ ] Ensure response format matches web endpoint

### 4. Update Routes
- [ ] Add route for `/mobile/feature_toggles` in `config/routes.rb`
- [ ] Follow existing mobile namespace patterns

### 5. Write Tests
- [ ] Add service specs: `spec/services/feature_toggles_service_spec.rb`
- [ ] Add controller specs: `spec/controllers/mobile/feature_toggles_controller_spec.rb`
- [ ] Test both authenticated and unauthenticated scenarios
- [ ] Test specific and all feature queries

### 6. Update Documentation
- [ ] Add API documentation for the new endpoint
- [ ] Include usage examples and parameter details

### 7. Manual Testing & Verification
- [ ] Verify both endpoints return identical results
- [ ] Test edge cases and error handling

### 8. Code Quality & Security
- [ ] Run RuboCop and ensure code style compliance
- [ ] Check for PII/sensitive data logging
- [ ] Review for security and performance

### 9. Code Review Preparation
- [ ] Run full test suite
- [ ] Prepare summary of changes for reviewers
- [ ] Document any configuration changes

## Acceptance Criteria
- [ ] Both endpoints return identical results for the same inputs
- [ ] Shared logic is encapsulated in the service
- [ ] All tests pass
- [ ] No business logic duplication between controllers
- [ ] Code follows repository standards
