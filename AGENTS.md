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

    ## PDF Generation Workflow

### Overview

PDF generation is an **on-demand** process that occurs when users request to download a filled form. Unlike the spool file processing which happens automatically in the background, PDFs are generated in real-time when the `download_pdf` endpoint is called.

### PDF Generation Triggers

PDF generation can be triggered in two ways:

1. **User Download Request**: `GET /v0/education_benefits_claims/:id/download_pdf`
2. **Programmatic Generation**: Direct calls to `PdfFill::Filler.fill_form()` in code

### Key PDF Components

#### 1. **PdfFill::Filler Module** (`lib/pdf_fill/filler.rb`)
- **Central PDF filling engine** that orchestrates the entire process
- Maintains registry of form classes in `FORM_CLASSES` hash
- Handles both standard and Unicode PDF forms via PDFtk
- Manages temporary file creation, cleanup, and security

#### 2. **Form-Specific Classes** (e.g., `lib/pdf_fill/forms/va2210216.rb`)
- Maps JSON form data to PDF field names via `KEY` constant
- Handles form-specific data transformations in `merge_fields()` method
- Defines field limits, validation rules, and formatting

#### 3. **HashConverter** (`lib/pdf_fill/hash_converter.rb`)
- **Transforms JSON form data into PDFtk-compatible format**
- Handles data type conversions (booleans → 1/0, dates, strings)
- Manages overflow text and extra page generation
- Processes iterative data (arrays, repeated sections)

#### 4. **PDF Templates** (`lib/pdf_fill/forms/pdfs/`)
- **Fillable PDF templates** (e.g., `22-10216.pdf`) with named form fields
- Created by VA form designers with specific field names
- Form classes map JSON keys to these PDF field names

### PDF Generation Flow

```
User clicks "Download PDF"
    ↓
GET /education_benefits_claims/:id/download_pdf
    ↓
EducationBenefitsClaimsController#download_pdf
    ↓
Find EducationBenefitsClaim & SavedClaim records
    ↓
PdfFill::Filler.fill_form(saved_claim, uuid, options)
    ↓
[1] Form Class Lookup: FORM_CLASSES['22-10216'] → Va2210216
    ↓
[2] Data Preparation: form_class.new(form_data).merge_fields()
    ↓
[3] HashConverter Creation: transform JSON → PDF field mappings
    ↓
[4] Template Resolution: lib/pdf_fill/forms/pdfs/22-10216.pdf
    ↓
[5] PDFtk Fill: PDF_FORMS.fill_form(template, output, field_data)
    ↓
[6] Optional Stamping: Electronic signature stamps if enabled
    ↓
[7] Extras Combination: Merge overflow pages if needed
    ↓
[8] File Delivery: send_data() → browser download
    ↓
[9] Cleanup: Delete temporary files
```

### Detailed Process Steps

#### Step 1: Form Class Registration
```ruby
# In lib/pdf_fill/filler.rb
FORM_CLASSES = {
  '22-10216' => PdfFill::Forms::Va2210216,
  '22-10215' => PdfFill::Forms::Va2210215,
  # ... other forms
}
```

#### Step 2: Data Transformation Pipeline
```ruby
# Example: Va2210216 class transforms data
def merge_fields(fill_options)
  form_data = @form_data
  
  # Combine first and last name into fullName
  if form_data['certifyingOfficial']
    official = form_data['certifyingOfficial']
    official['fullName'] = "#{official['first']} #{official['last']}"
  end
  
  form_data
end
```

#### Step 3: HashConverter Mapping
```ruby
# Va2210216::KEY maps JSON paths to PDF field names
KEY = {
  'institutionDetails' => {
    'institutionName' => {
      key: 'Text1',           # PDF field name
      limit: 50,              # Character limit
      question_num: 1,        # For overflow pages
      question_text: 'INSTITUTION NAME'
    }
  }
}
```

#### Step 4: PDFtk Integration
- Uses `pdftk` binary to fill PDF form fields
- Two PDF engines: standard (`PDF_FORMS`) and Unicode (`UNICODE_PDF_FORMS`)
- Flattens PDFs in production to prevent editing

#### Step 5: Electronic Signatures & Stamps
```ruby
# Automatic stamping for certain forms
stamp_text = "Signed electronically and submitted via VA.gov at #{timestamp}. " \
             "Signee signed with an identity-verified account."
```

#### Step 6: Overflow & Extra Pages
- **ExtrasGenerator**: Creates additional pages for overflow text
- **Continuation Sheets**: Special handling for forms like 22-10215 with many programs
- Combines main PDF with overflow pages using PDFtk

### Form Registration System

#### Adding New Form Support
1. **Create form class**: `lib/pdf_fill/forms/va[FORM_NUMBER].rb`
2. **Define KEY mapping**: JSON paths → PDF field names
3. **Add PDF template**: `lib/pdf_fill/forms/pdfs/[FORM_ID].pdf`
4. **Register in Filler**: Add to `FORM_CLASSES` hash
5. **Require in Filler**: Add `require` statement

#### Example Form Class Structure
```ruby
module PdfFill::Forms
  class Va2210216 < FormBase
    include FormHelper

    KEY = {
      'jsonFieldPath' => {
        key: 'PdfFieldName',
        limit: 50,
        question_num: 1,
        question_text: 'DISPLAY_NAME'
      }
    }

    def merge_fields(options)
      # Transform form data before PDF filling
      @form_data
    end
  end
end
```

### Error Handling & Logging

- **PdfFillerException**: Thrown when form class not found
- **Automatic cleanup**: Temporary files deleted even on errors
- **Comprehensive logging**: Tracks form ID, file extension, extras usage
- **Graceful fallbacks**: Continues without stamps if stamping fails

### Security Considerations

- **Temporary file isolation**: PDFs created in `tmp/pdfs/` directory
- **Automatic cleanup**: Files deleted after download/processing
- **Production flattening**: PDFs flattened to prevent editing in production
- **UUID file names**: Prevents file name conflicts and enumeration attacks

### Testing PDF Generation

#### Console Testing
```ruby
# In Rails console
claim = EducationBenefitsClaim.find(<CLAIM_ID>)
saved_claim = SavedClaim.find(claim.saved_claim_id)

# Generate PDF programmatically
pdf_path = PdfFill::Filler.fill_form(
  saved_claim,
  'test_file_name',
  sign: false  # Skip electronic signature for testing
)

# Check the generated file
File.exist?(pdf_path)  # Should return true
```

#### Browser Testing
1. Submit a form via the frontend
2. Note the `EducationBenefitsClaim` ID from the confirmation
3. Visit: `/v0/education_benefits_claims/<ID>/download_pdf`
4. Verify PDF downloads with correctly filled fields

#### API Testing with curl

**Submit VA1919 Form:**
```bash
curl -X POST "http://localhost:3000/v0/education_benefits_claims/1919" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "education_benefits_claim": {
      "form": "{\"certifyingOfficial\":{\"first\":\"John\",\"last\":\"Doe\",\"role\":{\"level\":\"certifying official\"}},\"aboutYourInstitution\":true,\"institutionDetails\":{\"facilityCode\":\"12345678\",\"institutionName\":\"Test University for VA1919\",\"institutionAddress\":{\"country\":\"USA\",\"state\":\"CA\",\"city\":\"San Francisco\",\"street\":\"123 Education Blvd\",\"postalCode\":\"94102\"}},\"isProprietaryProfit\":true,\"isProfitConflictOfInterest\":true,\"proprietaryProfitConflicts\":[{\"affiliatedIndividuals\":{\"first\":\"Jane\",\"last\":\"Smith\",\"title\":\"Administrator\",\"individualAssociationType\":\"va\"}},{\"affiliatedIndividuals\":{\"first\":\"Bob\",\"last\":\"Johnson\",\"title\":\"Director\",\"individualAssociationType\":\"saa\"}}],\"allProprietaryConflictOfInterest\":true,\"allProprietaryProfitConflicts\":[{\"certifyingOfficial\":{\"first\":\"Alice\",\"last\":\"Williams\",\"title\":\"Certifying Official\"},\"fileNumber\":\"123456789\",\"enrollmentPeriod\":{\"from\":\"2023-01-01\",\"to\":\"2023-12-31\"}},{\"certifyingOfficial\":{\"first\":\"David\",\"last\":\"Brown\",\"title\":\"Senior Official\"},\"fileNumber\":\"987654321\",\"enrollmentPeriod\":{\"from\":\"2022-06-01\",\"to\":\"2023-05-31\"}}],\"statementOfTruthSignature\":\"John Doe\",\"dateSigned\":\"2024-01-15\"}"
    }
  }'
```
*Note: CSRF protection has been disabled for this API endpoint to allow unauthenticated testing.*

**Download Generated PDF:**
```bash
curl -X GET "http://localhost:3000/v0/education_benefits_claims/download_pdf/28\
  -H "Accept: application/pdf" \
  --output "va1919_form.pdf"
```

**Expected Response (submit):**
```json
{
  "data": {
    "id": "123",
    "type": "education_benefits_claims", 
    "attributes": {
      "confirmationNumber": "V-EBC-123",
      "submittedAt": "2024-01-15T10:30:00.000Z",
      "regional_office": "Eastern",
      "form_type": "1919"
    }
  }
}
```

#### Test Fixtures & Specs
- **PDF Fixtures**: `spec/fixtures/pdf_fill/22-10216/` contains test PDFs
- **Form Classes**: Test form field mappings and data transformations  
- **Integration Tests**: Full download flow with realistic form data
- **Overflow Testing**: `spec/fixtures/pdf_fill/22-1919/overflow.json` tests character limit overflow functionality

#### Testing Overflow Functionality for VA1919

**Character Limits in VA1919:**
- Institution Name: 50 characters
- Institution Address: 100 characters  
- Certifying Official Name: 60 characters
- Official Names: 60 characters
- Employee Names: 60 characters
- Association Types: 30 characters

**Test Overflow with Curl:**
```bash
curl -X POST "http://localhost:3000/v0/education_benefits_claims/1919" \
  -H "Content-Type: application/json" \
  -d @test_1919_overflow_payload.json
```

When text exceeds these limits, it will be replaced with "See add'l info page" in the main PDF and the full text will appear on additional overflow pages.

#### Unit Testing for VA1919

**Test Structure:**
- **Integration Tests**: Test the complete `merge_fields` method behavior
- **Unit Tests**: Test individual helper methods in isolation

**Helper Method Tests:**
- `#process_certifying_official` - Name combination and role processing
- `#convert_boolean_fields` - Boolean to YES/NO/N/A conversion  
- `#process_proprietary_conflicts` - Proprietary conflicts processing (max 2)
- `#process_all_proprietary_conflicts` - All conflicts processing (max 2)
- `#convert_boolean_to_yes_no` - Individual boolean conversion

**Run Tests:**
```bash
# Run all VA1919 tests
bundle exec rspec spec/lib/pdf_fill/forms/va221919_spec.rb

# Run with documentation format
bundle exec rspec spec/lib/pdf_fill/forms/va221919_spec.rb --format documentation

# Run specific test group
bundle exec rspec spec/lib/pdf_fill/forms/va221919_spec.rb -e "private helper methods"
```

**Test Coverage:**
- ✅ Happy path scenarios
- ✅ Edge cases (nil values, missing data)
- ✅ Boundary conditions (max 2 conflicts limit)
- ✅ Error handling (graceful degradation)

### Configuration Updates (Required)

1. **Update FORM_TYPES**: Add '10275' to the FORM_TYPES array in `EducationBenefitsClaim`
2. **Update Routes**: Add route entry for `POST /v0/education_benefits_claims/10275`
3. **Update Controller Logic**: Ensure `V0::EducationBenefitsClaimsController` handles '10275' form type

## Technical Requirements

### Code Quality Standards

- **Rubocop compliance**: All files must pass rubocop with no violations
- **File endings**: Each file must end with exactly one newline character
- **No carriage returns**: Use Unix line endings only (LF, not CRLF)
- **Consistent formatting**: Match indentation, spacing, and style of corresponding 22-10216 files exactly

### Naming Conventions

- Class names: `VA10275` (following `VA10216` pattern)
- File paths: Replace `10216` with `10275` in all corresponding paths
- Schema reference: `'22-10275'` (following `'22-10216'` pattern)
- Form type: `'10275'` (following `'10275'` pattern)

### Data Flow Requirements

- Form submissions must flow through the same pipeline as 22-10216
- Must integrate with existing `EducationBenefitsClaim` and `EducationBenefitsSubmission` creation
- Must support the same confirmation number format: `V-EBC-{id}`
- Must trigger the same background spool file processing

## Assumptions

- JSON schema file `22-10275-schema.json` already exists and is valid
- Frontend integration will be handled separately
- PDF generation components will be added later
- Regional office assignment logic should follow the same geographic rules as other education forms

## Validation Criteria

The implementation is complete when:

1. A form can be submitted via `POST /v0/education_benefits_claims/10275` with valid JSON
2. `SavedClaim::EducationBenefits::VA10275` record is created in database
3. Related `EducationBenefitsClaim` and `EducationBenefitsSubmission` records are created automatically
4. Confirmation number is returned in format `V-EBC-{id}`
5. All files pass rubocop validation
6. Factory can generate valid test data

## Out of Scope

- PDF generation logic (`PdfFill::Forms::Va2210275`)
- PDF template files
- Comprehensive integration tests
- Frontend form components
- Detailed validation specs (basic model validation only)
1. **Update .CODEOWNERS**: Add ownership entries for all new 22-10275 files following the exact pattern established for 22-10216 files
    - Match the team/individual ownership assignments from 22-10216 entries
    - Include all new file paths created above

## Enforced Code Quality & Validation

### Mandatory Rubocop Compliance

- **All files MUST pass rubocop linting before delivery**
- Run `bundle exec rubocop <file_path>` on each created file
- Fix ALL rubocop violations - no exceptions or disabling rules
- Files with rubocop violations will be rejected

### Mandatory File Format Validation

- **Every file MUST end with exactly one newline character**
- Use this validation: `tail -c 1 <file_path> | od -c` should show `\\n`
- Files without proper endings will be rejected
- **Test this requirement**: After creating each file, run the validation command above

### Line Ending Enforcement

- **Unix line endings only (LF)**: No Windows/DOS carriage returns (CRLF)
- Validate with: `file <file_path>` should NOT show "with CRLF line terminators"
- If CRLF detected, convert with: `dos2unix <file_path>`

### Pre-Delivery Checklist

Before submitting files, run these commands on each created file:

```bash
# 1. Rubocop validation (must show no offenses)
bundle exec rubocop app/models/saved_claim/education_benefits/va10275.rb

# 2. Newline validation (must show exactly one \\n)
tail -c 1 app/models/saved_claim/education_benefits/va10275.rb | od -c

# 3. Line ending validation (must NOT show CRLF)
file app/models/saved_claim/education_benefits/va10275.rb
```