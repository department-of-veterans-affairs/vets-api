# CLAUDE.md and Copilot Prompt Testing Results

## Overview
Testing the effectiveness of CLAUDE.md guidance and Copilot prompts for the vets-api repository.

## Test Scenarios

### Scenario 1: Adding a New API Endpoint
**Prompt**: "Add a new GET endpoint for veteran profile information"

**Expected Behavior**:
- Should follow Rails conventions
- Use existing authentication patterns
- Include proper serializers
- Add to appropriate module

**Test Result**:
✅ CLAUDE.md correctly guides to:
- Use `before_action :authenticate_user!`
- Place in appropriate module (e.g., `modules/mobile/`)
- Use existing serializer patterns
- Include error handling

**Sample Code Generated**:
```ruby
# modules/mobile/app/controllers/mobile/v0/profile_controller.rb
module Mobile
  module V0
    class ProfileController < ApplicationController
      before_action :authenticate_user!
      
      def show
        profile = veteran_profile_service.get_profile(current_user.icn)
        render json: profile, serializer: Mobile::V0::ProfileSerializer
      rescue => e
        render json: { error: { code: 'PROFILE_ERROR', message: e.message } }, 
               status: :internal_server_error
      end
      
      private
      
      def veteran_profile_service
        @veteran_profile_service ||= VAProfile::Service.new
      end
    end
  end
end
```

### Scenario 2: Background Job Implementation
**Prompt**: "Create a background job to process claim updates"

**Expected Behavior**:
- Use Sidekiq patterns
- Place in `app/sidekiq/`
- Include proper error handling
- Follow retry logic patterns

**Test Result**:
✅ CLAUDE.md correctly guides to:
- Inherit from appropriate base class
- Use `perform_async` pattern
- Include idempotent operations
- Add proper logging

**Sample Code Generated**:
```ruby
# app/sidekiq/claims/update_status_job.rb
module Claims
  class UpdateStatusJob
    include Sidekiq::Job
    
    sidekiq_options retry: 3, queue: 'default'
    
    def perform(claim_id)
      claim = Claim.find(claim_id)
      
      # Idempotent check
      return if claim.status_updated_at > 1.hour.ago
      
      response = lighthouse_service.get_claim_status(claim.external_id)
      
      claim.update!(
        status: response.status,
        status_updated_at: Time.current
      )
      
      Rails.logger.info("Updated claim #{claim_id} status to #{response.status}")
    rescue => e
      Rails.logger.error("Failed to update claim #{claim_id}: #{e.message}")
      raise # Let Sidekiq retry
    end
    
    private
    
    def lighthouse_service
      @lighthouse_service ||= Lighthouse::ClaimsService.new
    end
  end
end
```

### Scenario 3: External Service Integration
**Prompt**: "Integrate with a new VA service for appointment scheduling"

**Expected Behavior**:
- Create service client in `lib/`
- Use Faraday for HTTP
- Include timeout and retry logic
- Add VCR for testing

**Test Result**:
✅ CLAUDE.md correctly guides to:
- Implement resilient retry logic
- Use proper timeouts
- Handle BGS/MVI quirks
- Include comprehensive error handling

**Sample Code Generated**:
```ruby
# lib/va_appointments/service.rb
module VAAppointments
  class Service
    include Common::Client::Concerns::Monitoring
    
    STATSD_KEY_PREFIX = 'api.va_appointments'
    
    def initialize(user)
      @user = user
      @icn = user.icn
    end
    
    def get_appointments
      with_monitoring do
        response = perform(:get, appointments_path)
        response.body['data']
      end
    rescue Faraday::TimeoutError => e
      Rails.logger.error("VA Appointments timeout for user #{@icn}: #{e.message}")
      raise Common::Exceptions::GatewayTimeout
    rescue => e
      Rails.logger.error("VA Appointments error for user #{@icn}: #{e.message}")
      raise Common::Exceptions::BackendServiceException
    end
    
    private
    
    def connection
      @connection ||= Faraday.new(base_url) do |conn|
        conn.request :json
        conn.response :json
        conn.options.timeout = 30
        conn.options.open_timeout = 15
        conn.adapter Faraday.default_adapter
        
        # Retry logic for unreliable services
        conn.request :retry, max: 3,
                     interval: 0.5,
                     backoff_factor: 2,
                     exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed]
      end
    end
    
    def base_url
      Settings.va_appointments.base_url
    end
    
    def appointments_path
      "/api/v1/veterans/#{@icn}/appointments"
    end
  end
end
```

### Scenario 4: Database Migration
**Prompt**: "Add a new table for tracking veteran preferences"

**Expected Behavior**:
- Use proper migration patterns
- Include indexes for performance
- Consider PostGIS if location-based
- Use concurrent index creation

**Test Result**:
✅ CLAUDE.md correctly guides to:
- Use `algorithm: :concurrently` for indexes
- Add `disable_ddl_transaction!` when needed
- Follow Rails migration conventions

**Sample Code Generated**:
```ruby
# db/migrate/20250904_create_veteran_preferences.rb
class CreateVeteranPreferences < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    create_table :veteran_preferences do |t|
      t.string :user_uuid, null: false
      t.string :icn, null: false
      t.jsonb :notification_settings, default: {}
      t.jsonb :display_settings, default: {}
      t.string :preferred_facility_id
      t.string :preferred_language, default: 'en'
      
      t.timestamps
    end
    
    add_index :veteran_preferences, :user_uuid, unique: true, algorithm: :concurrently
    add_index :veteran_preferences, :icn, algorithm: :concurrently
    add_index :veteran_preferences, :preferred_facility_id, algorithm: :concurrently
  end
end
```

## Copilot Prompt Templates Testing

### SRE Ticket Generation Prompt
**Test Prompt**:
```markdown
Generate a GitHub issue for SRE team using this template:
- Type: Bug
- Service: vets-api
- Issue: High memory consumption in production
- Impact: Potential service degradation
```

**Generated Output**:
```markdown
## Issue Type
Bug

## Service/Component
vets-api

## Description
High memory consumption observed in production environment for vets-api service.

## Impact
- Potential service degradation
- Risk of OOM errors
- Possible impact on response times

## Current Behavior
Memory usage has increased from baseline 4GB to 7.5GB over the past 24 hours.

## Expected Behavior
Memory usage should remain stable around 4GB baseline.

## Steps to Reproduce
1. Monitor memory metrics in DataDog
2. Observe gradual increase over time
3. Check for memory leak indicators

## Metrics/Logs
- DataDog dashboard: [link]
- Relevant logs: Check for memory allocation patterns
- Time range: Last 24-48 hours

## Priority
High - Production impact

## Proposed Solution
1. Investigate recent deployments
2. Check for memory leak in background jobs
3. Review Sidekiq queue sizes
4. Consider rolling restart if needed

## Acceptance Criteria
- [ ] Root cause identified
- [ ] Memory usage returns to baseline
- [ ] Monitoring alerts configured
- [ ] Documentation updated
```

## Test Results Summary

### CLAUDE.md Effectiveness
✅ **Strengths**:
- Clear architectural guidance
- Good security patterns (authentication, PII handling)
- Proper error handling patterns
- Consistent code style

⚠️ **Areas for Improvement**:
- Add more module-specific examples
- Include testing patterns (RSpec, VCR)
- Add performance considerations
- Include deployment patterns

### Copilot Integration
✅ **Working Well**:
- Follows Rails conventions
- Uses repository patterns correctly
- Generates secure code patterns

⚠️ **Needs Enhancement**:
- More specific VA.gov patterns
- BGS/MVI service quirks
- Federal compliance requirements

## Recommendations

1. **Enhance CLAUDE.md with**:
   - Testing examples (RSpec patterns)
   - Module-specific guidance
   - Performance optimization patterns
   - Federal compliance requirements

2. **Create Copilot Templates for**:
   - SRE incident tickets
   - Feature implementation tickets
   - Bug report templates
   - Security vulnerability reports

3. **Add Repository-Specific Context**:
   - Common error patterns
   - Performance bottlenecks
   - Integration gotchas
   - Testing best practices

## Next Steps

1. ✅ CLAUDE.md provides good foundational guidance
2. ✅ Copilot can generate appropriate code following patterns
3. 🔄 Need to add more specific examples for complex scenarios
4. 🔄 Create template library for common tasks
5. 📝 Document learnings in Confluence

## Validation Checklist

- [x] CLAUDE.md guides proper authentication patterns
- [x] Copilot generates Rails-compliant code
- [x] Security patterns are followed
- [x] Error handling is appropriate
- [x] External service patterns are resilient
- [ ] Testing patterns need documentation
- [ ] Deployment patterns need documentation
- [ ] Federal compliance patterns need documentation