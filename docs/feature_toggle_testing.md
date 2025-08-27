# Feature Toggle Test Coverage

This guide explains how to properly test feature toggles in the vets-api codebase.

## Overview

Every feature toggle must be tested in both enabled and disabled states to ensure:
- The feature works correctly when enabled
- The application behaves properly when the feature is disabled
- No unexpected errors occur in either state

## Automated Validation

The repository has automated checks to ensure feature toggle test coverage:

1. **Danger Bot**: Comments on PRs when new feature toggles lack proper test coverage
2. **GitHub Actions**: Runs on PR creation/updates to validate coverage
3. **Rake Tasks**: Available for local testing and CI/CD validation

## How to Test Feature Toggles

### Method 1: Using Flipper Stubs (Recommended)

This is the recommended approach per the repository guidelines:

```ruby
describe 'MyController' do
  context 'with my_feature toggle' do
    context 'when enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:my_feature).and_return(true)
      end

      it 'enables the new behavior' do
        # Test the enabled behavior
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:my_feature).and_return(false)
      end

      it 'uses the legacy behavior' do
        # Test the disabled behavior
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
```

### Method 2: Using Shared Examples

For common patterns, use the provided shared examples:

```ruby
describe 'MyController' do
  include_examples 'feature toggle behavior', :my_feature do
    let(:enabled_behavior) { 'enables new functionality' }
    let(:disabled_behavior) { 'maintains legacy functionality' }
  end
end
```

### Method 3: Using Helper Methods

The coverage helper provides a convenient method:

```ruby
describe 'MyController' do
  it 'works with feature enabled' do
    allow_flipper_enabled(:my_feature, enabled: true)
    # Test enabled behavior
  end

  it 'works with feature disabled' do
    allow_flipper_enabled(:my_feature, enabled: false)
    # Test disabled behavior
  end
end
```

## Validation Commands

### Check Coverage for Current Changes
```bash
bundle exec rake feature_toggles:validate_coverage
```

### Generate Full Coverage Report
```bash
bundle exec rake feature_toggles:list_coverage
```

### Test the Danger Check Locally
```bash
bundle exec danger local
```

## Common Patterns

### Controller Actions
```ruby
describe 'GET #index' do
  context 'with enhanced_search feature' do
    context 'when enabled' do
      before { allow(Flipper).to receive(:enabled?).with(:enhanced_search).and_return(true) }
      
      it 'uses the new search algorithm' do
        get :index
        expect(assigns(:results)).to be_enhanced
      end
    end

    context 'when disabled' do
      before { allow(Flipper).to receive(:enabled?).with(:enhanced_search).and_return(false) }
      
      it 'uses the legacy search algorithm' do
        get :index
        expect(assigns(:results)).to be_legacy
      end
    end
  end
end
```

### Background Jobs
```ruby
describe 'MyJob' do
  context 'with async_processing feature' do
    context 'when enabled' do
      before { allow(Flipper).to receive(:enabled?).with(:async_processing).and_return(true) }
      
      it 'processes asynchronously' do
        expect { MyJob.perform_async }.to change(MyJob.jobs, :size).by(1)
      end
    end

    context 'when disabled' do
      before { allow(Flipper).to receive(:enabled?).with(:async_processing).and_return(false) }
      
      it 'processes synchronously' do
        expect { MyJob.perform_async }.not_to change(MyJob.jobs, :size)
      end
    end
  end
end
```

### Service Objects
```ruby
describe 'MyService' do
  context 'with new_algorithm feature' do
    let(:service) { described_class.new(params) }

    context 'when enabled' do
      before { allow(Flipper).to receive(:enabled?).with(:new_algorithm).and_return(true) }
      
      it 'returns enhanced results' do
        result = service.call
        expect(result.enhanced?).to be true
      end
    end

    context 'when disabled' do
      before { allow(Flipper).to receive(:enabled?).with(:new_algorithm).and_return(false) }
      
      it 'returns standard results' do
        result = service.call
        expect(result.enhanced?).to be false
      end
    end
  end
end
```

## Important Guidelines

### ❌ Avoid Global State Changes
**Don't use these patterns:**
```ruby
# These modify global state and can affect other tests
Flipper.enable(:my_feature)
Flipper.disable(:my_feature)
```

### ✅ Use Stubs Instead
**Use these patterns:**
```ruby
# These are isolated to the specific test
allow(Flipper).to receive(:enabled?).with(:my_feature).and_return(true)
allow(Flipper).to receive(:enabled?).with(:my_feature).and_return(false)
```

### Actor Types
When testing features with specific actor types, include the actor:

```ruby
# For user-based features
allow(Flipper).to receive(:enabled?).with(:my_feature, user).and_return(true)

# For cookie-based features  
allow(Flipper).to receive(:enabled?).with(:my_feature, cookie_id).and_return(true)
```

## Troubleshooting

### "Missing test coverage" Error
If you get this error, ensure you have tests for both states:
1. One test with `and_return(true)` 
2. One test with `and_return(false)`

### False Positives
The detection looks for specific patterns. Ensure your stubs match these formats:
- `allow(Flipper).to receive(:enabled?).with(:feature_name).and_return(true/false)`
- Feature name as symbol (`:feature_name`) or string (`'feature_name'`)

### Complex Feature Logic
For features with complex logic, test edge cases in both states:

```ruby
context 'with complex_feature' do
  context 'when enabled' do
    before { allow(Flipper).to receive(:enabled?).with(:complex_feature).and_return(true) }
    
    it 'handles success case' do
      # Test success path
    end
    
    it 'handles error case' do
      # Test error path with feature enabled
    end
  end

  context 'when disabled' do
    before { allow(Flipper).to receive(:enabled?).with(:complex_feature).and_return(false) }
    
    it 'handles success case' do
      # Test success path
    end
    
    it 'handles error case' do
      # Test error path with feature disabled
    end
  end
end
```

## CI/CD Integration

The validation runs automatically on:
- Pull requests that modify `config/features.yml`
- Pull requests that modify Ruby files in `app/` or `modules/`
- Pull requests that modify spec files

Failed validation will:
- Block the PR from merging (if configured)
- Add a warning comment with specific guidance
- Provide examples of proper test patterns

For questions or issues, consult the [vets-api Copilot Instructions](/.github/copilot-instructions.md).