# Unified Health Data (UHD) Service

The Unified Health Data service provides a unified interface to retrieve health data from multiple VA systems, including VistA and Oracle Health (formerly Cerner). This service consolidates data from different sources into consistent models that can be consumed by VA.gov applications.

## Architecture

```
lib/unified_health_data/
├── README.md                    # This file
├── service.rb                   # Main service class
├── client.rb                   # Main client class
├── configuration.rb             # Service configuration
├── reference_range_formatter.rb # Lab result formatting utilities
├── models/                      # Data models using Vets::Model
│   ├── clinical_notes.rb       # Clinical notes model
│   ├── condition.rb             # Condition model
│   ├── lab_or_test.rb          # Lab results and tests model
│   └── prescription.rb         # Prescription model
├── adapters/                    # Data source adapters
│   ├── clinical_notes_adapter.rb          # Clinical notes parser 
│   ├── conditions_adapter.rb          # Conditions parser 
│   ├── labs_or_test_adapter.rb          # Labs and tests parser
│   ├── prescriptions_adapter.rb           # Main prescription parser
│   ├── vista_prescription_adapter.rb      # VistA medication parser
│   └── oracle_health_prescription_adapter.rb # Oracle Health FHIR parser
├── serializers/                # API response serializers
│   ├── clinical_notes_serializer.rb       # Clinical notes serialization
│   ├── conditions_serializer.rb          # Conditions serialization 
│   ├── labs_or_test_serializer.rb          # Labs and tests serialization
│   ├── prescriptions_serializer.rb           # Main prescription serialization
│   └── prescriptions_refills_serializer.rb     # Prescription refills serialization
└── logging.rb                  # Logging utilities
```

## Available Methods

### UnifiedHealthData::Service

The main service class provides the following public methods:

- `get_labs(start_date:, end_date:)` - Retrieve lab results for date range
- `get_care_summaries_and_notes` - Retrieve clinical notes and care summaries
- `get_prescriptions` - Retrieve prescriptions from all data sources
- `refill_prescription(prescription_ids)` - Submit prescription refill requests
- `get_single_summary_or_note(note_id)` - Retrieve a single clinical note by ID

## Data Sources

### VistA (Veterans Health Information Systems and Technology Architecture)
- Legacy VA system containing historical health records
- JSON-based API responses via `/v1/medicalrecords/medications` endpoint
- Medication data in `vista.medicationList.medication[]`
- Includes facility transition status (`inCernerTransition`)

### Oracle Health (formerly Cerner)
- Modern FHIR-compliant health records system  
- FHIR Bundle responses with entry arrays via `/v1/medicalrecords/medications` endpoint
- Medication data as FHIR MedicationRequest resources
- FHIR R4 standard compliance

## Prescription Field Mapping

The prescription adapters map fields from different data sources to a unified model that matches the Mobile API serializer expectations.

### Complete Field Mapping Table

| **Mobile Serializer Field** | **VistA API Field** | **Oracle Health FHIR Field** | **Data Type** | **Notes** |
|------------------------------|---------------------|-------------------------------|---------------|-----------|
| `prescription_id` | `prescriptionId` | `id` | String | Primary identifier |
| `refill_status` | `refillStatus` | `status` (mapped) | String | active, expired, discontinued |
| `refill_submit_date` | `refillSubmitDate` | (not available) | String | Date last refill submitted |
| `refill_date` | `refillDate` | `dispenseRequest.validityPeriod.start` | String | Date of last refill |
| `refill_remaining` | `refillRemaining` | `dispenseRequest.numberOfRepeatsAllowed` | Integer | Number of refills left |
| `facility_name` | `facilityName` | `dispenseRequest.performer.display` | String | Dispensing facility |
| `ordered_date` | `orderedDate` | `authoredOn` | String | Date prescription ordered |
| `quantity` | `quantity` | `dispenseRequest.quantity.value` | String | Quantity dispensed |
| `expiration_date` | `expirationDate` | `dispenseRequest.validityPeriod.end` | String | Prescription expiration |
| `prescription_number` | `prescriptionNumber` | `identifier[].value` | String | Pharmacy prescription number |
| `prescription_name` | `prescriptionName` | `medicationCodeableConcept.text` | String | Medication name |
| `dispensed_date` | `dispensedDate` | `dispenseRequest.initialFill.date` | String | Date medication dispensed |
| `station_number` | `stationNumber` | `dispenseRequest.performer.identifier.value` | String | VA station identifier |
| `is_refillable` | `isRefillable` | (calculated from status + refills) | Boolean | Can prescription be refilled |
| `is_trackable` | `isTrackable` | `false` (default) | Boolean | Can shipment be tracked |
| `instructions` | `sig` | `dosageInstruction[0].text` | String | Patient instructions |
| `facility_phone_number` | `cmopDivisionPhone` | (not available) | String | Pharmacy phone number |
| `disp_status` | `dispStatus` | (not available) | String | Detailed dispensing status from VistA |

### Status Mapping (Oracle Health → Mobile API)

| **FHIR Status** | **Mobile API Status** | **Description** |
|-----------------|----------------------|-----------------|
| `active` | `active` | Prescription is active and available |
| `completed` | `expired` | Prescription has been completed |
| `stopped` | `discontinued` | Prescription was stopped |
| `cancelled` | `discontinued` | Prescription was cancelled |

### Additional VistA Fields Available

The VistA response contains additional fields that are not currently mapped but could be useful:

- `facilityApiName` - API-friendly facility name
- `inCernerTransition` - Whether facility is transitioning to Cerner
- `notRefillableDisplayMessage` - User-friendly refill restriction message
- `providerFirstName`, `providerLastName` - Prescribing provider
- `divisionName` - VA division name
- `ndc` - National Drug Code
- `category` - Medication category (e.g., "Rx Medication")
- `orderableItem` - Orderable item name
- `shape`, `color`, `frontImprint`, `backImprint` - Physical pill description

## Usage Examples

### Basic Prescription Retrieval

```ruby
# Initialize service for a user
service = UnifiedHealthData::Service.new(current_user)

# Get prescriptions
prescriptions = service.get_prescriptions
# Returns array of UnifiedHealthData::Prescription objects

# Access prescription data
prescriptions.each do |prescription|
  puts "#{prescription.prescription_name} - #{prescription.refill_remaining} refills left"
  puts "Instructions: #{prescription.sig}"
  puts "Refillable: #{prescription.is_refillable}"
end
```

### Prescription Refill

```ruby
# Refill specific prescriptions
prescription_ids = ['12345', '67890']
result = service.refill_prescription(prescription_ids)

# Handle success and failures
result[:success].each do |success|
  puts "Successfully submitted refill for prescription #{success[:id]}"
end

result[:failed].each do |failure|
  puts "Failed to refill #{failure[:id]}: #{failure[:error]}"
end
```

### Controller Integration

```ruby
class PrescriptionsController < ApplicationController
  before_action :authenticate_user!

  def index
    service = UnifiedHealthData::Service.new(current_user)
    
    prescriptions = service.get_prescriptions
    
    # Use existing Mobile serializer for consistency
    render json: prescriptions, 
           each_serializer: Mobile::V0::PrescriptionsSerializer
  end

  def refill
    service = UnifiedHealthData::Service.new(current_user)
    prescription_ids = refill_params[:prescriptions].map { |p| p[:id] }
    
    result = service.refill_prescription(prescription_ids)
    render json: result
  end

  private

  def refill_params
    params.permit(prescriptions: [:id])
  end
end
```

## Authentication

The service handles authentication automatically by:
1. Using the user's ICN (Integration Control Number) as the patient identifier
2. Fetching access tokens from the security endpoint using configured credentials
3. Adding required headers (`Authorization`, `x-api-key`) to all requests

Users must have a valid ICN for the service to function properly.

## Error Handling

The service includes comprehensive error handling:

### Service-Level Errors
- Network timeouts and connection failures via circuit breaker
- Authentication/authorization errors with custom UHD error prefix
- Invalid response formats with JSON parsing fallbacks
- Prescription refill failures with graceful degradation

### Adapter-Level Errors
- Malformed data from individual sources
- Missing required fields with safe defaults
- Type conversion errors
- FHIR resource parsing errors

### Logging
- StatsD metrics with `api.uhd` prefix for monitoring
- Structured logging with service context
- Test code distribution analytics for lab results
- Error logging excludes PII/PHI data

All errors are logged with appropriate context for debugging while returning graceful fallbacks to prevent user-facing failures.

## Data Source System Tracking

Each prescription model includes a `data_source_system` attribute to track origin:
- `"VISTA"` - Data from VistA system
- `"ORACLE_HEALTH"` - Data from Oracle Health/Cerner system

This enables analytics and debugging of data source-specific issues.

## Method Aliases

The Prescription model provides aliases to match Mobile API serializer expectations:
- `refillable?` → `is_refillable`
- `trackable?` → `is_trackable`
- `sig` → `instructions`
- `cmop_division_phone` → `facility_phone_number`

## Performance Considerations

- The service fetches data from multiple systems concurrently when possible
- Response caching is handled at the API gateway level
- Large responses are streamed to prevent memory issues
- Monitoring and metrics are collected via StatsD integration with `api.uhd` prefix

## Configuration

The service uses `UnifiedHealthData::Configuration` for:
- API endpoints (`Settings.mhv.uhd.host`) and authentication
- Security token endpoint (`Settings.mhv.uhd.security_host`)
- API credentials (`app_id`, `app_token`, `x_api_key`)
- Mock responses via betamocks
- Circuit breaker configuration
- Custom error handling with UHD prefix

## Testing

Each component includes comprehensive test coverage:
- Unit tests for models and adapters in `spec/lib/unified_health_data/`
- Integration tests for the full service
- VCR cassettes for external API responses
- Mock data matching actual API response formats
- Error condition testing

For testing individual components:

```ruby
# Test model creation
prescription = UnifiedHealthData::Prescription.new({
  id: '12345',
  type: 'Prescription',
  prescription_name: 'Test Drug',
  refill_remaining: 3,
  is_refillable: true,
  instructions: 'Take as directed'
})

# Test adapter parsing - VistA
vista_adapter = UnifiedHealthData::Adapters::VistaPrescriptionAdapter.new
result = vista_adapter.parse(vista_medication_data)

# Test adapter parsing - Oracle Health
oracle_adapter = UnifiedHealthData::Adapters::OracleHealthPrescriptionAdapter.new
result = oracle_adapter.parse(fhir_medication_request)

# Test clinical notes adapter 
notes_adapter = UnifiedHealthData::Adapters::ClinicalNotesAdapter.new
result = notes_adapter.parse(document_reference_data)
```

## Running the API locally

In order to run the API locally, you can bypass authentication by adding a stub `test_user` and skipping authentication in the controller you are testing.

For example, if you want to test the `labs_and_tests_controller` in the `my_health` module (`modules/my_health/app/controllers/my_health/v2/labs_and_tests_controller.rb`), it would look like this:

```ruby
module MyHealth
  module V2
    class LabsAndTestsController < ApplicationController
      service_tag 'mhv-medical-records'

      skip_before_action :authenticate # Add this

      def index
        start_date = params[:start_date]
        end_date = params[:end_date]
        labs = service.get_labs(start_date:, end_date:)
        serialized_labs = UnifiedHealthData::LabOrTestSerializer.new(labs).serializable_hash[:data]
        render json: serialized_labs,
               status: :ok
      end

      private

      def service
      # Add a test user
        test_user = OpenStruct.new( 
          mhv_correlation_id: REDACTED, # Get the MHV ID of a test user
          icn: 'REDACTED', # Get the ICN of a test user
          edipi: '10000000',
          last_name: 'Tester',
          uuid: '12345',
          flipper_id: '12345'
        )
        # Instantiate the service with your `test_user` rather than the `@current_user`
        UnifiedHealthData::Service.new(test_user)
      end
    end
  end
end
```

You can then hit the expected endpoint (either in the browser or from a locally running vets-website). If using betamocks in the `vets-api-mockdata` repo, ensure you have a `default.yml` response added.
