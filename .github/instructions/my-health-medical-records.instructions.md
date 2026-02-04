---
applyTo: "modules/my_health/app/controllers/my_health/mr_controller.rb,modules/my_health/app/controllers/my_health/bb_controller.rb,modules/my_health/app/controllers/my_health/v1/allergies_controller.rb,modules/my_health/app/controllers/my_health/v1/clinical_notes_controller.rb,modules/my_health/app/controllers/my_health/v1/conditions_controller.rb,modules/my_health/app/controllers/my_health/v1/labs_and_tests_controller.rb,modules/my_health/app/controllers/my_health/v1/vaccines_controller.rb,modules/my_health/app/controllers/my_health/v1/vitals_controller.rb,modules/my_health/app/controllers/my_health/v1/health_records_controller.rb,modules/my_health/app/controllers/my_health/v1/health_record_contents_controller.rb,modules/my_health/app/controllers/my_health/v1/medical_records/**/*_controller.rb,modules/my_health/app/controllers/my_health/v2/allergies_controller.rb,modules/my_health/app/controllers/my_health/v2/clinical_notes_controller.rb,modules/my_health/app/controllers/my_health/v2/conditions_controller.rb,modules/my_health/app/controllers/my_health/v2/immunizations_controller.rb,modules/my_health/app/controllers/my_health/v2/labs_and_tests_controller.rb,modules/my_health/app/controllers/my_health/v2/vitals_controller.rb,modules/my_health/app/controllers/my_health/v2/ccd_controller.rb,modules/my_health/app/controllers/my_health/v2/concerns/**/*,modules/my_health/app/controllers/concerns/my_health/mhv_controller_concerns.rb,modules/my_health/app/controllers/concerns/my_health/aal_client_concerns.rb,modules/my_health/app/controllers/concerns/sortable_records.rb,app/controllers/concerns/json_api_pagination_links.rb,modules/my_health/app/serializers/my_health/v1/allergy_serializer.rb,modules/my_health/app/serializers/my_health/v1/health_condition_serializer.rb,modules/my_health/app/serializers/my_health/v1/extract_status_serializer.rb,modules/my_health/app/serializers/my_health/v1/eligible_data_classes_serializer.rb,modules/my_health/app/serializers/my_health/v1/vaccine_serializer.rb,modules/mobile/app/controllers/mobile/v0/allergy_intolerances_controller.rb,modules/mobile/app/controllers/mobile/v0/immunizations_controller.rb,modules/mobile/app/controllers/mobile/v0/labs_and_tests_controller.rb,modules/mobile/app/controllers/mobile/v1/allergy_intolerances_controller.rb,modules/mobile/app/controllers/mobile/v1/immunizations_controller.rb,modules/mobile/app/controllers/mobile/v1/labs_and_tests_controller.rb,modules/mobile/app/models/mobile/v0/adapters/allergy_intolerance.rb,modules/mobile/app/models/mobile/v0/adapters/legacy_allergy_intolerance.rb,modules/mobile/app/models/mobile/v0/adapters/immunizations.rb,modules/mobile/app/models/mobile/v0/adapters/diagnostic_report.rb,modules/mobile/app/services/mobile/v0/lighthouse_health/**/*,modules/mobile/spec/requests/mobile/v0/health/allergy_intolerance_spec.rb,modules/mobile/spec/requests/mobile/v0/health/immunizations_spec.rb,modules/mobile/spec/requests/mobile/v0/health/labs_and_tests_spec.rb,modules/mobile/spec/requests/mobile/v1/health/allergies_spec.rb,modules/mobile/spec/requests/mobile/v1/health/immunizations_spec.rb,modules/mobile/spec/requests/mobile/v1/health/labs_and_tests_spec.rb,modules/mobile/spec/models/adapters/immunizations_adapter_spec.rb,lib/lighthouse/veterans_health/**/*,lib/medical_records/**/*,lib/bb/**/*,lib/mhv/aal/**/*,lib/unified_health_data/**/*,app/policies/mhv_medical_records_policy.rb,app/policies/mhv_health_records_policy.rb,app/sidekiq/unified_health_data/**/*,modules/my_health/config/routes.rb,modules/my_health/config/initializers/fhir_client_patch.rb,spec/lib/lighthouse/veterans_health/**/*,spec/lib/medical_records/**/*,spec/lib/bb/**/*,spec/lib/mhv/aal/**/*,spec/lib/unified_health_data/**/*,spec/policies/mhv_medical_records_policy_spec.rb,spec/sidekiq/unified_health_data/**/*,spec/support/vcr_cassettes/mr_client/**/*,modules/my_health/spec/requests/my_health/v1/medical_records/**/*,modules/my_health/spec/requests/my_health/v1/allergies*,modules/my_health/spec/requests/my_health/v1/clinical_notes*,modules/my_health/spec/requests/my_health/v1/conditions*,modules/my_health/spec/requests/my_health/v1/labs_and_tests*,modules/my_health/spec/requests/my_health/v1/vaccines*,modules/my_health/spec/requests/my_health/v1/vitals*,modules/my_health/spec/requests/my_health/v2/**/*,modules/my_health/spec/controllers/my_health/**/*,modules/my_health/spec/serializer/v1/extract_status_serializer_spec.rb,modules/my_health/spec/serializer/v1/eligible_data_classes_serializer_spec.rb"
---

<!-- @format -->

# Copilot Instructions for My Health / Medical Records

**Path-Specific Instructions for Medical Records**

These instructions automatically apply when working with:

- **Controllers:** All controllers inheriting from `MyHealth::MRController`
  - `AllergiesController`, `ClinicalNotesController`, `ConditionsController`
  - `LabsAndTestsController`, `VaccinesController`, `VitalsController`
  - `MedicalRecords::CcdController`, `MedicalRecords::ImagingController`
  - `MedicalRecords::RadiologyController`, `MedicalRecords::PatientController`
  - `MedicalRecords::BbmiNotificationController`, `MedicalRecords::MRSessionController`
- **Client Libraries:** `lib/medical_records/` - MedicalRecords clients for MHV and Lighthouse APIs
- **Serializers:** Medical Records-related JSONAPI serializers in `modules/my_health/app/serializers/my_health/v1/`
- **Policy:** `app/policies/mhv_medical_records_policy.rb` - Authorization policy for Medical Records access

---

## 📚 Medical Records Module Structure

### MRController Hierarchy (`modules/my_health/`)

All Medical Records controllers inherit from `MRController` which provides:

- Multiple client initialization (MedicalRecords, Lighthouse, PHRMgr, BBInternal)
- MHV session management via multiple authentication mechanisms
- Patient resource handling (`with_patient_resource`, `render_resource`)
- Feature flag support for Accelerated Delivery (Oracle Health) data paths

**Base Controller:**

- `modules/my_health/app/controllers/my_health/mr_controller.rb` - Base controller for all Medical Records features

**Medical Records Controllers (inherit from MRController):**

- `modules/my_health/app/controllers/my_health/v1/allergies_controller.rb` - Allergy data (index, show)
- `modules/my_health/app/controllers/my_health/v1/clinical_notes_controller.rb` - Clinical notes (index, show)
- `modules/my_health/app/controllers/my_health/v1/conditions_controller.rb` - Health conditions (index, show)
- `modules/my_health/app/controllers/my_health/v1/labs_and_tests_controller.rb` - Lab results and diagnostic tests (index, show)
- `modules/my_health/app/controllers/my_health/v1/vaccines_controller.rb` - Vaccination records (index, show, pdf)
- `modules/my_health/app/controllers/my_health/v1/vitals_controller.rb` - Vital signs data (index)

**Medical Records Namespace Controllers:**

- `modules/my_health/app/controllers/my_health/v1/medical_records/ccd_controller.rb` - Consolidated CDA generation and retrieval
- `modules/my_health/app/controllers/my_health/v1/medical_records/imaging_controller.rb` - Medical imaging study retrieval
- `modules/my_health/app/controllers/my_health/v1/medical_records/radiology_controller.rb` - Radiology reports
- `modules/my_health/app/controllers/my_health/v1/medical_records/patient_controller.rb` - Patient demographics and extract operations
- `modules/my_health/app/controllers/my_health/v1/medical_records/bbmi_notification_controller.rb` - Blue Button notification handling
- `modules/my_health/app/controllers/my_health/v1/medical_records/mr_session_controller.rb` - Medical Records session management

**Serializers (JSONAPI format):**

- `modules/my_health/app/serializers/my_health/v1/allergy_serializer.rb` - Allergy data
- `modules/my_health/app/serializers/my_health/v1/health_condition_serializer.rb` - Health conditions
- `modules/my_health/app/serializers/my_health/v1/extract_status_serializer.rb` - CCD extract status
- `modules/my_health/app/serializers/my_health/v1/eligible_data_classes_serializer.rb` - Available data classes for user

### Routes (`modules/my_health/config/routes.rb`)

**Medical Records namespace (`/my_health/v1/medical_records/`):**

```ruby
# V0 routes (Legacy)
scope :medical_records do
  resources :allergies, only: %i[index show]
  resources :clinical_notes, only: %i[index show]
  resources :conditions, only: %i[index show]
  resources :labs_and_tests, only: %i[index]
end

# V1 routes (Current)
namespace :v1 do
  scope :medical_records do
    resources :vaccines, only: %i[index show] do
      get :pdf, on: :member
    end
    resources :allergies, only: %i[index show]
    resources :clinical_notes, only: %i[index show]
    resources :labs_and_tests, only: %i[index show]
    resources :vitals, only: %i[index]
    resources :conditions, only: %i[index show]
  end

  namespace :medical_records do
    resource :ccd, only: %i[create show], controller: :ccd do
      get :status, on: :member
    end
    resources :imaging, only: %i[index show], defaults: { format: :json }
    resources :radiology, only: %i[index show], defaults: { format: :json }
    resource :patient, only: [], controller: :patient do
      get :vitals, on: :collection
      get :allergies, on: :collection
      get :labs, on: :collection
      get :vaccines, on: :collection
      post :extract, on: :collection
      get :extract_status, on: :collection
    end
    resource :bbmi_notification, only: %i[create], defaults: { format: :json }
    resource :mr_session, only: [], controller: :mr_session do
      post :create, on: :collection
    end
  end
end
```

### Medical Records Client Libraries (`lib/medical_records/`)

**Core Files:**

- `lib/medical_records/client.rb` - Main FHIR-based client for MHV Medical Records API
- `lib/medical_records/configuration.rb` - Faraday configuration for Medical Records endpoints
- `lib/medical_records/client_session.rb` - Session management for MHV authentication
- `lib/medical_records/lighthouse_client.rb` - Client for Lighthouse Health API (Oracle Health data path)
- `lib/medical_records/bb_internal/client.rb` - Blue Button internal API client
- `lib/medical_records/phr_mgr/client.rb` - PHR Manager client for patient data operations
- `lib/medical_records/user_eligibility/client.rb` - User eligibility verification client

**Key Client Methods (MedicalRecords::Client):**

```ruby
# Allergies
client.list_allergies(user_uuid, use_cache: true)
client.get_allergy(allergy_id)

# Clinical Notes
client.list_clinical_notes
client.get_clinical_note(note_id)

# Conditions
client.list_conditions(user_uuid, use_cache: true)
client.get_condition(condition_id)

# Labs and Tests
client.list_labs_and_tests
client.get_diagnostic_report(report_id)

# Vaccines
client.list_immunizations(user_uuid, use_cache: true)
client.get_immunization(immunization_id)

# Vitals
client.list_vitals

# Patient Data
client.get_patient_by_identifier(fhir_client, identifier)
```

**Key Client Methods (MedicalRecords::LighthouseClient):**

```ruby
# Lighthouse Health API (Oracle Health data path)
lighthouse_client = MedicalRecords::LighthouseClient.new(icn)

# FHIR-based resource retrieval
lighthouse_client.list_allergies
lighthouse_client.list_conditions
lighthouse_client.list_immunizations
lighthouse_client.list_observations  # Vitals and labs
```

---

## 🎯 Key Concepts

### Patient Resource Handling

**202 Accepted for Patient Not Found:**
MHV API returns `202 Accepted` when patient does not exist in the system (not a 404). Controllers should handle this gracefully:

```ruby
def with_patient_resource(resource)
  if resource.equal?(:patient_not_found)
    render plain: '', status: :accepted
  else
    yield resource
  end
end

def render_resource(resource)
  if resource.equal?(:patient_not_found)
    render plain: '', status: :accepted
  else
    render json: resource.to_json
  end
end
```

### Multi-Client Architecture

MRController supports multiple client types based on feature flags and data source:

```ruby
def client
  use_oh_data_path = Flipper.enabled?(:mhv_accelerated_delivery_enabled, @current_user) &&
                     params[:use_oh_data_path].to_i == 1
  @client ||= if use_oh_data_path
                create_lighthouse_client
              else
                create_medical_records_client
              end
end

private

def create_lighthouse_client
  MedicalRecords::LighthouseClient.new(current_user.icn)
end

def create_medical_records_client
  MedicalRecords::Client.new(
    session: {
      user_uuid: current_user.user_account_uuid,
      user_id: current_user.mhv_correlation_id
    },
    icn: current_user.icn
  )
end

def phrmgr_client
  @phrmgr_client ||= PHRMgr::Client.new(current_user.icn)
end

def bb_client
  @bb_client ||= BBInternal::Client.new(
    session: { user_id: current_user.mhv_correlation_id }
  )
end
```

### FHIR Client Integration

Medical Records API is FHIR R4 compliant. The client uses the `fhir_models` gem:

```ruby
def fhir_client
  @fhir_client ||= sessionless_fhir_client(jwt_bearer_token)
end

def sessionless_fhir_client(bearer_token)
  FHIR.logger.level = Logger::INFO

  FHIR::Client.new(base_path).tap do |client|
    client.use_r4
    client.default_json
    client.use_minimal_preference
    client.set_bearer_token(bearer_token)
  end
end
```

### LOINC Codes

Medical Records uses LOINC codes to identify different types of clinical data:

```ruby
# Clinical Notes
PHYSICIAN_PROCEDURE_NOTE = '11506-3'
DISCHARGE_SUMMARY = '18842-5'
CONSULT_RESULT = '11488-4'

# Vitals
BLOOD_PRESSURE = '85354-9'
BREATHING_RATE = '9279-1'
HEART_RATE = '8867-4'
HEIGHT = '8302-2'
TEMPERATURE = '8310-5'
WEIGHT = '29463-7'
PULSE_OXIMETRY = '59408-5,2708-6'

# Labs & Tests
MICROBIOLOGY = '79381-0'
PATHOLOGY = '60567-5'
EKG = '11524-6'
RADIOLOGY = '18748-4'
```

---

## 🔧 Common Patterns

### Controller Pattern for Medical Records

```ruby
module MyHealth
  module V1
    class AllergiesController < MRController
      def index
        render_resource client.list_allergies(@current_user.uuid)
      end

      def show
        allergy_id = params[:id].try(:strip)
        render_resource client.get_allergy(allergy_id)
      end
    end
  end
end
```

### Controller Pattern with Pagination Support (Experimental)

```ruby
module MyHealth
  module V1
    class AllergiesController < MRController
      def index
        if Flipper.enabled?(:mhv_medical_records_support_new_model_allergy)
          use_cache = params.key?(:use_cache) ?
            ActiveModel::Type::Boolean.new.cast(params[:use_cache]) : true

          with_patient_resource(client.list_allergies(@current_user.uuid, use_cache:)) do |resource|
            resource = resource.sort
            if pagination_params[:per_page]
              resource = resource.paginate(**pagination_params)
              links = pagination_links(resource)
            end
            options = { meta: resource.metadata, links: }
            render json: AllergySerializer.new(resource.data, options)
          end
        else
          render_resource client.list_allergies(@current_user.uuid)
        end
      end
    end
  end
end
```

### Client Usage Pattern

```ruby
# Initialize client (automatic via MRController#client)
# Client selection based on feature flags and use_oh_data_path parameter

# Fetch allergies
allergies = client.list_allergies(user.uuid, use_cache: true)

# Fetch single allergy
allergy = client.get_allergy(allergy_id)

# Handle patient not found
if allergies.equal?(:patient_not_found)
  render plain: '', status: :accepted
else
  render json: allergies.to_json
end
```

### Testing Pattern

```ruby
RSpec.describe 'MyHealth::V1::Allergies', type: :request do
  let(:user) { build(:user, :mhv) }
  let(:allergy_id) { '123' }

  before do
    sign_in_as(user)
  end

  describe 'GET /my_health/v1/medical_records/allergies' do
    context 'when patient exists' do
      it 'returns allergies list' do
        VCR.use_cassette('medical_records/allergies/list_success') do
          get '/my_health/v1/medical_records/allergies'

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to be_an(Array)
        end
      end
    end

    context 'when patient does not exist' do
      it 'returns 202 Accepted' do
        VCR.use_cassette('medical_records/allergies/patient_not_found') do
          get '/my_health/v1/medical_records/allergies'

          expect(response).to have_http_status(:accepted)
          expect(response.body).to be_empty
        end
      end
    end
  end

  describe 'GET /my_health/v1/medical_records/allergies/:id' do
    it 'returns single allergy' do
      VCR.use_cassette('medical_records/allergies/get_allergy_success') do
        get "/my_health/v1/medical_records/allergies/#{allergy_id}"

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
```

---

## ⚙️ Feature Flags

### Medical Records Feature Flags

**`:mhv_accelerated_delivery_enabled`**

- Enables Oracle Health (Lighthouse) data path when combined with `use_oh_data_path=1` parameter
- User-specific flag
- Routes requests to LighthouseClient instead of MedicalRecords::Client

**`:mhv_accelerated_delivery_uhd_oh_lab_type_logging_enabled`**

- Enables background job logging for Oracle Health lab data refresh
- Used with LighthouseClient

**`:mhv_accelerated_delivery_uhd_vista_lab_type_logging_enabled`**

- Enables background job logging for VistA lab data refresh
- Used with MedicalRecords::Client

**`:mhv_medical_records_new_eligibility_check`**

- Enables new eligibility verification via UserEligibility::Client
- Replaces account type check with SM user eligibility check

**`:mhv_medical_records_support_new_model_allergy`** (Experimental)

- Enables new allergies model with pagination support
- Not yet fully implemented

**`:mhv_medical_records_support_backend_pagination_allergy`**

- Enables caching for allergy data when using new model
- Works with `:mhv_medical_records_support_new_model_allergy`

**Usage Pattern:**

```ruby
def client
  use_oh_data_path = Flipper.enabled?(:mhv_accelerated_delivery_enabled, @current_user) &&
                     params[:use_oh_data_path].to_i == 1

  @client ||= if use_oh_data_path
                create_lighthouse_client
              else
                create_medical_records_client
              end
end
```

**In Tests:**

```ruby
# ALWAYS stub, never enable/disable
allow(Flipper).to receive(:enabled?)
  .with(:mhv_accelerated_delivery_enabled, user).and_return(true)
allow(Flipper).to receive(:enabled?)
  .with(:mhv_medical_records_new_eligibility_check).and_return(false)
```

---

## 🔐 Authentication & Authorization

### Authorization Policy (`app/policies/mhv_medical_records_policy.rb`)

The `MHVMedicalRecordsPolicy` controls access to Medical Records features:

```ruby
MHVMedicalRecordsPolicy = Struct.new(:user, :mhv_medical_records) do
  MR_ACCOUNT_TYPES = %w[Premium].freeze

  def access?
    if Flipper.enabled?(:mhv_medical_records_new_eligibility_check)
      begin
        client = UserEligibility::Client.new(user.mhv_correlation_id, user.icn)
        response = client.get_is_valid_sm_user
        validate_client(response) && user.va_patient?
      rescue => e
        log_denial_details('ERROR FETCHING SM USER ELIGIBILITY', e)
        false
      end
    else
      MR_ACCOUNT_TYPES.include?(user.mhv_account_type) && user.va_patient?
    end
  end

  private

  def validate_client(response)
    [
      'MHV Premium SM account with no logins in past 26 months',
      'MHV Premium SM account with Logins in past 26 months',
      'MHV Premium account with no SM'
    ].any? { |substring| response['accountStatus'].include?(substring) }
  end
end
```

**Access Requirements:**

1. **Legacy:** MHV Premium account type AND VA patient status
2. **New (with feature flag):** Valid SM user eligibility AND VA patient status

**Feature Flag:**

- **`:mhv_medical_records_new_eligibility_check`** - When enabled, uses new eligibility verification

**Usage in Controllers:**

```ruby
# In MRController
def authorize
  raise_access_denied unless current_user.authorize(:mhv_medical_records, :access?)
end

def raise_access_denied
  raise Common::Exceptions::Forbidden, detail: 'You do not have access to medical records'
end
```

### MHV Session Management

**MRController initializes Blue Button client for authentication:**

```ruby
before_action :authenticate_bb_client

def bb_client
  @bb_client ||= BBInternal::Client.new(
    session: { user_id: current_user.mhv_correlation_id }
  )
end

def authenticate_bb_client
  bb_client.authenticate
end
```

**Key Points:**

- User must be VA patient (`user.va_patient?`)
- Legacy: User must have MHV Premium account type
- New: User must pass SM user eligibility check
- BB client authentication required before accessing Medical Records endpoints
- Multiple client types support different authentication mechanisms

---

## 📝 Error Handling

### Common Error Scenarios

**Patient Not Found (202 Accepted):**

```ruby
# MHV returns 202 when patient doesn't exist in system
if resource.equal?(:patient_not_found)
  render plain: '', status: :accepted
else
  render json: resource.to_json
end
```

**Record Not Found:**

```ruby
raise Common::Exceptions::RecordNotFound, record_id if resource.blank?
# Returns 404 Not Found
```

**MHV API Errors:**

```ruby
rescue Faraday::TimeoutError => e
  Rails.logger.error("MHV MR: Timeout for user #{current_user.icn}")
  render json: {
    error: {
      code: 'MHV_TIMEOUT',
      message: 'Service temporarily unavailable'
    }
  }, status: :gateway_timeout

rescue Faraday::ClientError => e
  Rails.logger.error("MHV MR: Client error - #{e.message}")
  render json: {
    error: {
      code: 'MHV_ERROR',
      message: 'Unable to process request'
    }
  }, status: :bad_gateway
```

**Never Log PII:**

- ❌ Don't log: patient names, SSN, medical data, addresses
- ✅ Do log: `user.icn`, record IDs, error types, response codes

---

## 🧪 Testing Guidelines

### Test Structure for Medical Records Features

**Request Specs:**

- Location: `modules/my_health/spec/requests/my_health/v1/`
- Use VCR cassettes for Medical Records client responses
- Test all HTTP status codes: 200, 202, 404, 500
- Test authentication requirements
- Test patient not found scenarios

**Client Specs:**

- Location: `spec/lib/medical_records/`
- Test individual MedicalRecords::Client methods
- Use VCR cassettes for MHV API responses
- Test FHIR client interactions

### VCR Cassette Naming Convention

```
spec/fixtures/vcr_cassettes/medical_records/
  ├── allergies/
  │   ├── list_success.yml
  │   ├── get_allergy_success.yml
  │   └── patient_not_found.yml
  ├── clinical_notes/
  │   └── list_success.yml
  ├── conditions/
  │   └── list_success.yml
  ├── labs_and_tests/
  │   └── list_success.yml
  └── vaccines/
      └── list_success.yml
```

---

## 📊 Monitoring & Logging

### Datadog Tracing (Recommended Addition)

```ruby
def index
  Datadog::Tracing.trace('mhv.medical_records.list_allergies') do |span|
    span.set_tag('user.icn', current_user.icn)
    span.set_tag('data_source', use_oh_data_path ? 'lighthouse' : 'mhv')

    render_resource client.list_allergies(@current_user.uuid)
  end
end
```

### StatsD Metrics

Track Medical Records API calls:

- `api.medical_records.list_allergies` - Allergy retrieval
- `api.medical_records.list_conditions` - Condition retrieval
- `api.medical_records.list_labs` - Lab results retrieval

---

## 🚨 Common Issues & Solutions

### Issue: 202 Accepted response instead of 404

**Solution:** This is expected behavior. MHV returns 202 when patient doesn't exist in the system. Handle gracefully with empty response body.

### Issue: FHIR client errors

**Solution:** Ensure `fhir_models` gem is properly configured. Check FHIR logger level and bearer token validity.

### Issue: Lighthouse vs MHV data path confusion

**Solution:** Check `use_oh_data_path` parameter and `:mhv_accelerated_delivery_enabled` feature flag. Log which client is being used.

### Issue: BBInternal client authentication failures

**Solution:** Verify MHV correlation ID is present. Check BB client session management.

### Issue: Missing LOINC codes

**Solution:** Reference LOINC code constants defined in `MedicalRecords::Client`. Add new codes as needed for additional data types.

---

## 🔄 Maintaining These Instructions

### When to Update This File

**This instruction file should be updated when changes to `applyTo` files impact:**

- API contracts (request/response formats, endpoints, parameters)
- Controller patterns (before_actions, error handling, patient resource handling)
- Client methods or signatures
- FHIR client integration patterns
- Serializer structure or attributes
- Route definitions
- Feature flag usage patterns (especially data path selection)
- Authentication/authorization requirements
- LOINC codes or clinical data type definitions

**Analyze changes for impact:**

1. **New endpoints or actions** → Update Routes section and Controller examples
2. **New data types (allergies, labs, etc.)** → Update Controller list and Client methods
3. **New MedicalRecords::Client methods** → Update Client Library section with method signatures
4. **New serializers or attributes** → Update Serializers section
5. **New feature flags** → Update Feature Flags section with usage patterns
6. **New LOINC codes** → Update Key Concepts section with new code definitions
7. **Changed error handling** → Update Error Handling section
8. **New client types (Lighthouse, PHRMgr, etc.)** → Update Multi-Client Architecture section
9. **Authentication changes** → Update Authentication & Authorization section
10. **FHIR integration changes** → Update FHIR Client Integration section

**Changes that DON'T require updates:**

- Internal implementation details that don't affect usage patterns
- Refactoring that maintains the same public interface
- Bug fixes that don't change behavior
- Performance optimizations without API changes
- Code style or formatting changes

**How to Keep Instructions Current:**

- Review this file when making significant changes to Medical Records features
- Update code examples to match current patterns in the codebase
- Remove deprecated patterns and add new best practices
- Keep VCR cassette examples aligned with actual test structure
- Verify feature flag documentation matches current implementation
- Update LOINC codes when new clinical data types are added

---

**These path-specific instructions automatically apply when working on My Health/Medical Records features.**
