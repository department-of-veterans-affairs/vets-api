# Burials

## Overview

The Burials module provides a comprehensive platform for processing VA Form 21P-530EZ (Application for Burial Benefits) submissions on VA.gov. This module handles the complete lifecycle of burial benefit claims, from initial form submission through final adjudication, including PDF generation, document uploads, and integration with multiple VA backend services.

The module operates as a Rails Engine within the vets-api ecosystem, providing isolated functionality for burial benefits while maintaining integration points with shared VA.gov services. It supports both authenticated and unauthenticated user submissions, handles complex form validation, and manages secure document transmission to VA claims processing systems.

Key features include automated PDF form filling, Benefits Intake API integration for document submission, comprehensive monitoring and error handling, and support for multiple submission pathways including direct API submission and traditional mail processing workflows.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [API Reference](#api-reference)
- [Testing](#testing)

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Ruby | 3.1+ | Rails application dependency |
| Rails | 7.0+ | Parent application framework |
| PostgreSQL | 12+ | Database with PostGIS |
| Redis | 6+ | Background job processing |
| Benefits Intake API | - | Lighthouse document submission service |
| Claims Evidence API | - | VA external service for evidence upload |
| VA Notify | - | Email notification service |

## Configuration

Configure the module through the main application settings:

```yaml
# config/settings.yml
modules:
  burials:
    enabled: true

lighthouse:
  benefits_intake:
    host: 'https://sandbox-api.va.gov'
    timeout: 30

claims_evidence_api:
  base_url: 'https://claimevidence-api.dev.bip.va.gov'
  ssl: true
  timeout: 60

vanotify:
  services:
    21p_530ez:
      api_key: <%= ENV['VANOTIFY_API_KEY'] %>
      email:
        confirmation:
          template_id: burial_confirmation_template
          flipper_id: burial_confirmation_email
        error:
          template_id: burial_error_template
          flipper_id: burial_error_email
```

**Required Environment Variables:**
- `LIGHTHOUSE_BENEFITS_INTAKE_CLIENT_ID` - OAuth client identifier
- `LIGHTHOUSE_BENEFITS_INTAKE_RSA_KEY` - Path to RSA private key
- `VANOTIFY_API_KEY` - VA Notify API key for email notifications

## Usage Examples

### Basic Form Submission

```ruby
# Create a burial claim
claim = Burials::SavedClaim.new(
  form: form_data.to_json,
  user: current_user
)
claim.save!

# Generate PDF
pdf_path = claim.to_pdf

# Submit to Benefits Intake API
Burials::BenefitsIntake::SubmitClaimJob.perform_async(claim.id)
```

### Direct Service Usage

```ruby
# Initialize service
service = Lighthouse::BenefitsIntake::Service.new

# Prepare metadata
metadata = Lighthouse::BenefitsIntake::Metadata.new(
  form_id: Burials::FORM_ID,
  veteran_first_name: claim.veteran_first_name,
  veteran_last_name: claim.veteran_last_name,
  file_number: claim.file_number,
  source: 'va.gov',
  doc_type: claim.document_type,
  business_line: claim.business_line
)

# Submit with attachments
upload_url = service.upload_doc(
  document: pdf_path,
  metadata: metadata,
  attachments: claim.persistent_attachments
)
```

### PDF Generation and Filling

```ruby
# Access the PDF filler directly
filler = Burials::PdfFill::Forms::Va21p530ez.new(claim)

# Generate filled PDF
pdf_path = filler.generate('/tmp/filled_form.pdf')

# Get form field mappings
mappings = filler.merge_fields
```

### Email Notifications

```ruby
# Send confirmation email
notifier = VeteranFacingServices::NotificationEmail::SavedClaim.new(
  claim.id,
  service_name: '21p_530ez'
)
notifier.deliver(:confirmation)

# Send error notification
notifier.deliver(:error)
```

### Monitoring and Tracking

```ruby
# Initialize monitor
monitor = Burials::Monitor.new

# Track successful submission
monitor.track_request(
  :info,
  'Burial claim submitted successfully',
  'burials.submission.success',
  claim_id: claim.id,
  veteran_icn: claim.veteran_icn
)

# Track processing errors
monitor.track_request(
  :error,
  'Benefits Intake submission failed',
  'burials.submission.error',
  exception: error.message,
  claim_id: claim.id
)
```

## API Reference

### Background Jobs

| Job | Purpose | Parameters |
|-----|---------|------------|
| `Burials::BenefitsIntake::SubmitClaimJob` | Submit to Benefits Intake API | `saved_claim_id` |
| `Burials::NotificationEmailJob` | Send status notifications | `saved_claim_id`, `email_type` |

### Configuration Options

| Setting | Type | Description |
|---------|------|-------------|
| `burials.pdf_stamping` | Boolean | Enable PDF stamping for submissions |
| `burials.evidence_upload` | Boolean | Enable Claims Evidence API uploads |
| `burials.email_notifications` | Boolean | Enable VA Notify email sending |

## Testing

```bash
# Run all module tests
bundle exec rspec modules/burials/spec/
```

### Test Factories

```ruby
# Create test burial claim
claim = create(:burials_saved_claim)

# With attachments
claim = create(:burials_saved_claim, :with_attachments)

# With specific form data
claim = create(:burials_saved_claim, form: custom_form_data.to_json)
```

### Feature Flag Testing

```ruby
# Always stub Flipper in tests
allow(Flipper).to receive(:enabled?)
  .with(:burial_benefits_intake_upload)
  .and_return(true)

allow(Flipper).to receive(:enabled?)
  .with(:burial_confirmation_email)
  .and_return(true)
```

### External Service Mocking

```ruby
# Mock Benefits Intake API
allow_any_instance_of(Lighthouse::BenefitsIntake::Service)
  .to receive(:upload_doc)
  .and_return('success_uuid')

# Mock Claims Evidence API
allow_any_instance_of(ClaimsEvidenceApi::Service::Files)
  .to receive(:upload)
  .and_return({ 'data' => { 'id' => 'evidence_uuid' } })
```

The module provides comprehensive burial benefits processing capabilities within the VA.gov ecosystem, supporting veterans and their families through the burial allowance application process with robust error handling, monitoring, and integration with VA backend services.