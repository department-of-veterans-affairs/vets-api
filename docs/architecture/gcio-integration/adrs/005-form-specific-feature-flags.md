# ADR-005: Form-Specific Feature Flags for Granular Rollout Control

## Context

The GCIO form intake integration will support multiple form types (21-526EZ, 21-0966, 21-4138, etc.). We need a safe rollout strategy that allows:

1. **Independent rollout** per form type
2. **Different rollout speeds** based on form complexity/volume
3. **Independent rollback** if a specific form has issues
4. **Surgical control** during production incidents
5. **Form-specific monitoring** and metrics

### Original Design

Single feature flag controlling all forms:

```ruby
# ❌ Single flag - all or nothing
def should_submit_to_gcio?
  ENABLED_FORMS.include?(form_id) &&
    Flipper.enabled?(:form_intake_integration, user_account)
end
```

**Problem**: Can't enable 21-526EZ at 50% while testing 21-0966 at 1%. All forms share the same flag.

## Decision

**Use form-specific feature flags** - one flag per form type for maximum control.

```ruby
# ✅ Form-specific flags
module FormIntake
  FORM_FEATURE_FLAGS = {
    '21-526EZ' => :form_intake_integration_526,
    '21-0966' => :form_intake_integration_0966,
    '21-4138' => :form_intake_integration_4138,
    '20-10207' => :form_intake_integration_10207
  }.freeze
  
  def self.enabled_for_form?(form_id, user_account = nil)
    flag = FORM_FEATURE_FLAGS[form_id]
    return false unless flag
    
    Flipper.enabled?(flag, user_account)
  end
end
```

## Alternatives Considered

### Alternative 1: Single Global Flag

**Approach**: One `form_intake_integration` flag for all forms.

**Rejected because**:
- Can't control rollout per form
- Can't disable one form independently
- All forms at same percentage
- Higher risk - issue affects all forms
- Harder to A/B test

### Alternative 2: Compound Flag Names

**Approach**: Check multiple flags: global + form-specific.

```ruby
Flipper.enabled?(:form_intake_integration) &&
  Flipper.enabled?("form_intake_#{form_id}".to_sym)
```

**Rejected because**:
- More complex logic
- Two flags to manage per form
- Confusing for operators
- Easy to misconfigure

### Alternative 3: Dynamic Flag Creation

**Approach**: Dynamically create flags as needed, no hardcoding.

**Rejected because**:
- Flags not visible in config
- Can't predefine in features.yml
- Harder to track which forms are supported
- Documentation unclear

### Alternative 4: Database Configuration

**Approach**: Store enabled forms in database table.

**Rejected because**:
- Flipper already provides this functionality
- Need to build UI for management
- Can't use Flipper's percentage rollout
- More code to maintain

## Consequences

### Positive

- **Surgical control**: Enable/disable individual forms
- **Independent rollout**: Different speeds per form
- **Risk isolation**: Problem with one form doesn't affect others
- **Better testing**: Can test forms independently in production
- **Clearer metrics**: Per-form success rates
- **Flexible**: Can have 526 at 100% while 0966 at 5%
- **Safer**: Lower blast radius for issues
- **Observable**: Clear which forms are enabled

### Negative

- **More flags**: 4+ flags instead of 1
- **More configuration**: Each flag needs definition in features.yml
- **More commands**: Multiple enable/disable commands
- **Documentation**: Need to explain per-form control

### Mitigations

- **Helper method**: `FormIntake.enabled_for_form?` simplifies checks
- **List helper**: `FormIntake.enabled_forms` shows active forms
- **Clear naming**: Flag names clearly map to form IDs
- **Documentation**: Rollout strategy guide provided

## Implementation Pattern

### Code Check

```ruby
# In Lighthouse job
def should_submit_to_gcio?
  return false unless @form_submission_attempt
  return false unless @claim.user_account
  
  FormIntake.enabled_for_form?(@claim.form_id, @claim.user_account)
end
```

### Adding New Form

```ruby
# 1. Add to eligible forms
ELIGIBLE_FORMS << '21-686C'

# 2. Add feature flag mapping
FORM_FEATURE_FLAGS['21-686C'] = :form_intake_integration_686

# 3. Add to features.yml
# form_intake_integration_686:
#   actor_type: user_account
#   description: Enable GCIO integration for form 21-686C

# 4. Deploy
# 5. Enable at 1%
Flipper.enable_percentage_of_actors(:form_intake_integration_686, 1)
```

### Production Rollout Example

```ruby
# Week 1: Test 526
Flipper.enable_percentage_of_actors(:form_intake_integration_526, 1)
# Monitor... looks good
Flipper.enable_percentage_of_actors(:form_intake_integration_526, 10)

# Week 2: Scale 526, add 0966
Flipper.enable_percentage_of_actors(:form_intake_integration_526, 50)
Flipper.enable_percentage_of_actors(:form_intake_integration_0966, 1)

# Week 3: 526 issue detected!
Flipper.disable(:form_intake_integration_526)  # Emergency disable
# 0966 keeps working at 1%

# Week 4: Fix deployed, re-enable 526
Flipper.enable_percentage_of_actors(:form_intake_integration_526, 10)
# Gradually increase again

# Week 5: Both forms stable
Flipper.enable(:form_intake_integration_526)   # 100%
Flipper.enable(:form_intake_integration_0966)  # 100%

# Week 6: Add third form
Flipper.enable_percentage_of_actors(:form_intake_integration_4138, 1)
```

## Monitoring Strategy

### Per-Form Metrics

```ruby
# Success rate by form (last 24h)
FormIntake::FORM_FEATURE_FLAGS.keys.each do |form_id|
  submissions = FormIntakeSubmission.joins(:form_submission)
    .where('form_submissions.form_type': form_id)
    .where('form_intake_submissions.created_at > ?', 24.hours.ago)
  
  total = submissions.count
  success = submissions.success.count
  rate = total.positive? ? (success.to_f / total * 100).round(2) : 0
  
  puts "#{form_id}: #{rate}% (#{success}/#{total})"
end
```

### Alert Thresholds

Per-form alerts allow different thresholds:

| Form | Traffic | Success Threshold | Alert Level |
|------|---------|-------------------|-------------|
| 21-526EZ | High | >95% | Critical |
| 21-0966 | Medium | >90% | Warning |
| 21-4138 | Low | >85% | Info |

## Advantages in Production

### Real-World Scenario

**Situation**: 21-526EZ has complex GCIO mapping, prone to errors. 21-0966 is simple, very reliable.

**With form-specific flags**:
```ruby
# Keep 0966 at 100% (it's reliable)
Flipper.enable(:form_intake_integration_0966)

# Keep 526 at 10% (still working on stability)
Flipper.enable_percentage_of_actors(:form_intake_integration_526, 10)
```

**Without form-specific flags**:
- Can't have different percentages
- Must choose: both at 10% or both at 100%
- 0966 unnecessarily limited by 526's issues

## Testing Strategy

### Staging Environment

```ruby
# Enable all forms in staging
FormIntake::FORM_FEATURE_FLAGS.values.each { |flag| Flipper.enable(flag) }

# Test each form independently
test_forms = ['21-526EZ', '21-0966', '21-4138']
test_forms.each do |form_id|
  # Submit test form
  # Verify GCIO receives data
  # Check IBM can query it
end
```

### Production Testing

```ruby
# Enable for test users only
test_users = UserAccount.where(icn: TEST_ICNS)
test_users.each do |user|
  Flipper.enable_actor(:form_intake_integration_526, user)
end

# Real submissions, real GCIO calls, but limited blast radius
```

## Success Metrics

- ✅ Can enable forms independently
- ✅ Can rollback one form without affecting others
- ✅ Each form can have different rollout percentage
- ✅ Clear monitoring per form type
- ✅ Easy to see which forms are active
- ✅ Lower risk during rollout

---

**This pattern is used elsewhere in vets-api**: See `medical_expense_reports_govcio_mms`, `burial_submitted_email_notification` - form/module specific flags are standard practice.

