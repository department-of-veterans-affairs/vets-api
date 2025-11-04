# Income and Assets

## Overview

The Income and Assets module provides comprehensive processing capabilities for VA Form 21P-0969 (Income and Asset Statement in Support of Claim for Pension or Parents' Dependency and Indemnity Compensation) within the VA.gov ecosystem. This Rails Engine handles the complete lifecycle of income and asset statements, from initial form submission through final adjudication, including PDF generation, document uploads, and integration with multiple VA backend services.

The module operates as an isolated Rails Engine within vets-api, providing income and asset statement-specific functionality while maintaining integration points with shared VA.gov services. It supports both authenticated and unauthenticated user submissions, handles complex form validation with detailed income reporting, asset documentation, trust information, and transfer records, and manages secure document transmission to VA claims processing systems.

Key features include automated PDF form filling with comprehensive section mapping, Benefits Intake API integration for document submission, detailed income and asset categorization with constants-driven validation, comprehensive monitoring and error handling, email notifications via VA Notify, and support for multiple submission pathways including direct API submission and traditional mail processing workflows.

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
| VA Notify | - | Email notification service |

## Configuration

Configure the module through the main application settings:

```yaml
# config/settings.yml
modules:
  income_and_assets:
    enabled: true

lighthouse:
  benefits_intake:
    host: 'https://sandbox-api.va.gov'
    timeout: 30

vanotify:
  services:
    21p_0969:
      api_key: <%= ENV['VANOTIFY_API_KEY'] %>
      email:
        confirmation:
          template_id: income_assets_confirmation_template
          flipper_id: income_assets_confirmation_email
        error:
          template_id: income_assets_error_template
          flipper_id: income_assets_error_email
```

**Required Environment Variables:**
- `LIGHTHOUSE_BENEFITS_INTAKE_CLIENT_ID` - OAuth client identifier
- `LIGHTHOUSE_BENEFITS_INTAKE_RSA_KEY` - Path to RSA private key
- `VANOTIFY_API_KEY` - VA Notify API key for email notifications

## Usage Examples

### Basic Form Submission

```ruby
# Create an income and assets statement
claim = IncomeAndAssets::SavedClaim.new(
  form: form_data.to_json,
  user: current_user
)
claim.save!

# Generate PDF with detailed section mapping
pdf_path = claim.to_pdf

# Submit to Benefits Intake API
IncomeAndAssets::BenefitsIntake::SubmitClaimJob.perform_async(claim.id)
```

### Direct Service Usage

```ruby
# Initialize service
service = Lighthouse::BenefitsIntake::Service.new

# Prepare metadata
metadata = Lighthouse::BenefitsIntake::Metadata.new(
  form_id: IncomeAndAssets::FORM_ID,
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
filler = IncomeAndAssets::PdfFill::Va21p0969.new(claim)

# Generate filled PDF with comprehensive section mapping
pdf_path = filler.generate('/tmp/filled_form.pdf')

# Get form field mappings for specific sections
section_mappings = filler.merge_fields

# Access individual section processors
section_13 = IncomeAndAssets::PdfFill::Sections::Section13.new
section_13.expand(form_data)
```

### Income and Asset Constants Usage

```ruby
# Use predefined constants for income types
income_type = IncomeAndAssets::Constants::INCOME_TYPES['SOCIAL_SECURITY']
# => 0

# Asset type mapping
asset_type = IncomeAndAssets::Constants::ASSET_TYPES['RENTAL_PROPERTY']
# => 2

# Trust type validation
trust_type = IncomeAndAssets::Constants::TRUST_TYPES['REVOCABLE']
# => 0

# Transfer method categorization
transfer_method = IncomeAndAssets::Constants::TRANSFER_METHODS['SOLD']
# => 0
```

### Email Notifications

```ruby
# Send confirmation email
notifier = IncomeAndAssets::NotificationEmail.new(claim.id)
notifier.deliver(:confirmation)

# Send error notification
notifier.deliver(:error)
```

### Form Profile Integration

```ruby
# Use form profile for prefill data
form_profile = IncomeAndAssets::FormProfiles::Va21p0969.new(user)
prefill_data = form_profile.metadata
```

## API Reference

### Background Jobs

| Job | Purpose | Parameters |
|-----|---------|------------|
| `IncomeAndAssets::BenefitsIntake::SubmitClaimJob` | Submit to Benefits Intake API | `saved_claim_id` |
| `IncomeAndAssets::NotificationEmailJob` | Send status notifications | `saved_claim_id`, `email_type` |

### Configuration Options

| Setting | Type | Description |
|---------|------|-------------|
| `income_and_assets.pdf_stamping` | Boolean | Enable PDF stamping for submissions |
| `income_and_assets.email_notifications` | Boolean | Enable VA Notify email sending |

## Testing

```bash
# Run all module tests
bundle exec rspec modules/income_and_assets/spec/
```

### Test Factories

```ruby
# Create test income and assets claim
claim = create(:income_and_assets_saved_claim)

# With specific form data
claim = create(:income_and_assets_saved_claim, form: custom_form_data.to_json)

# With complex income and asset data
claim = create(:income_and_assets_saved_claim, :with_complex_assets)
```

### Feature Flag Testing

```ruby
# Always stub Flipper in tests
allow(Flipper).to receive(:enabled?)
  .with(:income_assets_benefits_intake_upload)
  .and_return(true)

allow(Flipper).to receive(:enabled?)
  .with(:income_assets_confirmation_email)
  .and_return(true)
```

### External Service Mocking

```ruby
# Mock Benefits Intake API
allow_any_instance_of(Lighthouse::BenefitsIntake::Service)
  .to receive(:upload_doc)
  .and_return('success_uuid')

# Mock PDF generation
allow_any_instance_of(IncomeAndAssets::PdfFill::Va21p0969)
  .to receive(:generate)
  .and_return('/tmp/test_form.pdf')
```

The module provides comprehensive income and asset statement processing capabilities within the VA.gov ecosystem, supporting veterans and their families through the pension eligibility determination process with detailed financial disclosure, robust error handling, monitoring, and integration with VA backend services.