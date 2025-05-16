# IVC ChampVa
This module allows you to generate form_mappings based on a PDF file.
With this in place, you can submit a form payload from the vets-website
and have this module map that payload to the associated PDF and submit it
to PEGA via S3.

PEGA has the ability to hit an endpoint to update the database table `ivc_champva_forms`
with their `case_id` and `status` in the payload.

## Key Features

### VES Integration
The module includes a VES (Veterans Eligibility System) integration for the 10-10d form submissions. When enabled via feature flags, form data is automatically formatted and submitted to the VES API, which validates and processes CHAMPVA applications. 

The VES integration follows a specific workflow:

1. **Conditional Submission Logic**:
   - VES submission only occurs for form 10-10d (CHAMPVA Application)
   - The `champva_send_to_ves` feature flag must be enabled
   - VES submission is currently only available in non-production environments

2. **Submission Ordering**:
   - The system first prepares both the PEGA submission (PDF generation) and VES submission (data formatting)
   - PDF files are uploaded to S3 for PEGA processing first
   - Only if the S3 upload is successful (status 200) will the system proceed with the VES submission
   - This ensures that application data is never sent to VES without a corresponding successful PDF submission

3. **Data Transformation**:
   - Raw form data is transformed into VES-compatible format by the `VesDataFormatter`
   - The formatter creates a structured `VesRequest` object with applicant, sponsor, and beneficiary information
   - The system performs extensive validation on the transformed data before submission

4. **Error Handling and Resilience**:
   - VES submission errors are logged but do not prevent the overall form submission from succeeding
   - This design ensures that PEGA processing can continue even if VES is unavailable
   - Any failed VES submissions are tracked in the database with their status and full request payload
   - The `VesRetryFailuresJob` background job automatically retries failed submissions periodically

5. **Database Storage**:
   - VES submission data is encrypted using KMS before being stored in the database
   - Each successful submission updates the corresponding form record with:
     - `application_uuid`: Unique identifier from VES
     - `ves_status`: Response status from VES
     - `ves_request_data`: Encrypted copy of the submitted data

### Retry Mechanisms
The module implements a robust retry mechanism with configurable parameters for failed operations. A `IvcChampva::Retry` service handles retrying problematic operations with configurable max retries, delay, and condition-based retry logic. Feature flags like `champva_retry_logic_refactor` control which retry implementation is used. The system automatically retries when specific error messages occur during form processing.

### Email Notifications
The system includes an email notification service that sends confirmation emails to applicants once their form is processed by PEGA. Email templates are form-specific and dynamically selected based on the form number. Email notifications can be tracked and use custom callbacks for monitoring successful deliveries.

### Form Merging
The module supports merging 10-10d CHAMPVA applications with Other Health Insurance (OHI) forms through the `submit_champva_app_merged` endpoint, which automatically generates and attaches 10-7959c forms as supporting documents when applicants indicate they have other health insurance.

### Combined PDF Flow for FMP
The module includes a feature for Foreign Medical Program (FMP) claims that combines all submitted documents into a single PDF before submission to PEGA. When the `champva_fmp_single_file_upload` feature flag is enabled and a form 10-7959f-2 (FMP Claim) is submitted:

1. The system collects all PDFs associated with the submission, including:
   - The main form (10-7959f-2)
   - All supporting documents (medical bills, receipts, medical records, etc.)
2. The `PdfCombiner` service merges these into a single coherent PDF document while preserving page order
3. The combined PDF is uploaded to S3 as a single file with appropriate metadata
4. The system tracks all original document filenames in the database for reference
5. A metadata JSON file is generated to trigger PEGA processing of the submission

### Performance Monitoring
The module has comprehensive monitoring through DataDog, tracking various metrics including form submissions, PEGA updates, VES interactions, and email notifications. Monitoring is managed through the `IvcChampva::Monitor` class, providing visibility into the system's performance and helping identify issues.

### Multi-form Processing
The system can process multiple PDF forms in a single submission, with appropriate attachment IDs assigned to each. This capability supports forms that may require multiple PDFs to be generated, such as forms with multiple applicants.

### Status Validation & Notifications
A `MissingFormStatusJob` background job automatically identifies forms that haven't received a status update from PEGA within a configurable timeframe and can send failure notification emails to appropriate parties. This ensures forms don't get "lost" in the system without being processed.

### Enhanced PDF Handling
The module includes advanced PDF handling with features like:
- PDF authentication stamping showing the user's login status and time of submission (e.g., "Signed electronically and submitted via VA.gov at 15:30:45 Signee signed with an identity-verified account." or "Signee not signed in.")
- Digital signature application for forms requiring signatures
- Multi-page form support with conditional page generation
- PDF unlock capabilities for password-protected files
- Robust temp file management for high concurrency environments

### Error Handling
The system implements comprehensive error handling with consistent status codes and error messages. Failed operations are logged and tracked, with appropriate retry mechanisms for recoverable errors.

## Feature Flags
Current feature flags used to control functionality:

| Flag | Purpose | Notes |
|------|---------|-------|
| `champva_send_to_ves` | Enables sending form submission data to the VES API | Long-running feature flag pending integration signoff from VES team |
| `champva_retry_logic_refactor` | Enables refactored retry logic for form submissions | |
| `champva_fmp_single_file_upload` | Enables combining FMP form and supporting docs into a single PDF | Only applies to form 10-7959f-2 |
| `champva_vanotify_custom_callback` | Enables custom callback for failure emails with VA Notify | |
| `champva_vanotify_custom_confirmation_callback` | Enables custom callback for confirmation emails | |
| `champva_log_all_s3_uploads` | Enables detailed logging for all S3 uploads | |
| `champva_enable_pega_report_check` | Enables querying PEGA reporting API for form status | |
| `champva_pega_applicant_metadata_enabled` | Enables including applicant data in S3 metadata | |
| (TODO) | Enables the endpoint to submit combined 10-10d/10-7959c form submissions | Feature is WIP |

## Uploads_Controller
The uploads_controller.rb file in the IVC Champva module is a key component of the application, responsible for handling file uploads. It contains several private methods that perform various tasks related to file uploads. The get_attachment_ids_and_form method constructs attachment IDs based on the parsed form data and also instantiates a new form object.

The supporting_document_ids method retrieves the IDs of any supporting documents included in the parsed form data. The get_file_paths_and_metadata method generates file paths and metadata for the uploaded files, and also handles any attachments associated with the form. The get_form_id method retrieves the ID of the form being processed. 

## Helpful Links
- [Swagger API UI](https://department-of-veterans-affairs.github.io/va-digital-services-platform-docs/api-reference/) then search "https://dev-api.va.gov/v1/apidocs" to see the ivc_champva endpoint
- [Project MarkDowns](https://github.com/department-of-veterans-affairs/va.gov-team/tree/master/products/health-care/champva)
  - [Team Resource Repository](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/champva/team/team-resource-repository.md)
  - [VES Integration](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/champva/engineering/ves_use_case_and_objectives.md)
  - [Missing PEGA Status Playbook](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/champva/team/ivc-forms-monitoring-playbook.md)
- [DataDog Dashboard](https://vagov.ddog-gov.com/dashboard/zsa-453-at7/ivc-champva-forms)
- [Pega Callback API ADR](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/champva/ADR-callback-api-to-receive-status-from-pega.md)
- [Pega Callback API Implementation Plan](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/health-care/champva/callback-api-technical-spec.md)

## Endpoints
- `/ivc_champva/v1/forms` - Submit a CHAMPVA form
- `/ivc_champva/v1/forms/10-10d-ext` - Submit a 10-10d form with automatic OHI form generation (WIP)
- `/ivc_champva/v1/forms/submit_supporting_documents` - Upload supporting documents for a form
- `/ivc_champva/v1/forms/status_updates` - Receive status updates from PEGA

## Supported Forms
The module currently supports the following forms:
- VHA 10-10d - CHAMPVA Application
- VHA 10-7959c - Other Health Insurance (OHI)
- VHA 10-7959f-1 - Foreign Medical Program Registration
- VHA 10-7959f-2 - Foreign Medical Program Claim
- VHA 10-7959a - CHAMPVA Claim

### Generate files for new forms
`rails ivc_champva:generate\['path to PDF file'\]`

### Updating expired forms
Form PDFs have an expiration date found in the upper right corner below the OMB control number.
To update a form with the latest PDF:
1. Locate the latest version of the form PDF via VA.gov
2. Save the PDF somewhere on disk
3. Run `rails ivc_champva:generate_mapping\['path to PDF file'\]` - a file will be generated:
    - A JSON.erb mapping file in `modules/ivc_champva/app/form_mappings` (it will have "latest" in the name)
4. Compare the new mapping file with the existing one, updating mappings as appropriate.
5. When the mapping file is complete, replace the original mapping file with the new one. 
6. Replace the existing form PDF found in `modules/ivc_champva/templates/vha_{FORM NUMBER}.pdf` with the new one
7. Verify stamping behavior by running ivc_champva unit tests locally and observing the generated PDFs in the `tmp` directory.
8. Adjust the form OMB expiration unit test found in `modules/ivc_champva/spec/models/vha_{FORM NUMBER}_spec.rb`

### Installation
Ensure the following line is in the root project's Gemfile:

  `gem 'ivcchampva', path: 'modules/ivcchampva'`

### License
This module is open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
