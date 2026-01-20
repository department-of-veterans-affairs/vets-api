# ADR-002: Extract Shared Validation Logic to ClaimBehavior Concern

## Status
Accepted

## Context
The DependentsBenefits module has three claim types that need shared functionality:
- `DependentsBenefits::SavedClaim`
- `AddRemoveDependent` 
- `SchoolAttendanceApproval`

These classes require common validation logic and utility methods for form processing, including:
- Custom JSON schema validation against VetsJsonSchema
- Form parsing utilities with camelCase conversion
- Error tracking and monitoring
- Submittability checks for 686/674 forms

## Problem
Initially, all classes inherited from `DependentsBenefits::SavedClaim` to share this functionality. However, `DependentsBenefits::SavedClaim` needs backwards compatibility with `SavedClaim::DependencyClaim` for encryption during migration.

The backwards compatibility implementation caused all three claim types to appear as `SavedClaim::DependencyClaim` in Rails console and other contexts, masking their true types and making debugging difficult.

Additionally, using inheritance for shared behavior conflicted with Rails' `self.abstract_class = true` pattern and created confusion about what constituted truly abstract class semantics versus shared functionality.

## Decision
Extract shared validation and utility methods into `DependentsBenefits::ClaimBehavior` concern:

```ruby
# Pattern:
class ClaimType < ::SavedClaim
  include DependentsBenefits::ClaimBehavior
end

# Applied to:
├── DependentsBenefits::SavedClaim (includes backwards compatibility)
├── AddRemoveDependent 
└── SchoolAttendanceApproval
```

This follows Rails conventions for shared behavior using concerns rather than inheritance hierarchies.

## Consequences

### Benefits
- **Rails idiomatic**: Uses established Rails pattern for sharing behavior across models
- **Flexible composition**: Classes can include multiple concerns as needed
- **Isolated backwards compatibility**: Only `DependentsBenefits::SavedClaim` carries legacy compatibility burden
- **Preserved type identity**: Each class maintains its proper type in Rails console and logs
- **Testable in isolation**: Concern can be unit tested independently
- **Clear intent**: Obviously shared behavior, not inheritance relationship
- **Future extensibility**: New concerns can be added without inheritance conflicts

### Drawbacks
- Developers must understand which functionality comes from concerns vs base class
- Slightly more verbose than direct inheritance

## Implementation Notes
- `ClaimBehavior` concern contains form validation, schema checking, and utility methods
- Backwards compatibility code remains isolated in `DependentsBenefits::SavedClaim`
- Each concrete class maintains distinct behavior and can be properly identified in debugging
- Follows existing VA.gov codebase patterns for shared model functionality

This pattern provides clean separation of concerns while maintaining shared functionality across all dependent benefit claim types without the complexity and confusion of inheritance hierarchies.