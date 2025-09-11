# Unified Health Data (UHD) Service

The Unified Health Data service provides a unified interface to retrieve health data from multiple VA systems, including VistA and Oracle Health (formerly Cerner). This service consolidates data from different sources into consistent models that can be consumed by VA.gov applications.

## Architecture

```
lib/unified_health_data/
├── README.md                    # This file
├── service.rb                   # Main service class
├── configuration.rb             # Service configuration
├── reference_range_formatter.rb # Lab result formatting utilities
├── models/                      # Data models using Vets::Model
│   ├── clinical_notes.rb       # Clinical notes model
│   ├── lab_or_test.rb          # Lab results and tests model
│   ├── prescription.rb         # Prescription model
│   └── prescription_attributes.rb # Prescription attributes
├── adapters/                    # Data source adapters
│   ├── clinical_notes_adapter.rb          # Clinical notes parser
│   ├── prescriptions_adapter.rb           # Main prescription parser
│   ├── vista_prescription_adapter.rb      # VistA medication parser
│   └── oracle_health_prescription_adapter.rb # Oracle Health FHIR parser
└── serializers/                # Optional serializers for API responses
```

## Available Methods

### UnifiedHealthData::Service

The main service class provides the following public methods:

- `get_labs(start_date:, end_date:)` - Retrieve lab results for date range
- `get_care_summaries_and_notes` - Retrieve clinical notes and care summaries
- `get_prescriptions` - Retrieve prescriptions from all data sources
- `refill_prescription(prescription_ids)` - Submit prescription refill requests

## Data Sources

### VistA (Veterans Health Information Systems and Technology Architecture)
- Legacy VA system containing historical health records
- JSON-based API responses
- Medication data in `vista.medicationList.medication[]`

### Oracle Health (formerly Cerner)
- Modern FHIR-compliant health records system
- FHIR Bundle responses with entry arrays
- Medication data as FHIR MedicationRequest resources

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
- `dispStatus` - Detailed dispensing status
- `ndc` - National Drug Code
- `category` - Medication category (e.g., "Rx Medication")
- `orderableItem` - Orderable item name
- `shape`, `color`, `frontImprint`, `backImprint` - Physical pill description

## Usage Examples

### Basic Prescription Retrieval

```ruby
# Initialize service for a user
service = UnifiedHealthData::Service.new(current_user)

# Get all prescriptions
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
    prescription_ids = refill_params[:prescriptions].map { |p| p[:orderId] }
    
    result = service.refill_prescription(prescription_ids)
    render json: result
  end

  private

  def refill_params
    params.permit(prescriptions: [:orderId])
  end
end
```

## Error Handling

The service includes comprehensive error handling:

### Service-Level Errors
- Network timeouts and connection failures
- Authentication/authorization errors
- Invalid response formats

### Adapter-Level Errors
- Malformed data from individual sources
- Missing required fields
- Type conversion errors

All errors are logged with appropriate context for debugging while returning graceful fallbacks to prevent user-facing failures.

## Data Source System Tracking

Each prescription model includes a `data_source_system` attribute to track origin:
- `"VISTA"` - Data from VistA system
- `"ORACLE_HEALTH"` - Data from Oracle Health/Cerner system

This enables analytics and debugging of data source-specific issues.

## Performance Considerations

- The service fetches data from multiple systems concurrently when possible
- Response caching is handled at the API gateway level
- Large responses are streamed to prevent memory issues
- Monitoring and metrics are collected via StatsD integration

## Configuration

The service uses `UnifiedHealthData::Configuration` for:
- API endpoints and authentication
- Timeout settings
- Feature flags for data source selection
- Monitoring configuration

## Testing

Each component includes comprehensive test coverage:
- Unit tests for models and adapters
- Integration tests for the full service
- Mock data matching actual API response formats
- Error condition testing

For testing individual components:

```ruby
# Test model creation
attrs = UnifiedHealthData::PrescriptionAttributes.new({
  prescription_name: 'Test Drug',
  refill_remaining: 3,
  is_refillable: true
})

prescription = UnifiedHealthData::Prescription.new({
  id: '12345',
  type: 'Prescription',
  attributes: attrs
})

# Test adapter parsing
adapter = UnifiedHealthData::Adapters::VistaPrescriptionAdapter.new
result = adapter.parse(vista_medication_data)
```