# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Vets API is a Ruby on Rails API providing common services for applications on VA.gov (formerly vets.gov). It serves millions of veterans with benefits, healthcare, appeals, and claim processing functionality.

**Core Technologies:**
- Ruby ~3.3.6
- Rails ~7.2.2  
- PostgreSQL 15.x with PostGIS 3
- Redis 6.2.x
- Sidekiq (Enterprise for production features)

**Key External Services:**
- BGS (Benefits Gateway Services) - benefits data
- MVI (Master Veteran Index) - veteran identity
- Lighthouse APIs - modern REST APIs for claims, health records
- VA Profile - contact information

## Project Architecture

**Modular Structure:**
- Main Rails app in `app/` directory
- Modules in `modules/` directory (Rails engines for specific features)
- Each module contains: appeals_api, claims_api, mobile, my_health, etc.
- Shared concerns and base classes in main app

**Key Directories:**
- `app/controllers/` - Base controllers and shared functionality
- `app/models/` - Core domain models and shared entities  
- `app/serializers/` - JSON API serializers for responses
- `app/services/` - Business logic services
- `app/sidekiq/` - Background jobs
- `modules/*/` - Feature-specific Rails engines
- `lib/` - Utilities and external service integrations
- `config/` - Application configuration and settings

## Common Development Commands

**Setup and Dependencies:**
```bash
# Install dependencies
bundle install

# Database setup and migration
make db

# Alternative database commands
bundle exec rails db:create db:migrate
```

**Running the Application:**
```bash
# Start all services with Foreman
foreman start -m all=1

# Rails console
bundle exec rails console
```

**Testing:**
```bash
# Run all tests
bundle exec rspec spec/

# Run specific test file
bundle exec rspec path/to/spec_file.rb

# Run tests with logging (logs to log/test.log)
RAILS_ENABLE_TEST_LOG=true bundle exec rspec path/to/spec.rb

# Alternative test command
make spec
```

**Code Quality:**
```bash
# Run RuboCop linter
bundle exec rubocop

# Run Brakeman security scanner
bundle exec brakeman
```

## Development Patterns and Standards

**Authentication and Authorization:**
- Most endpoints require `before_action :authenticate_user!`
- Use ICN (Integration Control Number) for veteran identification with external services
- Policy classes in `app/policies/` for authorization logic

**API Responses:**
- Use serializers: `render json: object, serializer: SomeSerializer`
- Error responses use envelope format: `{ error: { code, message } }`
- Service objects return `{ data: result, error: nil }` pattern

**Background Jobs:**
- Use Sidekiq for operations taking >2 seconds
- Jobs in `app/sidekiq/` directory
- `perform_async` for immediate background work
- `perform_in` for delayed execution

**Feature Flags:**
- Flipper for gradual rollouts and A/B testing
- In tests, stub instead of enable/disable: `allow(Flipper).to receive(:enabled?).with(:feature).and_return(true)`

**External Service Integration:**
- Service clients in `lib/` with Faraday configuration  
- Always include error handling, timeouts, retries
- Use VCR cassettes for testing external service calls
- BGS and MVI services can be slow/unreliable - implement resilient retry logic

**Security Considerations:**
- Never log PII (email, SSN, medical data)
- Use strong parameters - never use `params` directly
- Store sensitive config in environment variables
- Implement idempotent operations to prevent duplicate submissions

**Database:**
- PostGIS required for geospatial functionality
- Use `algorithm: :concurrently` for index operations in migrations
- Add `disable_ddl_transaction!` for concurrent index operations

## Configuration

**Settings:**
- Main configuration in `config/settings.yml` (maintain alphabetical order)
- Environment-specific overrides in `config/settings/[environment].yml`
- Local development customization in `config/settings.local.yml`

**Important Config Files:**
- `config/routes.rb` - API routing
- `config/database.yml` - Database configuration
- `config/sidekiq.yml` - Background job configuration
- `Gemfile` - Ruby dependencies

## Testing Guidelines

**Test Structure:**
- RSpec tests in `spec/` directory
- Module-specific tests in `modules/*/spec/`
- Use VCR for external service mocking
- Factory Bot for test data creation

**Best Practices:**
- Stub Flipper features instead of enabling/disabling
- Test error conditions and edge cases
- Mock external service calls
- Use `rails_helper.rb` for Rails-specific tests
- Use `spec_helper.rb` for unit tests

**RSpec Testing Patterns:**
- Use `describe` for classes/methods, `context` for conditions
- Start test descriptions with verbs ("returns", "raises", "creates")
- Group related tests with `shared_examples` for reusability
- Use `let` for test data setup, `let!` when immediate evaluation needed
- Prefer `expect().to` over `should` syntax

**Controller Testing Example:**
```ruby
RSpec.describe Mobile::V0::ProfileController, type: :controller do
  let(:user) { build(:user, :accountable) }
  
  before { sign_in_as(user) }
  
  describe '#show' do
    context 'when service returns successfully' do
      let(:profile_data) { { name: 'John Doe', email: 'john@example.com' } }
      
      before do
        allow_any_instance_of(VAProfile::Service)
          .to receive(:get_profile).and_return(profile_data)
      end
      
      it 'returns profile data' do
        get :show
        
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['attributes'])
          .to include('name' => 'John Doe')
      end
    end
    
    context 'when service raises an error' do
      before do
        allow_any_instance_of(VAProfile::Service)
          .to receive(:get_profile).and_raise(StandardError, 'Service unavailable')
      end
      
      it 'returns error response' do
        get :show
        
        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)['error']['message'])
          .to eq('Service unavailable')
      end
    end
  end
end
```

**Service/Model Testing Example:**
```ruby
RSpec.describe VAProfile::Service do
  describe '#get_profile' do
    let(:user_icn) { '12345678901234567' }
    let(:service) { described_class.new }
    
    context 'with valid ICN' do
      it 'returns profile data', :vcr do
        result = service.get_profile(user_icn)
        
        expect(result).to be_a(Hash)
        expect(result).to have_key('personalInformation')
      end
    end
    
    context 'with timeout error' do
      before do
        allow(service).to receive(:perform).and_raise(Faraday::TimeoutError)
      end
      
      it 'raises gateway timeout exception' do
        expect { service.get_profile(user_icn) }
          .to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end
  end
end
```

**Background Job Testing Example:**
```ruby
RSpec.describe Claims::UpdateStatusJob, type: :job do
  let(:claim) { create(:claim) }
  
  describe '#perform' do
    it 'updates claim status' do
      VCR.use_cassette('lighthouse/claims/get_status') do
        expect { described_class.new.perform(claim.id) }
          .to change { claim.reload.status }.to('completed')
      end
    end
    
    it 'is idempotent' do
      claim.update!(status_updated_at: 30.minutes.ago)
      
      expect { described_class.new.perform(claim.id) }
        .not_to change { claim.reload.status }
    end
    
    it 'logs errors and re-raises for Sidekiq retry' do
      allow(Lighthouse::ClaimsService).to receive(:new)
        .and_raise(StandardError, 'API Error')
      
      expect(Rails.logger).to receive(:error)
        .with(/Failed to update claim/)
      
      expect { described_class.new.perform(claim.id) }
        .to raise_error(StandardError, 'API Error')
    end
  end
end
```

## Module-Specific Notes

**Appeals API (`modules/appeals_api/`):**
- Handles Notice of Disagreements and appeals processing
- Integrates with Caseflow and decision review services
- **Key Patterns:**
  - Use `AppealsApi::ApplicationController` as base
  - PDF validation with `AppealsApi::PdfValidation::Validator`
  - Form submission pattern: validate → transform → submit
  - Always include `veteran_icn` in request context
- **Example Controller:**
```ruby
module AppealsApi
  module V0
    class NoticeOfDisagreementsController < AppealsApi::ApplicationController
      before_action :validate_json_schema, only: [:create]
      
      def create
        form_data = transform_request_body
        nod_service.submit_notice_of_disagreement(veteran_icn, form_data)
        
        render json: { status: 'submitted' }, status: :created
      rescue => e
        log_submission_error(e)
        render_error(e)
      end
    end
  end
end
```

**Claims API (`modules/claims_api/`):** 
- Disability compensation claims submission and status
- Power of Attorney management
- Intent to File processing
- **Key Patterns:**
  - Asynchronous processing with `ClaimsApi::SubmissionJob`
  - PDF evidence attachment handling
  - BGS integration for legacy claims
  - Lighthouse integration for modern claims
- **Example Service:**
```ruby
module ClaimsApi
  class ClaimSubmissionService
    def submit_526_claim(veteran, claim_data)
      # Validate claim data
      validator.validate!(claim_data)
      
      # Transform to BGS format
      bgs_payload = transform_to_bgs_format(claim_data)
      
      # Submit asynchronously
      ClaimsApi::SubmissionJob.perform_async(veteran.participant_id, bgs_payload)
      
      { submission_id: SecureRandom.uuid, status: 'pending' }
    end
    
    private
    
    def validator
      @validator ||= ClaimsApi::Form526Validator.new
    end
  end
end
```

**Mobile (`modules/mobile/`):**
- Mobile-specific API endpoints
- Veteran-facing mobile application support
- **Key Patterns:**
  - Version namespacing (`V0`, `V1`, etc.)
  - Simplified response format for mobile consumption
  - Pagination with `Mobile::PaginationMixin`
  - Push notification integration
- **Example Response Pattern:**
```ruby
module Mobile
  module V0
    class AppointmentsController < ApplicationController
      include Mobile::PaginationMixin
      
      def index
        appointments = appointment_service.get_appointments(current_user.icn)
        paginated = paginate_array(appointments, params)
        
        render json: {
          data: serialized_appointments(paginated[:data]),
          meta: pagination_meta(paginated)
        }
      end
      
      private
      
      def serialized_appointments(appointments)
        appointments.map do |apt|
          Mobile::V0::AppointmentSerializer.new(apt).serializable_hash
        end
      end
    end
  end
end
```

**My Health (`modules/my_health/`):**
- Healthcare records and appointments
- Prescription management
- Secure messaging with healthcare providers
- **Key Patterns:**
  - FHIR data transformation
  - MHV (MyHealtheVet) session management
  - Medical record caching strategies
  - HIPAA-compliant logging
- **Example Medical Records:**
```ruby
module MyHealth
  class MedicalRecordsService
    def get_lab_results(user)
      # Check cache first (medical data changes infrequently)
      cached = Rails.cache.read(cache_key(user.icn, 'lab_results'))
      return cached if cached.present?
      
      # Fetch from MHV with proper session
      mhv_session = establish_mhv_session(user)
      lab_data = mhv_client.get_lab_results(mhv_session.token)
      
      # Transform FHIR to simplified format
      transformed = transform_lab_results(lab_data)
      
      # Cache for 1 hour (medical data is semi-static)
      Rails.cache.write(cache_key(user.icn, 'lab_results'), transformed, expires_in: 1.hour)
      
      transformed
    rescue MHV::SessionExpiredError
      # Refresh session and retry once
      retry_with_new_session(user) { get_lab_results(user) }
    end
    
    private
    
    def cache_key(icn, data_type)
      "my_health:#{icn}:#{data_type}"
    end
  end
end
```

**Check In (`modules/check_in/`):**
- Appointment check-in process
- Pre-check-in workflows
- Travel claim integration
- **Key Patterns:**
  - UUID-based session management
  - CHIP (Check-In Experience) integration
  - Mobile-optimized flows
  - Real-time appointment updates

**Veteran Verification (`modules/veteran_verification/`):**
- Service history verification
- Disability rating confirmations
- Letter generation services
- **Key Patterns:**
  - BGS integration for service records
  - PDF generation for verification letters
  - Secure document delivery

## External Service Integration Notes

**BGS (Benefits Gateway Services):**
- Legacy SOAP-based service for benefits data
- Can be slow and unreliable - implement robust retry logic
- Use veteran ICN for lookups

**MVI (Master Veteran Index):**
- Veteran identity and correlation service
- Critical for linking veteran records across systems
- Returns ICN used by other services

**Lighthouse APIs:**
- Modern REST APIs replacing legacy services
- More reliable than BGS for supported operations
- OAuth 2.0 authentication

## Federal Compliance and Security Requirements

**HIPAA Compliance (Healthcare Data):**
- Never log PHI (Protected Health Information) - medical records, treatments, conditions
- Use de-identified data in logs: `Rails.logger.info("Retrieved records for user #{user.uuid}")`
- Implement audit trails for all healthcare data access
- Cache medical data with appropriate expiration (1 hour max for lab results)
- Always use encrypted connections for health data transmission

**PII (Personally Identifiable Information) Protection:**
- Never log SSN, full names, addresses, phone numbers, emails
- Use ICN (Integration Control Number) for user identification in logs
- Implement parameter filtering: `config.filter_parameters += [:ssn, :first_name, :last_name, :email]`
- Sanitize form data before processing: strip, validate, and encode user inputs
- Use strong parameters in controllers - never accept raw `params`

**Federal Security Standards:**
- All API endpoints require authentication unless explicitly public
- Implement proper session management with timeouts
- Use environment variables for all secrets and credentials
- Enable SQL injection protection (Rails default parameterized queries)
- Implement CSRF protection for state-changing operations
- Force SSL/TLS in production environments

**Audit and Compliance Logging:**
```ruby
# Good: Audit-compliant logging
Rails.logger.info("User #{current_user.icn} accessed medical records", {
  user_icn: current_user.icn,
  action: 'medical_records_access',
  timestamp: Time.current,
  request_id: request.uuid
})

# Bad: Exposes PII
Rails.logger.info("John Doe (SSN: 123-45-6789) accessed records")
```

**Data Retention and Disposal:**
- Follow VA data retention policies (typically 7 years for veteran data)
- Implement soft deletes with audit trails: `acts_as_paranoid`
- Regular cleanup jobs for temporary/cached data
- Secure deletion of sensitive data when retention period expires

**Access Control Patterns:**
- Role-based access with clear separation of duties
- Principle of least privilege - minimal necessary permissions
- Regular access reviews and deprovisioning
- Multi-factor authentication for administrative access

**Incident Response Requirements:**
- Log all security-relevant events (authentication, authorization failures)
- Implement automated alerting for security incidents
- Maintain incident response procedures
- Regular security testing and vulnerability assessments

**Data Classification Examples:**
- **Public**: General VA information, public forms
- **Internal**: System metadata, non-sensitive configurations  
- **Confidential**: Veteran personal information, financial data
- **Restricted**: Medical records, disability ratings, service records

**Secure Coding Checklist:**
- [ ] No PII/PHI in logs or error messages
- [ ] All user inputs validated and sanitized
- [ ] Authentication required for sensitive operations
- [ ] Proper error handling (don't expose system internals)
- [ ] Environment variables for secrets
- [ ] SQL injection protection enabled
- [ ] XSS protection headers configured
- [ ] CSRF tokens for state changes
- [ ] Secure session configuration
- [ ] Regular dependency updates for security patches