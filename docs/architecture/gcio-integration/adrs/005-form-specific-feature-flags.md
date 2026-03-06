# ADR-005: Use Form-Specific Feature Flags for Granular Rollout

## Context

GCIO integration affects multiple form types (21-526EZ, 21-0966, 21P-601, etc.). We need to:
- Roll out incrementally (one form at a time)
- Enable for specific users (canary testing)
- Disable quickly if issues arise
- Control independently per form type

## Decision

**Use individual Flipper feature flags per form type** with `actor_type: user`.

```yaml
# config/features.yml
form_intake_integration_526:
  actor_type: user
  description: Enable GCIO integration for 21-526EZ

form_intake_integration_0966:
  actor_type: user
  description: Enable GCIO integration for 21-0966

form_intake_integration_601:
  actor_type: user
  description: Enable GCIO integration for 21P-601
```

**Configuration**:
```ruby
# config/initializers/form_intake_integration.rb
FORM_FEATURE_FLAGS = {
  '21-526EZ' => :form_intake_integration_526,
  '21-0966' => :form_intake_integration_0966,
  '21P-601' => :form_intake_integration_601
}.freeze

def self.enabled_for_form?(form_id, user_account = nil)
  flag = FORM_FEATURE_FLAGS[form_id]
  return false unless flag
  
  Flipper.enabled?(flag, user_account)
end
```

## Alternatives Considered

**Single global flag**: Rejected - All forms on/off together, too risky  
**Percentage-based only**: Rejected - Can't target specific forms  
**Environment variables**: Rejected - Requires deployment to change  

## Consequences

**Positive**:
- Independent rollout per form
- Actor-based targeting (specific users)
- Percentage-based rollout support
- Quick disable without deployment
- Fine-grained control

**Negative**:
- More flags to manage
- Must add flag for each new form

**Mitigation**: Clear naming convention, documentation of which forms have flags
