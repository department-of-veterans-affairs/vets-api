# Pensions

## Overview

The Pensions module provides comprehensive processing capabilities for VA Form 21P-527EZ (Application for Veterans Pension) within the VA.gov ecosystem. This Rails Engine handles the complete lifecycle of pension benefit claims, from initial form submission through final adjudication, including PDF generation, document uploads, and integration with multiple VA backend services.

The module operates as an isolated Rails Engine within vets-api, providing pension-specific functionality while maintaining integration points with shared VA.gov services. It supports both authenticated and unauthenticated user submissions, handles complex form validation with military service history, medical expenses, and income reporting, and manages secure document transmission to VA claims processing systems.

Key features include automated PDF form filling with overflow page generation, Benefits Intake API integration for document submission, BPDS (Benefits Processing Data Service) integration for structured data submission, comprehensive monitoring and error handling, email notifications via VA Notify, and support for multiple submission pathways including direct API submission and traditional mail processing workflows.

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
| BPDS | - | Benefits Processing Data Service |
| VA Notify | - | Email notification service |

## Configuration

Configure the module through the main application settings:

```yaml
# config/settings.yml
modules:
  pensions:
    enabled: true

lighthouse:
  benefits_intake:
    host: 'https://sandbox-api.va.gov'
    timeout: 30

bpds:
  url: <%= ENV['bpds__url'] %>
  jwt_secret: <%= ENV['bpds__jwt_secret'] %>
  schema_version: 'test'

vanotify:
  services:
    pensions:
      api_key: <%= ENV['VANOTIFY_API_KEY'] %>
      email:
        confirmation:
          template_id: pension_confirmation_template
          flipper_id: pension_confirmation_email
        error:
          template_id: pension_error_template
          flipper_id: pension_error_email
```

**Required Environment Variables:**
- `LIGHTHOUSE_BENEFITS_INTAKE_CLIENT_ID` - OAuth client identifier
- `LIGHTHOUSE_BENEFITS_INTAKE_RSA_KEY` - Path to RSA private key
- `VANOTIFY_API_KEY` - VA Notify API key for email notifications
- `bpds__url` - BPDS service endpoint
- `bpds__jwt_secret` - JWT secret for BPDS authentication

## Usage Examples

### Basic Form Submission

```ruby
# Create a pension claim
claim = Pensions::SavedClaim.new(
  form: form_data.to_json,
  user: current_user
)
claim.save!

# Generate PDF with overflow pages
pdf_path = claim.to_pdf

# Submit to Benefits Intake API
Pensions::BenefitsIntake::SubmitClaimJob.perform_async(claim.id)
```

### Direct Service Usage

```ruby
# Initialize service
service = Lighthouse::BenefitsIntake::Service.new

# Prepare metadata
metadata = Lighthouse::BenefitsIntake::Metadata.new(
  form_id: Pensions::FORM_ID,
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

### PDF Generation and Complex Form Filling

```ruby
# Access the PDF filler directly
filler = Pensions::PdfFill::Va21p527ez.new(claim)

# Generate filled PDF with overflow handling
pdf_path = filler.generate('/tmp/filled_form.pdf')

# Get form field mappings for complex sections
section_10_mappings = Pensions::PdfFill::Sections::Section10.new.expand_medical_expenses(
  claim.parsed_form.dig('medicalExpenses')
)
```

### Military Information Prefill

```ruby
# Get military service information for prefill
military_info = Pensions::MilitaryInformation.new(user)

service_branches = military_info.service_branches_for_pensions
# => { "army" => true, "navy" => false, "airForce" => false, ... }

entry_date = military_info.first_uniformed_entry_date
# => "1975-06-15"

service_number = military_info.service_number
# => "123456789" (SSN for post-1971 service)
```

### BPDS Integration

```ruby
# Submit structured data to BPDS
bpds_service = BPDS::Service.new
response = bpds_service.submit_form_data(
  claim_id: claim.id,
  form_data: claim.parsed_form,
  veteran_icn: claim.veteran_icn
)
```

### Email Notifications

```ruby
# Send confirmation email
notifier = Pensions::NotificationEmail.new(claim.id)
notifier.deliver(:confirmation)

# Send error notification
notifier.deliver(:error)
```

### Zero Silent Failures Manual Remediation

```ruby
# Manual resubmission with pension-specific stamps
remediation = Pensions::ZeroSilentFailures::ManualRemediation.new(claim.id)
remediation.perform_resubmission(
  reason: 'Benefits Intake API timeout',
  user_id: current_user.id
)
```

## API Reference

### Background Jobs

| Job | Purpose | Parameters |
|-----|---------|------------|
| `Pensions::BenefitsIntake::SubmitClaimJob` | Submit to Benefits Intake API | `saved_claim_id` |
| `Pensions::NotificationEmailJob` | Send status notifications | `saved_claim_id`, `email_type` |

### Configuration Options

| Setting | Type | Description |
|---------|------|-------------|
| `pensions.pdf_stamping` | Boolean | Enable PDF stamping for submissions |
| `pensions.bpds_submission` | Boolean | Enable BPDS structured data submission |
| `pensions.email_notifications` | Boolean | Enable VA Notify email sending |

## Testing

```bash
# Run all module tests
bundle exec rspec modules/pensions/spec/
```

### Test Factories

```ruby
# Create test pension claim
claim = create(:pensions_saved_claim)

# With specific form data
claim = create(:pensions_saved_claim, form: custom_form_data.to_json)

# Pending submission
claim = create(:pensions_saved_claim, :pending)
```

### Feature Flag Testing

```ruby
# Always stub Flipper in tests
allow(Flipper).to receive(:enabled?)
  .with(:pension_benefits_intake_upload)
  .and_return(true)

allow(Flipper).to receive(:enabled?)
  .with(:pension_confirmation_email)
  .and_return(true)

allow(Flipper).to receive(:enabled?)
  .with(:pension_bpds_submission)
  .and_return(true)
```

### External Service Mocking

```ruby
# Mock Benefits Intake API
allow_any_instance_of(Lighthouse::BenefitsIntake::Service)
  .to receive(:upload_doc)
  .and_return('success_uuid')

# Mock BPDS API
allow_any_instance_of(BPDS::Service)
  .to receive(:submit_form_data)
  .and_return({ 'status' => 'success' })

# Mock military information
allow_any_instance_of(Pensions::MilitaryInformation)
  .to receive(:service_branches_for_pensions)
  .and_return({ 'army' => true, 'navy' => false })
```

The module provides comprehensive pension processing capabilities within the VA.gov ecosystem, supporting veterans through the pension application process with robust error handling, monitoring, and integration with VA backend services including BPDS for automated claim processing.