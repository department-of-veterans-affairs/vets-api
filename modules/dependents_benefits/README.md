# Dependents Benefits

## Overview

The Dependents Benefits module provides comprehensive processing capabilities for VA Form 21-686c (Declaration of Status of Dependents) and VA Form 21-674 (Request for Approval of School Attendance) within the VA.gov ecosystem. This Rails Engine handles the complete lifecycle of dependent benefit claims, from initial form submission through final adjudication, including PDF generation, document uploads, and integration with multiple VA backend services.

The module operates as an isolated Rails Engine within vets-api, providing dependents-specific functionality while maintaining integration points with shared VA.gov services. It supports authenticated user submissions, handles complex form validation with spouse information, children, students, and dependent removal scenarios, and manages secure document transmission to VA claims processing systems.

Key features include automated PDF form filling with overflow page generation, Benefits Intake API integration for backup document submission, BGS (Benefits Gateway Services) integration for primary claim submission, Claims Evidence API integration for document uploads, comprehensive monitoring and error handling, email notifications via VA Notify, and support for multiple submission pathways including a parent/child claim architecture that processes 686c and 674 forms together or separately.

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
| Benefits Intake API | - | Lighthouse document submission service (backup) |
| BGS | - | Benefits Gateway Services (primary submission) |
| Claims Evidence API | - | Document upload service |
| VA Notify | - | Email notification service |

## Configuration

Configure the module through the main application settings:

```yaml
# config/settings.yml
modules:
  dependents_benefits:
    enabled: true

lighthouse:
  benefits_intake:
    host: 'https://sandbox-api.va.gov'
    timeout: 30

# Note: Digital Forms API integration exists for FDF pilot but is experimental
# and not yet recommended for general use

vanotify:
  services:
    dependents_benefits:
      api_key: <%= ENV['VANOTIFY_API_KEY'] %>
      email:
        received_686c_674:
          template_id: dependents_received_686c_674_template
          flipper_id: dependents_received_686c_674_email
        received_686c_only:
          template_id: dependents_received_686c_only_template
          flipper_id: dependents_received_686c_only_email
        received_674_only:
          template_id: dependents_received_674_only_template
          flipper_id: dependents_received_674_only_email
        error_686c_674:
          template_id: dependents_error_686c_674_template
          flipper_id: dependents_error_686c_674_email
        error_686c_only:
          template_id: dependents_error_686c_only_template
          flipper_id: dependents_error_686c_only_email
        error_674_only:
          template_id: dependents_error_674_only_template
          flipper_id: dependents_error_674_only_email
```

**Required Environment Variables:**
- `LIGHTHOUSE_BENEFITS_INTAKE_CLIENT_ID` - OAuth client identifier for Lighthouse
- `LIGHTHOUSE_BENEFITS_INTAKE_RSA_KEY` - Path to RSA private key for Lighthouse
- `VANOTIFY_API_KEY` - VA Notify API key for email notifications
- `BGS_URL` - BGS service endpoint
- `BGS_CLIENT_ID` - BGS client identifier
- `CLAIMS_EVIDENCE_API_URL` - Claims Evidence API endpoint

## Usage Examples

### Basic Form Submission

```ruby
# Create a dependents claim (parent claim)
claim = DependentsBenefits::PrimaryDependencyClaim.new(
  form: form_data.to_json,
  user_account: current_user.user_account
)
claim.save!

# Create claim group for tracking
SavedClaimGroup.create!(
  claim_group_guid: claim.guid,
  parent_claim_id: claim.id,
  saved_claim_id: claim.id,
  user_data: user_data.get_user_json
)

# Generate child claims and enqueue submission jobs
DependentsBenefits::ClaimProcessor.enqueue_submissions(claim.id)
```

### Direct Service Usage

```ruby
# Initialize claim processor
processor = DependentsBenefits::ClaimProcessor.new(parent_claim_id)

# Enqueue all submission jobs (BGS and Claims Evidence)
result = processor.enqueue_submissions
# => { data: { jobs_enqueued: 2 }, error: nil }
```

### PDF Generation

```ruby
# Access the PDF filler directly for 686c
filler = DependentsBenefits::PdfFill::Va21686c.new(claim)
pdf_path = filler.generate('/tmp/filled_686c.pdf')

# Access the PDF filler for 674
filler = DependentsBenefits::PdfFill::Va21674.new(claim)
pdf_path = filler.generate('/tmp/filled_674.pdf')
```

### Child Claim Generation

```ruby
# Generate a 686c claim from parent form data
form_data = parent_claim.parsed_form
DependentsBenefits::Generators::Claim686cGenerator.new(form_data, parent_claim.id).generate

# Generate 674 claims for each student
form_data.dig('dependents_application', 'student_information')&.each do |student|
  DependentsBenefits::Generators::Claim674Generator.new(form_data, parent_claim.id, student).generate
end
```

### Email Notifications

```ruby
# Send submission confirmation email
notifier = DependentsBenefits::NotificationEmail.new(claim.id)
notifier.send_submitted_notification

# Send received confirmation email
notifier.send_received_notification

# Send error notification
notifier.send_error_notification
```

### Benefits Intake Backup Submission

```ruby
# Backup submission via Lighthouse (used when primary BGS submission fails)
lighthouse_submission = DependentsBenefits::BenefitsIntake::LighthouseSubmission.new(saved_claim, user_data)
uuid = lighthouse_submission.initialize_service
lighthouse_submission.prepare_submission
lighthouse_submission.upload_to_lh
```

### Zero Silent Failures

```ruby
# Zero Silent Failures support exists in the module for handling
# submission failures gracefully. See DependentsBenefits::ZeroSilentFailures
# for implementation details.
#
# The ClaimProcessor handles permanent failures by:
# 1. Marking the parent claim group as failed
# 2. Enqueueing a backup Benefits Intake job
# 3. Sending error notifications to avoid silent failures
```

## API Reference

### Background Jobs

| Job | Purpose | Parameters |
|-----|---------|------------|
| `DependentsBenefits::Sidekiq::BGS::BGSFormJob` | Submit to BGS (primary) | `parent_claim_id` |
| `DependentsBenefits::Sidekiq::ClaimsEvidence::ClaimsEvidenceFormJob` | Upload documents to Claims Evidence | `parent_claim_id` |
| `DependentsBenefits::Sidekiq::BenefitsIntakeJob` | Submit to Lighthouse Benefits Intake (backup) | `parent_claim_id` |
| `DependentsBenefits::Sidekiq::DependentSubmissionJob` | Base job for dependent submissions | `claim_id` |

### Feature Flags

| Flag | Description |
|------|-------------|
| `dependents_module_enabled` | Enable/disable the dependents module |
| `dependents_digital_forms_api_submission_enabled` | Enable Digital Forms API pilot (experimental) |
| `va_dependents_net_worth_and_pension` | Enable pension-related dependent submissions |
| `va_dependents_no_ssn` | Enable submissions without SSN |
| `va_dependents_v3` | Enable v3 form prefill |
| `dependents_removal_check` | Enable dependent removal validation |
| `dependents_pension_check` | Enable pension eligibility check |
| `benefits_intake_submission_status_job` | Enable Benefits Intake status tracking |

### Form IDs

| Constant | Value | Description |
|----------|-------|-------------|
| `DependentsBenefits::FORM_ID` | `686C-674` | Base combined claim form ID |
| `DependentsBenefits::FORM_ID_V2` | `686C-674-V2` | Versioned combined claim form ID |
| `DependentsBenefits::ADD_REMOVE_DEPENDENT` | `21-686C` | Add/Remove Dependent form |
| `DependentsBenefits::SCHOOL_ATTENDANCE_APPROVAL` | `21-674` | School Attendance Approval form |
| `DependentsBenefits::PARENT_DEPENDENCY` | `21-509` | Parent Dependency form |

### Models

| Model | Description |
|-------|-------------|
| `DependentsBenefits::PrimaryDependencyClaim` | Parent claim for 686c/674 submissions |
| `DependentsBenefits::AddRemoveDependent` | 21-686C specific claim |
| `DependentsBenefits::SchoolAttendanceApproval` | 21-674 specific claim |
| `DependentsBenefits::ParentDependency` | 21-509 specific claim |

## Testing

```bash
# Run all module tests
bundle exec rspec modules/dependents_benefits/spec/
```

### Test Factories

```ruby
# Create test dependents claim (parent claim with full form data)
claim = create(:dependents_claim)

# Create 674 student claim
claim = create(:student_claim)

# Create 686c add/remove dependents claim
claim = create(:add_remove_dependents_claim)
```

### Feature Flag Testing

```ruby
# Always stub Flipper in tests
allow(Flipper).to receive(:enabled?)
  .with(:dependents_module_enabled, instance_of(User))
  .and_return(true)

allow(Flipper).to receive(:enabled?)
  .with(:va_dependents_net_worth_and_pension)
  .and_return(true)

allow(Flipper).to receive(:enabled?)
  .with(:va_dependents_no_ssn)
  .and_return(true)

allow(Flipper).to receive(:enabled?)
  .with(:benefits_intake_submission_status_job)
  .and_return(true)
```

### External Service Mocking

```ruby
# Mock BGS Dependent Service
allow_any_instance_of(BGS::DependentService)
  .to receive(:get_dependents)
  .and_return({ dependents: [] })

# Mock Benefits Intake API (backup submission)
allow_any_instance_of(DependentsBenefits::BenefitsIntake::LighthouseSubmission)
  .to receive(:upload_to_lh)
  .and_return(true)

# Mock Claims Evidence API
allow_any_instance_of(ClaimsEvidenceApi::Uploader)
  .to receive(:upload_evidence)
  .and_return({ 'status' => 'success' })

# Mock Claim Processor
allow(DependentsBenefits::ClaimProcessor)
  .to receive(:enqueue_submissions)
  .and_return({ data: { jobs_enqueued: 2 }, error: nil })
```

The module provides comprehensive dependent benefits processing capabilities within the VA.gov ecosystem, supporting veterans through the process of adding or removing dependents with robust error handling, monitoring, and integration with VA backend services including BGS for automated claim processing and Benefits Intake as a reliable backup submission pathway.
