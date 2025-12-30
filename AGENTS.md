# Vets-API Development Environment Setup Guide

This guide provides comprehensive setup instructions for the vets-api project, specifically tailored for AI agents and automated development workflows.

## Project Overview

The vets-api project is a Ruby on Rails application that provides APIs for VA services. It uses Docker for containerization and includes comprehensive test suites.


### Test Database
Tests use the `vets_api_test` database, which is automatically created during setup. The test environment includes:
- Schema loaded from `db/schema.rb`
- Parallel testing support (8 workers by default in CI)
- Transactional fixtures enabled

## Key Configuration Files

### `.developer-setup`
- **Location**: Project root
- **Purpose**: Indicates the development environment type
- **Values**: `native`, `docker`, or `hybrid`
- **Auto-created**: By `bin/setup` commands

### `config/settings.local.yml`
- **Purpose**: Local development settings overrides
- **Auto-created**: From `config/settings.local.yml.example`
- **Contains**:
  - Betamocks cache directory configuration
  - SAML authentication settings
  - ClamAV mock settings for development

### `config/database.yml`
- **Purpose**: Database configuration for different environments
- **Test Database**: Uses `Settings.test_database_url` with optional `TEST_ENV_NUMBER` suffix
- **Docker**: Connects to postgres container via `postgres://` URLs

## Troubleshooting

### Common Issues


### Core Backend Files (Required)

1. **SavedClaim Model**:
   - **Path**: `app/models/saved_claim/education_benefits/va_{{FORM_SHORT}}.rb`
   - **Example**: `app/models/saved_claim/education_benefits/va_10216.rb`
   - **Class Name**: `SavedClaim::EducationBenefits::VA{{FORM_SHORT}}` (no underscore in class name)
   - Inherit from SavedClaim::EducationBenefits
   - Validate against schema '{{FORM_ID}}'
   - Follow exact structure of va_10216.rb

2. **EducationForm Helper**:
   - **Path**: `app/sidekiq/education_form/forms/va_{{FORM_SHORT}}.rb`
   - **Example**: `app/sidekiq/education_form/forms/va_10216.rb`
   - **Class Name**: `EducationForm::Forms::VA{{FORM_SHORT}}` (no underscore in class name)
   - Use the JSON schema to determine form structure and required fields
   - Follow exact structure of existing va_10216.rb helper
   - Include in spool file processing logic

3. **FormProfile Configuration**:
   - **Path**: `app/models/form_profiles/va_{{FORM_SHORT}}.rb`
   - **Example**: `app/models/form_profiles/va_10216.rb`
   - **Class Name**: `FormProfiles::VA{{FORM_SHORT}}` (no underscore in class name)
   - Configure prefill settings and return URL
   - Follow va_10216.rb pattern exactly

4. **Factory Definition**:
   - **Path**: `spec/factories/va{{FORM_SHORT}}.rb` (NO underscore, NO subdirectory)
   - **Example**: `spec/factories/va10216.rb`
   - **Factory Name**: `:va{{FORM_SHORT}}` (no underscore)
   - Use the JSON schema to create realistic test data
   - Follow va10216 pattern (note: no underscore in filename)

5. **Basic Model Spec**:
   - **Path**: `spec/models/saved_claim/education_benefits/va{{FORM_SHORT}}_spec.rb` (NO underscore)
   - **Example**: `spec/models/saved_claim/education_benefits/va10216_spec.rb`
   - Basic validation tests only (not PDF generation tests)
   - Follow va10216_spec.rb structure (note: no underscore in filename)

6. **Exclude from Reports**:
   - Add form number (as string, without "22-") to reject arrays in:
     - `app/sidekiq/education_form/create_daily_fiscal_year_to_date_report.rb`
     - `app/sidekiq/education_form/create_daily_year_to_date_report.rb`

7. **Add to EducationBenefitsClaim Model**:
   - Add form number (as string, without "22-") to `FORM_TYPES` array in `app/models/education_benefits_claim.rb`

### Naming Pattern Rules

- **File names with underscores**: Models, Helpers, FormProfiles (`va_10216.rb`)
- **File names without underscores**: Factories, Specs (`va10216.rb`, `va10216_spec.rb`)
- **Class names**: Always without underscores (`VA10216`)
- **Factory location**: Directly in `spec/factories/` (no subdirectories)
- **Form numbers in arrays**: Always without "22-" prefix (e.g., `"10216"` not `"22-10216"`)

## Additional Resources

- **Project Documentation**: See `docs/` directory for detailed guides
- **Docker Configuration**: Review `docker-compose.yml` and `docker-compose.test.yml`
- **CI/CD Pipeline**: Check `.github/workflows/` for automated testing setup
- **API Documentation**: Available via Swagger UI when application is running
- **Form Naming Conventions**: See `progress/naming-conventions-validation.md` for detailed examples

This setup provides a complete, isolated development environment suitable for both manual development and automated agent workflows.

## Agent Guidelines

- When running agent tasks, make sure all rubocop lint and tests you modified pass
- Follow the exact naming conventions above when creating education benefits forms
- Reference existing files (e.g., va_10216.rb, va10216.rb) as templates

# Forms backend

## Form Backend Workflow Summary

### Overview

Example PR: https://github.com/department-of-veterans-affairs/vets-api/pull/20680/files#diff-80c3df7a8820f37d7c6bc7b85d279df2e754f26fa0cc648717657235a8e5fb95

https://github.com/department-of-veterans-affairs/vets-api/pull/20680/files#diff-80c3df7a8820f37d7c6bc7b85d279df2e754f26fa0cc648717657235a8e5fb95

- Focus on files mentioned below
- PDF only required for certain forms

### Key Components

### 1. **API Entry Point**

- **Route**: `POST /v0/education_benefits_claims/10216`
- **Controller**: `V0::EducationBenefitsClaimsController#create`
- **Accepts**: JSON form data in the request body

### 2. **Core Models**

```ruby
# Inheritance chain:
SavedClaim::EducationBenefits::VA10216 < SavedClaim::EducationBenefits < SavedClaim

```

- **`SavedClaim::EducationBenefits::VA10216`** - Validates against form schema '22-10216'
- **`EducationBenefitsClaim`** - Main business logic model (form type '10216' included in FORM_TYPES)
- **`FormProfiles::VA10216`** - Configuration with prefill settings and return URL
- **`SavedClaim::EducationBenefits::VA10216 (app/models/saved_claim/education_benefits/va_10216.rb)**` - represents saved model in the database
- **`EducationForm::Forms::VA10216 (app/sidekiq/education_form/forms/va_10216.rb)**` **-** helper functions for the spool file

### 3. Workflow Steps

### Step 1: **Form Submission**

1. Submit form data via the frontend
2. Submit form data in the rails console

```ruby
# Controller creates appropriate SavedClaim subclass
claim = SavedClaim::EducationBenefits.form_class('10216').new(form_params)
claim.save! # Validates form data against JSON schema

```

### Step 2: **Related Record Creation** (via ActiveRecord callbacks)

- **`EducationBenefitsClaim`** created automatically (`after_create` callback)
- **`EducationBenefitsSubmission`** created for tracking/reporting
- **Regional Processing Office** assigned based on geographic logic (for Spool only)

### Step 3: **Immediate Response**

- Returns **confirmation number** (format: `V-EBC-{id}`)
- Triggers `after_submit` hook (currently no special logic for 10216)
- Clears any saved in-progress form data

### Step 4: **Background Processing**

- **`EducationForm::CreateDailySpoolFiles`** (Sidekiq job)
- **`EducationForm::CreateDailyExcelFiles`** (Sidekiq job)
    - 22-10282
- **`PdfFill::Forms::Va2210216`** handles PDF form filling
    - 22-10216, 22-10215
- 

### Processing Flow Diagram

```
Frontend Form Submission
    ↓
V0::EducationBenefitsClaimsController
    ↓
SavedClaim::EducationBenefits::VA10216.new
    ↓
Validation against 22-10216 schema
    ↓
EducationBenefitsClaim creation (callback)
    ↓
EducationBenefitsSubmission creation (callback)
    ↓
Regional office assignment
    ↓
Return confirmation number
    ↓
[Background] Daily spool file processing
    ↓
[On-demand] PDF generation

```

### Development/Testing Support

- **Factory**: `FactoryBot.define :va10216` for test data
- **Fixtures**: `spec/fixtures/education_benefits_claims/10216/minimal.json`
- **Spec**: `spec/models/saved_claim/education_benefits/va10216_spec.rb`

This workflow ensures the 10216 form data flows through the same reliable pipeline as other education benefits while maintaining its specific institutional reporting requirements.

## Testing Workflow

You can follow the following steps to ensure the form submission data is submitted to the database:

- Spin up frontend `yarn watch` and backend `foreman start` and GIDS `rails s -p 4000 -b 0.0.0.0`
- Open up a rails console (`rails c`)
- Submit a form via the frontend
    - Upon submission, you will see the ID for `EducationBenefitsClaim`
    - Record the ID
- Run `claim = EducationBenefitsClaim.find(<INSERT_ID>)`
- Confirm that the submitted form is as expected
    - Form type, name, details, formatting