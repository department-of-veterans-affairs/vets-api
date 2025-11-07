# ADR 0001: Move Claim Generators from Models to Lib Directory

## Status
Accepted

## Date
2025-09-12

## Context
Claim generators (`Claim674Generator` and `Claim686cGenerator`) were in `models/` but are service objects, not ActiveRecord models. They handle business logic and external service integration rather than data persistence.

## Decision
Move generators from `models/dependents_benefits/generators/` to `lib/dependents_benefits/generators/` to follow Rails conventions for service objects.

## Consequences
- **Positive**: Better separation of concerns, follows Rails conventions, improves maintainability
- **Negative**: Requires updating require statements in controllers and tests

## Implementation
- Move files to `lib/dependents_benefits/generators/`
- Update require statements to use new paths
- Update any dependent test files