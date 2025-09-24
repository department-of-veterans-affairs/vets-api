# Form Submission Statuses - Multiple Gateway Implementation

This directory contains the implementation for supporting multiple Form APIs in the VA.gov Form Status feature.

## Architecture Overview

The system now supports multiple Form APIs through a gateway and formatter pattern:

- **Gateways**: Fetch submission data and status information from different Form APIs
- **Formatters**: Transform API responses into a consistent format for the frontend
- **Report**: Coordinates multiple gateways and formatters to provide unified results

## Current Implementations

### Lighthouse Benefits Intake API
- **Gateway**: `Gateways::BenefitsIntakeGateway`
- **Formatter**: `Formatters::BenefitsIntakeFormatter`
- **Forms Supported**: See `restricted_list_of_forms` in controller

## Adding a New Form API

### Step 1: Create Your Gateway

1. Create a new gateway class inheriting from `BaseGateway`:

```ruby
# lib/forms/submission_statuses/gateways/your_api_gateway.rb
class YourApiGateway < BaseGateway
  def submissions
    # Query your form submission model
  end

  def api_statuses(submissions)
    # Call your Form API to get statuses
    # Must return [statuses_data, errors] format
  end
end
```

2. Use the `ExampleGateway` as a template for implementation guidance.

### Step 2: Create Your Formatter

1. Create a new formatter class inheriting from `BaseFormatter`:

```ruby
# lib/forms/submission_statuses/formatters/your_api_formatter.rb
class YourApiFormatter < BaseFormatter
  private

  def merge_record(submission_map, status)
    # Map your API status format to submission objects
  end

  def build_submissions_map(submissions)
    # Create OpenStruct objects with required fields:
    # id, form_type, created_at, updated_at, detail, message, status, pdf_support
  end

  def pdf_supported?(submission)
    # Return true/false for PDF generation support
  end
end
```

2. Use the `ExampleFormatter` as a template for implementation guidance.

### Step 3: Register Your Gateway and Formatter

1. Add your gateway to the `Report` class:

```ruby
# lib/forms/submission_statuses/report.rb
def initialize(user_account:, allowed_forms:)
  @gateways = [
    { service: 'lighthouse_benefits_intake',
      gateway: Gateways::BenefitsIntakeGateway.new(user_account:, allowed_forms:) },
    { service: 'your_service_name',
      gateway: Gateways::YourApiGateway.new(user_account:, allowed_forms:) }
  ]
end
```

2. Add your formatter to the `FORMATTERS` constant:

```ruby
# lib/forms/submission_statuses/report.rb
FORMATTERS = {
  'lighthouse_benefits_intake' => Formatters::BenefitsIntakeFormatter.new,
  'your_service_name' => Formatters::YourApiFormatter.new
}.freeze
```

### Step 4: Decide on Form Restrictions

Choose between:

1. **Restricted approach**: Add your forms to `restricted_list_of_forms` in the controller
2. **Unrestricted approach**: Pass `nil` for `allowed_forms` to show all forms from your API

### Step 5: Add Tests

Create spec files for your implementations:

- `spec/lib/forms/submission_statuses/gateways/your_api_gateway_spec.rb`
- `spec/lib/forms/submission_statuses/formatters/your_api_formatter_spec.rb`

## Required Output Format

All formatters must produce OpenStruct objects with these fields:

```ruby
OpenStruct.new(
  id: "unique_identifier",        # From your Form API
  form_type: "form_number",       # e.g., "21-4142"
  created_at: timestamp,          # When form was submitted
  updated_at: timestamp,          # Last status update (can be nil)
  detail: "status_detail",        # Detailed status info (can be nil)
  message: "status_message",      # User-friendly message (can be nil)
  status: "current_status",       # Status value (can be nil)
  pdf_support: true_or_false      # Whether PDF generation is supported
)
```

## Status Mapping

If your API uses different status values than the standard ones, map them in the frontend:

```javascript
// vets-website/src/applications/personalization/dashboard/helpers.jsx
const SUBMISSION_STATUS_MAP = {
  your_api_status: 'standard_status',
  // ...
};
```

Standard statuses: `DRAFT`, `SUBMISSION IN PROGRESS`, `RECEIVED`, `ACTION NEEDED`

## Testing

Run the submission statuses specs to ensure your implementation works:

```bash
bundle exec rspec spec/lib/forms/submission_statuses/
bundle exec rspec spec/requests/v0/my_va/submission_statuses_spec.rb
```

## Documentation

Update the team implementation tracker in the main documentation with your team's details:

- Team name
- Form API used
- Whether you're the first team for this API
- Restricted vs unrestricted approach
- Forms added
- Epic/ticket links
- Useful notes for future teams
