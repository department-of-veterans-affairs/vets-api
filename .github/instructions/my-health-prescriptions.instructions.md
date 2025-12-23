---
applyTo: "modules/my_health/app/controllers/my_health/rx_controller.rb,modules/my_health/app/controllers/my_health/v1/prescriptions_controller.rb,modules/my_health/app/controllers/my_health/v1/prescription_preferences_controller.rb,modules/my_health/app/controllers/my_health/v1/prescription_documentation_controller.rb,modules/my_health/app/controllers/my_health/v1/trackings_controller.rb,modules/my_health/app/serializers/my_health/v1/prescription_serializer.rb,modules/my_health/app/serializers/my_health/v1/prescription_details_serializer.rb,modules/my_health/app/serializers/my_health/v1/prescription_preference_serializer.rb,modules/my_health/app/serializers/my_health/v1/prescription_documentation_serializer.rb,modules/my_health/app/serializers/my_health/v1/tracking_serializer.rb,lib/rx/**/*,app/models/prescription.rb,app/models/prescription_details.rb,app/models/prescription_preference.rb,app/models/prescription_documentation.rb,app/models/tracking.rb,app/policies/mhv_prescriptions_policy.rb,spec/lib/rx/**/*,modules/my_health/spec/requests/my_health/v1/prescription*,modules/my_health/spec/requests/my_health/v1/tracking*"
---

# Copilot Instructions for My Health / Prescriptions

**Path-Specific Instructions for Prescriptions**

These instructions automatically apply when working with:
- **Controllers:** All controllers inheriting from `MyHealth::RxController`
  - `PrescriptionsController`, `PrescriptionPreferencesController`, `PrescriptionDocumentationController`, `TrackingsController`
- **Client Library:** `lib/rx/` - Rx::Client for MHV Pharmacy API integration
- **Models:** `Prescription`, `PrescriptionDetails`, `PrescriptionPreference`, `PrescriptionDocumentation`, `Tracking`
- **Serializers:** All Rx-related JSONAPI serializers in `modules/my_health/app/serializers/my_health/v1/`
- **Policy:** `app/policies/mhv_prescriptions_policy.rb` - Authorization policy for Prescriptions access

---

## 📚 Prescriptions Module Structure

### RxController Hierarchy (`modules/my_health/`)
All Prescriptions controllers inherit from `RxController` which provides:
- MHV session management via `Rx::Client`
- Authentication checks (`authorize`)
- Service tagging for monitoring (`mhv-medications`)
- JSON API pagination support (via `JsonApiPaginationLinks` concern)

**Base Controller:**
- `modules/my_health/app/controllers/my_health/rx_controller.rb` - Base controller for all Prescriptions features

**Prescriptions Controllers (inherit from RxController):**
- `modules/my_health/app/controllers/my_health/v1/prescriptions_controller.rb` - Prescription CRUD operations and refills (index, show, refill, refill_prescriptions, list_refillable_prescriptions, get_prescription_image)
- `modules/my_health/app/controllers/my_health/v1/prescription_preferences_controller.rb` - Notification preferences (show, update)
- `modules/my_health/app/controllers/my_health/v1/prescription_documentation_controller.rb` - Medication documentation (index)
- `modules/my_health/app/controllers/my_health/v1/trackings_controller.rb` - Prescription shipment tracking (index)

**Serializers (JSONAPI format):**
- `modules/my_health/app/serializers/my_health/v1/prescription_serializer.rb` - Basic prescription data
- `modules/my_health/app/serializers/my_health/v1/prescription_details_serializer.rb` - Detailed prescription data with refill history
- `modules/my_health/app/serializers/my_health/v1/prescription_preference_serializer.rb` - Notification preferences
- `modules/my_health/app/serializers/my_health/v1/prescription_documentation_serializer.rb` - Medication documentation (drug information)
- `modules/my_health/app/serializers/my_health/v1/tracking_serializer.rb` - Shipment tracking data

### Routes (`modules/my_health/config/routes.rb`)
**Prescriptions namespace (`/my_health/v1/prescriptions/`):**

```ruby
namespace :v1 do
  resources :prescriptions, only: %i[index show], defaults: { format: :json } do
    get :active, to: 'prescriptions#index', on: :collection, defaults: { refill_status: 'active' }
    patch :refill, to: 'prescriptions#refill', on: :member
    patch :refill_prescriptions, to: 'prescriptions#refill_prescriptions', on: :collection
    get :list_refillable_prescriptions, to: 'prescriptions#list_refillable_prescriptions', on: :collection
    get 'get_prescription_image/:cmopNdcNumber', to: 'prescriptions#get_prescription_image', on: :collection
    get :documentation, to: 'prescription_documentation#index', on: :member
    resources :trackings, only: :index, controller: :trackings
  end

  # Preferences nested under prescriptions
  namespace :prescriptions do
    resource :preferences, only: %i[show update], controller: 'prescription_preferences'
  end
end
```

### Rx Client Library (`lib/rx/`)
Client for interacting with MHV (My HealtheVet) Pharmacy API:

**Core Files:**
- `lib/rx/client.rb` - Main Rx client with all API operations
- `lib/rx/configuration.rb` - Faraday configuration for Rx endpoints
- `lib/rx/client_session.rb` - Session management for MHV authentication
- `lib/rx/middleware/response/rx_parser.rb` - Response parsing middleware
- `lib/rx/middleware/response/rx_raise_error.rb` - Custom error handling middleware
- `lib/rx/middleware/response/rx_failed_station.rb` - Station failure detection middleware
- `lib/rx/rx_gateway_timeout.rb` - Custom timeout exception

**Key Client Methods:**

```ruby
# Prescription Retrieval
client.get_active_rxs                    # Get active prescriptions (Prescription model)
client.get_active_rxs_with_details       # Get active prescriptions (PrescriptionDetails model)
client.get_history_rxs                   # Get all prescriptions (Prescription model)
client.get_all_rxs                       # Get all prescriptions with details (PrescriptionDetails model)
client.get_rx(id)                        # Get single prescription (from history)
client.get_rx_details(id)                # Get single prescription with full details

# Refills
client.post_refill_rx(id)                # Refill single prescription
client.post_refill_rxs(ids)              # Refill multiple prescriptions

# Tracking
client.get_tracking_rx(id)               # Get current tracking for prescription
client.get_tracking_history_rx(id)       # Get full tracking history

# Documentation
client.get_rx_documentation(ndc)         # Get medication documentation by NDC

# Preferences
client.get_preferences                   # Get email/notification preferences
client.post_preferences(params)          # Update preferences
```

### Rx Response Parser Middleware (`lib/rx/middleware/response/rx_parser.rb`)

**Purpose:**
Faraday middleware that normalizes MHV Pharmacy API responses into a consistent format. Handles different response types from the MHV API.

**Response Envelope Structure:**
```ruby
{
  data: <normalized_response_data>,
  errors: <extracted_errors>,
  metadata: <extracted_metadata>
}
```

**Key Responsibilities:**

1. **Content-Type Detection**
   - Only processes JSON responses
   - Skips POST responses (refills return no body on success)

2. **Response Type Detection & Normalization**
   - **Prescription Lists** - Detects by `:prescription_list` key
   - **Medication Lists** - Detects by `:medication_list` key (detailed endpoint)
   - **Prescriptions** - Detects by `:prescription` key (single item)
   - **Tracking Objects** - Detects by `:tracking_info_list` key
   - **Documentation** - Detects by `:html` key

3. **Metadata Extraction (`split_meta_fields!`)**
   - Extracts `:sort`, `:filter`, `:pagination` from response
   - Removes metadata from data payload

4. **Error Extraction**
   - Extracts `:errors` key from response body
   - Places errors in response envelope

**Usage in Rx::Configuration:**
```ruby
# Registered as Faraday middleware
Faraday::Response.register_middleware rx_parser: Rx::Middleware::Response::RxParser

# Applied in Faraday connection stack
conn.response :rx_parser
```

**When Working with Responses:**
- Expect all Rx::Client responses to have `data`, `errors`, `metadata` structure
- POST refill operations return no body on success
- Check `errors` key for API-level errors
- Check `metadata` key for pagination/filtering info

---

## 🎯 Prescriptions Models

### Prescription Model (`app/models/prescription.rb`)

**Purpose:** Basic prescription data model used by legacy endpoints.

**Key Attributes:**
```ruby
:prescription_id              # Unique ID
:prescription_name            # Medication name
:prescription_number          # RX number
:prescription_image           # Image URL (if available)
:refill_status               # Status (Active, Expired, Discontinued, etc.)
:refill_submit_date          # When refill was requested
:refill_date                 # When refill was last filled
:refill_remaining            # Number of refills left
:facility_name               # VA facility name
:facility_api_name           # Facility API identifier
:ordered_date                # When prescription was ordered
:quantity                    # Quantity prescribed
:expiration_date             # Expiration date
:sig                         # Prescription instructions
:dispensed_date              # When prescription was dispensed
:station_number              # VA station number
:is_refillable               # Boolean - can be refilled
:is_trackable                # Boolean - has tracking info
:cmop_division_phone         # Phone number for CMOP
:metadata                    # Additional metadata
```

**Filterable Attributes:**
- `prescription_id` - eq, not_eq
- `refill_status` - eq, not_eq
- `refill_submit_date` - eq, not_eq
- `facility_name` - eq, not_eq
- `expiration_date` - eq, lteq, gteq
- `is_refillable` - eq, not_eq
- `is_trackable` - eq, not_eq

**Default Sorting:** `prescription_name: :asc`

**Helper Methods:**
```ruby
prescription.refillable?      # Alias for is_refillable
prescription.trackable?       # Alias for is_trackable
```

### PrescriptionDetails Model (`app/models/prescription_details.rb`)

**Purpose:** Extended prescription data model with additional fields from detailed API endpoint.

**Inherits from:** `Prescription`

**Additional Attributes:**
- Extended tracking information
- Additional pharmacy details
- Enhanced status information

**Usage:** Used by `get_all_rxs` and `get_rx_details` client methods.

### PrescriptionPreference Model (`app/models/prescription_preference.rb`)

**Purpose:** User's email notification preferences for prescriptions.

**Attributes:**
```ruby
:email_address               # Email for notifications
:rx_flag                     # Boolean - enable/disable notifications
```

**Validations:**
```ruby
validates :rx_flag, inclusion: { in: [true, false] }
validates :email_address,
  presence: true,
  format: { with: VAProfile::Models::Email::VALID_EMAIL_REGEX },
  length: { maximum: 255, minimum: 6 }
```

**Key Methods:**
```ruby
preference = PrescriptionPreference.new(params)
preference.valid?            # Run validations
preference.mhv_params        # Convert to MHV API format
preference.id                # SHA256 digest of attributes
```

### PrescriptionDocumentation Model (`app/models/prescription_documentation.rb`)

**Purpose:** Medication documentation and drug information.

**Attributes:**
```ruby
:html                        # HTML content of medication documentation
```

**Usage:** Retrieved using NDC (National Drug Code) from prescription details.

### Tracking Model (`app/models/tracking.rb`)

**Purpose:** Prescription shipment tracking information.

**Attributes:**
```ruby
:tracking_number             # Carrier tracking number
:prescription_id             # Associated prescription ID
:prescription_number         # Prescription number
:prescription_name           # Medication name
:facility_name               # Shipping facility
:rx_info_phone_number        # Contact phone number
:ndc_number                  # National Drug Code
:shipped_date                # Date prescription was shipped
:delivery_service            # Carrier service (e.g., USPS, UPS)
```

**Usage:** Retrieved for prescriptions that have `is_trackable: true`. Provides shipment tracking history and current delivery status.

---

## 🔧 Common Patterns

### Controller Pattern for Prescriptions

```ruby
module MyHealth
  module V1
    class PrescriptionsController < RxController
      include Filterable
      include MyHealth::PrescriptionHelper::Filtering
      include MyHealth::PrescriptionHelper::Sorting
      include MyHealth::RxGroupingHelper

      # GET /my_health/v1/prescriptions
      # Supports filtering, sorting, pagination
      # @param refill_status [String] Filter by refill status
      # @param page [Integer] Page number
      # @param per_page [Integer] Items per page
      # @param sort [Array<String>] Sort attributes (prefix with - for desc)
      def index
        resource = collection_resource
        recently_requested = get_recently_requested_prescriptions(resource.data)
        raw_data = resource.data.dup
        resource.records = resource_data_modifications(resource)

        filter_count = set_filter_metadata(resource.data, raw_data)
        resource = apply_filters(resource) if params[:filter].present?
        resource = apply_sorting(resource, params[:sort])
        resource.records = sort_prescriptions_with_pd_at_top(resource.records)
        is_using_pagination = params[:page].present? || params[:per_page].present?
        resource.records = params[:include_image].present? ? fetch_and_include_images(resource.data) : resource.data
        resource = resource.paginate(**pagination_params) if is_using_pagination
        options = { meta: resource.metadata.merge(filter_count).merge(recently_requested:) }
        options[:links] = pagination_links(resource) if is_using_pagination

        # Log unique user event for prescriptions accessed
        UniqueUserEvents.log_event(
          user: current_user,
          event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED
        )

        render json: MyHealth::V1::PrescriptionDetailsSerializer.new(resource.records, options)
      end

      # GET /my_health/v1/prescriptions/:id
      def show
        id = params[:id].try(:to_i)
        resource = get_single_rx_from_grouped_list(collection_resource.data, id)
        raise Common::Exceptions::RecordNotFound, id if resource.blank?

        options = { meta: client.get_rx_details(id).metadata }
        render json: MyHealth::V1::PrescriptionDetailsSerializer.new(resource, options)
      end

      # PATCH /my_health/v1/prescriptions/:id/refill
      def refill
        client.post_refill_rx(params[:id])

        # Log unique user event for prescription refill requested
        UniqueUserEvents.log_event(
          user: current_user,
          event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED
        )

        head :no_content
      end

      # PATCH /my_health/v1/prescriptions/refill_prescriptions
      # Batch refill multiple prescriptions
      def refill_prescriptions
        ids = params[:ids]
        successful_ids = []
        failed_ids = []
        ids.each do |id|
          client.post_refill_rx(id)
          successful_ids << id
        rescue => e
          Rails.logger.debug { "Error refilling prescription with ID #{id}: #{e.message}" }
          failed_ids << id
        end
        render json: { successful_ids:, failed_ids: }
      end

      # GET /my_health/v1/prescriptions/list_refillable_prescriptions
      def list_refillable_prescriptions
        resource = collection_resource
        recently_requested = get_recently_requested_prescriptions(resource.data)
        resource.records = filter_data_by_refill_and_renew(resource.data)

        options = { meta: resource.metadata.merge(recently_requested:) }
        render json: MyHealth::V1::PrescriptionDetailsSerializer.new(resource.data, options)
      end
    end
  end
end
```

### Prescription Preferences Pattern

```ruby
module MyHealth
  module V1
    class PrescriptionPreferencesController < RxController
      # GET /my_health/v1/prescriptions/preferences
      def show
        resource = client.get_preferences
        render json: PrescriptionPreferenceSerializer.new(resource)
      end

      # PUT /my_health/v1/prescriptions/preferences
      def update
        resource = client.post_preferences(params.permit(:email_address, :rx_flag))
        render json: PrescriptionPreferenceSerializer.new(resource)
      end
    end
  end
end
```

### Prescription Documentation Pattern

```ruby
module MyHealth
  module V1
    class PrescriptionDocumentationController < RxController
      # GET /my_health/v1/prescriptions/:id/documentation
      def index
        id = params[:id]
        rx = client.get_rx_details(id)
        raise StandardError, 'Rx not found' if rx.nil?
        raise StandardError, 'Missing NDC number' if rx.cmop_ndc_value.nil?

        documentation = client.get_rx_documentation(rx.cmop_ndc_value)
        prescription_documentation = PrescriptionDocumentation.new({ html: documentation[:data] })
        render json: PrescriptionDocumentationSerializer.new(prescription_documentation)
      rescue => e
        render json: { error: "Unable to fetch documentation: #{e}" }, status: :service_unavailable
      end
    end
  end
end
```

### Trackings Controller Pattern

```ruby
module MyHealth
  module V1
    class TrackingsController < RxController
      # GET /my_health/v1/prescriptions/:prescription_id/trackings
      # Retrieves tracking history for a shipped prescription
      # @param prescription_id [String] Prescription ID (from route)
      # @param page [Integer] Page number for pagination
      # @param per_page [Integer] Items per page
      # @param sort [String] Sort attribute (e.g., 'shipped_date' or '-shipped_date' for desc)
      def index
        resource = client.get_tracking_history_rx(params[:prescription_id])
        resource = resource.sort(params[:sort])
        resource = resource.paginate(**pagination_params)

        links = pagination_links(resource)
        options = { meta: resource.metadata, links: }
        render json: TrackingSerializer.new(resource.data, options)
      end
    end
  end
end
```

### Rx Client Usage Pattern

```ruby
# Initialize client with session (automatic via RxController#client)
client = Rx::Client.new(
  session: { user_id: current_user.mhv_correlation_id },
  upstream_request: request
)

# Fetch all prescriptions
prescriptions = client.get_all_rxs

# Fetch single prescription
prescription = client.get_rx_details(prescription_id)

# Refill prescription
client.post_refill_rx(prescription_id)

# Batch refill
client.post_refill_rxs([id1, id2, id3])

# Get tracking
tracking = client.get_tracking_rx(prescription_id)

# Get preferences
preferences = client.get_preferences

# Update preferences
client.post_preferences(email_address: 'user@example.com', rx_flag: true)
```

### Testing Pattern with VCR

```ruby
RSpec.describe 'MyHealth::V1::Prescriptions', type: :request do
  let(:user) { build(:user, :mhv, mhv_correlation_id: '12345') }
  let(:prescription_id) { 1_234_567 }

  before do
    sign_in_as(user)
  end

  describe 'GET /my_health/v1/prescriptions' do
    context 'when prescriptions exist' do
      it 'returns prescription list' do
        VCR.use_cassette('rx_client/prescriptions/get_all_rxs') do
          get '/my_health/v1/prescriptions'

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('prescriptions')
        end
      end

      it 'logs unique user event' do
        VCR.use_cassette('rx_client/prescriptions/get_all_rxs') do
          expect(UniqueUserEvents).to receive(:log_event).with(
            user: user,
            event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED
          )

          get '/my_health/v1/prescriptions'
        end
      end
    end

    context 'with filtering' do
      it 'filters by refill_status' do
        VCR.use_cassette('rx_client/prescriptions/get_active_rxs') do
          get '/my_health/v1/prescriptions', params: { filter: { refill_status: { eq: 'active' } } }

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with pagination' do
      it 'paginates results' do
        VCR.use_cassette('rx_client/prescriptions/get_all_rxs_paginated') do
          get '/my_health/v1/prescriptions', params: { page: 1, per_page: 10 }

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['links']).to be_present
        end
      end
    end
  end

  describe 'GET /my_health/v1/prescriptions/:id' do
    it 'returns single prescription' do
      VCR.use_cassette('rx_client/prescriptions/get_rx_details') do
        get "/my_health/v1/prescriptions/#{prescription_id}"

        expect(response).to have_http_status(:ok)
      end
    end

    it 'returns 404 when prescription not found' do
      VCR.use_cassette('rx_client/prescriptions/get_rx_not_found') do
        get '/my_health/v1/prescriptions/99999'

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /my_health/v1/prescriptions/:id/refill' do
    it 'refills prescription' do
      VCR.use_cassette('rx_client/prescriptions/post_refill_rx') do
        patch "/my_health/v1/prescriptions/#{prescription_id}/refill"

        expect(response).to have_http_status(:no_content)
      end
    end

    it 'logs unique user event' do
      VCR.use_cassette('rx_client/prescriptions/post_refill_rx') do
        expect(UniqueUserEvents).to receive(:log_event).with(
          user: user,
          event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED
        )

        patch "/my_health/v1/prescriptions/#{prescription_id}/refill"
      end
    end
  end

  describe 'GET /my_health/v1/prescriptions/preferences' do
    it 'returns preferences' do
      VCR.use_cassette('rx_client/preferences/get_preferences') do
        get '/my_health/v1/prescriptions/preferences'

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['attributes']).to include('email_address', 'rx_flag')
      end
    end
  end

  describe 'PUT /my_health/v1/prescriptions/preferences' do
    let(:preference_params) do
      { email_address: 'test@example.com', rx_flag: true }
    end

    it 'updates preferences' do
      VCR.use_cassette('rx_client/preferences/post_preferences') do
        put '/my_health/v1/prescriptions/preferences', params: preference_params

        expect(response).to have_http_status(:ok)
      end
    end

    it 'validates email format' do
      VCR.use_cassette('rx_client/preferences/invalid_email') do
        put '/my_health/v1/prescriptions/preferences', params: { email_address: 'invalid', rx_flag: true }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /my_health/v1/prescriptions/:prescription_id/trackings' do
    let(:prescription_id) { 1_234_567 }

    it 'returns tracking history' do
      VCR.use_cassette('rx_client/tracking/get_tracking_history_rx') do
        get "/my_health/v1/prescriptions/#{prescription_id}/trackings"

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']).to be_an(Array)
      end
    end

    context 'with pagination' do
      it 'paginates tracking results' do
        VCR.use_cassette('rx_client/tracking/get_tracking_history_paginated') do
          get "/my_health/v1/prescriptions/#{prescription_id}/trackings", params: { page: 1, per_page: 5 }

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['links']).to be_present
        end
      end
    end

    context 'with sorting' do
      it 'sorts by shipped_date descending' do
        VCR.use_cassette('rx_client/tracking/get_tracking_history_sorted') do
          get "/my_health/v1/prescriptions/#{prescription_id}/trackings", params: { sort: '-shipped_date' }

          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
```

### VSCode Snippets for Rx Development

**Speed up development with built-in code snippets:**

#### `rx_client` - Rx Client Call
Type `rx_client` + Tab to generate Rx client initialization and method call:

```ruby
rx_client = Rx::Client.new(session: { user_id: user.mhv_correlation_id }, upstream_request: request)
response = rx_client.get_all_rxs
```

#### `rx_vcr` - Rx Client with VCR
Type `rx_vcr` + Tab to generate VCR-wrapped Rx client test:

```ruby
VCR.use_cassette('rx_client/endpoint') do
  rx_client = Rx::Client.new(session: { user_id: user.mhv_correlation_id })
  response = rx_client.method(params)
  # test assertions
end
```

**Common Rx Client Methods:**
- `get_all_rxs` - Get all prescriptions with details
- `get_active_rxs_with_details` - Get active prescriptions
- `get_rx_details(id)` - Get single prescription
- `post_refill_rx(id)` - Refill prescription
- `get_tracking_rx(id)` - Get tracking info
- `get_preferences` - Get notification preferences

#### `flipper_stub` - Feature Flag Stub
Type `flipper_stub` + Tab to correctly stub Flipper in tests (never use `Flipper.enable!`):

```ruby
allow(Flipper).to receive(:enabled?).with(:feature_name).and_return(true)
```

---

## ⚙️ Feature Flags

### Prescriptions Feature Flags


## 🔐 Authentication & Authorization

### Authorization Policy (`app/policies/mhv_prescriptions_policy.rb`)

The `MHVPrescriptionsPolicy` controls access to Prescriptions features using a Struct-based policy pattern:

```ruby
MHVPrescriptionsPolicy = Struct.new(:user, :mhv_prescriptions) do
  RX_ACCESS_LOG_MESSAGE = 'RX ACCESS DENIED'

  def access?
    return true if user.loa3? && (mhv_user_account&.patient || mhv_user_account&.champ_va)

    log_access_denied(RX_ACCESS_LOG_MESSAGE)
    false
  end

  private

  def mhv_user_account
    user.mhv_user_account(from_cache_only: false)
  end

  def log_access_denied(message)
    Rails.logger.info(message,
                      mhv_id: user.mhv_correlation_id.presence || 'false',
                      sign_in_service: user.identity.sign_in[:service_name],
                      va_facilities: user.va_treatment_facility_ids.length,
                      va_patient: user.va_patient?)
  end
end
```

**Access Requirements:**

1. **LOA3:** User must be LOA3 (identity verified)
2. **Account Type:** User must have `patient` or `champ_va` account type

**Usage in Controllers:**
```ruby
# In RxController
def authorize
  raise_access_denied unless current_user.authorize(:mhv_prescriptions, :access?)
end

def raise_access_denied
  raise Common::Exceptions::Forbidden, detail: 'You do not have access to prescriptions'
end
```

### MHV Session Management

**All Rx controllers inherit from `RxController`:**
```ruby
module MyHealth
  class RxController < ApplicationController
    include MyHealth::MHVControllerConcerns
    include JsonApiPaginationLinks
    service_tag 'mhv-medications'

    protected

    def client
      @client ||= Rx::Client.new(
        session: { user_id: current_user.mhv_correlation_id },
        upstream_request: request
      )
    end

    def authorize
      raise_access_denied unless current_user.authorize(:mhv_prescriptions, :access?)
    end

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to prescriptions'
    end
  end
end
```

**Key Points:**
- User must have MHV correlation ID (`current_user.mhv_correlation_id`)
- Authorization check happens via `MHVPrescriptionsPolicy#access?`
- Session passed to Rx::Client with `user_id`
- Upstream request passed for StatsD tagging
- Client handles MHV API authentication internally

---

## 📝 Error Handling

### Common Error Scenarios

**Record Not Found:**
```ruby
raise Common::Exceptions::RecordNotFound, prescription_id if resource.blank?
# Returns 404 Not Found
```

**Validation Errors (Preferences):**
```ruby
raise Common::Exceptions::ValidationErrors, preference unless preference.valid?
# Returns 422 Unprocessable Entity with validation errors
```

**MHV API Errors:**
```ruby
rescue Faraday::TimeoutError => e
  Rails.logger.error("MHV Rx: Timeout for user #{current_user.icn}")
  render json: { error: { code: 'MHV_TIMEOUT', message: 'Service temporarily unavailable' } },
         status: :gateway_timeout

rescue Faraday::ClientError => e
  Rails.logger.error("MHV Rx: Client error - #{e.message}")
  render json: { error: { code: 'MHV_ERROR', message: 'Unable to process request' } },
         status: :bad_gateway
```

**Custom Timeout Exception:**
```ruby
rescue Rx::RxGatewayTimeout => e
  Rails.logger.error("Prescription API timeout for user #{current_user.icn}")
  render json: { error: { code: 'RX_GATEWAY_TIMEOUT', message: 'Pharmacy service unavailable' } },
         status: :gateway_timeout
```

**Batch Refill Errors:**
```ruby
# Partial failure handling - continue processing remaining items
ids.each do |id|
  client.post_refill_rx(id)
  successful_ids << id
rescue => e
  Rails.logger.debug { "Error refilling prescription with ID #{id}: #{e.message}" }
  failed_ids << id
end
render json: { successful_ids:, failed_ids: }
```

**Never Log PII:**
- ❌ Don't log: prescription names, patient addresses, phone numbers
- ✅ Do log: `user.icn`, prescription IDs, refill status codes, error types

---

## 🧪 Testing Guidelines

### Test Structure for Prescriptions Features

**Request Specs:**
- Location: `modules/my_health/spec/requests/my_health/v1/`
- Use VCR cassettes for Rx client responses
- Test all HTTP status codes: 200, 204, 404, 422, 503
- Test authentication requirements
- Test filtering, sorting, and pagination
- Test unique user event logging

**Model Specs:**
- Location: `spec/models/`
- Test validations (PrescriptionPreference)
- Test filterable attributes (Prescription)
- Test helper methods (refillable?, trackable?)

**Client Specs:**
- Location: `spec/lib/rx/`
- Test individual Rx::Client methods
- Use VCR cassettes for MHV API responses
- Test error handling and timeouts

### VCR Cassette Naming Convention

```
spec/fixtures/vcr_cassettes/rx_client/
  ├── session/
  │   └── mhv_session.yml
  ├── prescriptions/
  │   ├── get_all_rxs.yml
  │   ├── get_active_rxs.yml
  │   ├── get_rx_details.yml
  │   ├── get_rx_not_found.yml
  │   ├── post_refill_rx.yml
  │   └── post_refill_rxs.yml
  ├── tracking/
  │   ├── get_tracking_rx.yml
  │   └── get_tracking_history_rx.yml
  ├── documentation/
  │   └── get_rx_documentation.yml
  └── preferences/
      ├── get_preferences.yml
      └── post_preferences.yml
```

---

## 📊 Monitoring & Logging

### StatsD Metrics

The Rx::Client automatically tracks:
- `api.mhv.rxrefill.refills.requested` - Refill requests (count)
  - Tagged with `source_app` when upstream request available

### Datadog Tracing (Recommended Addition)

```ruby
def refill
  Datadog::Tracing.trace('mhv.prescriptions.refill') do |span|
    span.set_tag('user.icn', current_user.icn)
    span.set_tag('prescription.id', params[:id])

    client.post_refill_rx(params[:id])

    UniqueUserEvents.log_event(
      user: current_user,
      event_name: UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED
    )

    head :no_content
  end
end
```

### Unique User Events

Prescription events tracked:
- `UniqueUserEvents::EventRegistry::PRESCRIPTIONS_ACCESSED` - User viewed prescriptions list
- `UniqueUserEvents::EventRegistry::PRESCRIPTIONS_REFILL_REQUESTED` - User requested refill

---

## 🚨 Common Issues & Solutions

### Issue: Refill fails with status mismatch
**Solution:** Check prescription `is_refillable` status. Not all prescriptions can be refilled (expired, discontinued, etc.). Validate `refillable?` before attempting refill.

### Issue: VCR cassette not found in tests
**Solution:** Verify cassette path matches naming convention. May need to record new cassette by temporarily allowing HTTP connections.

### Issue: MHV session timeout
**Solution:** Rx::Client handles session refresh automatically. If issues persist, check MHV API status.

### Issue: Preferences validation fails
**Solution:** Ensure email format matches `VAProfile::Models::Email::VALID_EMAIL_REGEX` and `rx_flag` is boolean (true/false).

### Issue: Missing prescription documentation
**Solution:** Not all prescriptions have documentation. Check if `cmop_ndc_value` exists before calling `get_rx_documentation`.

### Issue: Tracking not available
**Solution:** Check `is_trackable` attribute. Not all prescriptions have tracking info (only shipped prescriptions).

### Issue: Batch refill partial failures
**Solution:** This is expected behavior. Return both `successful_ids` and `failed_ids` arrays. Log failed refills for investigation but don't fail entire request.

---

## 📖 Additional Resources

For general vets-api patterns and guidelines, see:
- [.github/copilot-instructions.md](../copilot-instructions.md) - General repository patterns
- [.github/instructions/my-health-messaging.instructions.md](./my-health-messaging.instructions.md) - Secure Messaging patterns (similar module)
- [.github/instructions/my-health-medical-records.instructions.md](./my-health-medical-records.instructions.md) - Medical Records patterns (similar module)
- [.vscode/copilot-examples.md](../../.vscode/copilot-examples.md) - Code examples

---

## 🔄 Maintaining These Instructions

### When to Update This File

**This instruction file should be updated when changes to `applyTo` files impact:**
- API contracts (request/response formats, endpoints, parameters)
- Controller patterns (before_actions, error handling, filtering/sorting)
- Model validations or attributes
- Client methods or signatures
- Serializer structure or attributes
- Route definitions
- Feature flag usage patterns (especially authorization policy)
- Authentication/authorization requirements
- Refill workflows or batch operations
- Tracking or documentation retrieval patterns

**Analyze changes for impact:**
1. **New endpoints or actions** → Update Routes section and Controller examples
2. **New prescription attributes** → Update Models section with new attributes
3. **New Rx::Client methods** → Update Client Library section with method signatures
4. **New serializers or attributes** → Update Serializers section
5. **New feature flags** → Update Feature Flags section with usage patterns
6. **Changed validation rules** → Update Models section and testing examples
7. **Changed error handling** → Update Error Handling section
8. **New controller patterns (filtering, sorting)** → Update Common Patterns section
9. **Authentication changes** → Update Authentication & Authorization section
10. **New unique user events** → Update Monitoring & Logging section
11. **Batch operation changes** → Update refill_prescriptions pattern examples

**Changes that DON'T require updates:**
- Internal implementation details that don't affect usage patterns
- Refactoring that maintains the same public interface
- Bug fixes that don't change behavior
- Performance optimizations without API changes
- Code style or formatting changes

**How to Keep Instructions Current:**
- Review this file when making significant changes to Prescriptions features
- Update code examples to match current patterns in the codebase
- Remove deprecated patterns and add new best practices
- Keep VCR cassette examples aligned with actual test structure
- Verify feature flag documentation matches current implementation
- Update unique user event names if they change

---

**These path-specific instructions automatically apply when working on My Health/Prescriptions features.**
