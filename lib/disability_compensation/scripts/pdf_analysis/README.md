# VA Form 526 PDF Analysis Scripts

This directory contains 5 scripts for comprehensive VA Form 526 PDF analysis and document identifier extraction:

## Scripts Overview

### 1. `find_pdfs_from_from526submissions.rb` - Complete Analysis Workflow
Orchestrates the full VA Form 526 analysis pipeline.
- **Usage**: `rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_from_from526submissions.rb [start_date] [end_date]`
- **Process**: Extracts claim IDs → checks PDFs → compiles comprehensive results
- **Output**: Complete analysis with claim IDs, PDF status, and all document identifiers

### 2. `find_submittedClaimIds_from_form526submissions.rb` - Claim ID Analysis
Analyzes Form526Submission records and extracts claim IDs.
- **Usage**: `rails runner lib/disability_compensation/scripts/pdf_analysis/find_submittedClaimIds_from_form526submissions.rb [start_date] [end_date]`
- **Analysis**: Statistics on submissions with/without claim IDs
- **Output**: JSON export of claim IDs and log of submissions without IDs

### 3. `find_pdfs_for_submittedClaimIds.rb` - Batch PDF Checking
Processes multiple claim IDs for PDF presence and document identifiers.
- **Usage**: `rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_for_submittedClaimIds.rb <claim_ids_file>`
- **Input**: Text file with claim IDs (one per line)
- **Output**: JSON results with PDF status and complete document information

### 4. `find_pdfs_for_submittedClaimId.rb` - Single Claim Analysis
Retrieves all supporting document identifiers for one claim via Lighthouse API.
- **Usage**: `rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_for_submittedClaimId.rb <claim_id>`
- **Output**: JSON with supporting documents, VA Form 21-526 status, and exit code
- **Identifiers**: document_id, document_type_label, original_file_name, tracked_item_id, upload_date

### 5. `record_to_aws.rb` - AWS S3 Upload
Uploads analysis results to AWS S3 for storage and sharing.
- **Usage**: `rails runner lib/disability_compensation/scripts/pdf_analysis/record_to_aws.rb <results_file> [bucket_name] [prefix]`
- **Requirements**: AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
- **Output**: S3 URL confirmation and optional presigned URL

## Document Identifiers Returned

The PDF analysis scripts return comprehensive document information from the Lighthouse API, including all available identifiers for each supporting document:

- **`document_id`**: Unique document identifier in VA systems
- **`document_type_label`**: Human-readable document type description (e.g., "VA 21-526 Veterans Application for Compensation or Pension")
- **`original_file_name`**: Original filename of the uploaded document
- **`tracked_item_id`**: Associated tracked item identifier for claim processing
- **`upload_date`**: Date when the document was uploaded to VA systems

## Logging

All scripts use structured logging with timestamps. Control verbosity with:

```bash
# Default INFO level
rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_from_from526submissions.rb

# Debug level for detailed output
LOG_LEVEL=DEBUG rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_from_from526submissions.rb
```

## Usage Examples

```bash
# Analyze and extract claim IDs from submissions (last 7 days by default)
rails runner lib/disability_compensation/scripts/pdf_analysis/find_submittedClaimIds_from_form526submissions.rb

# Check PDFs and retrieve all document identifiers for claims in claim_ids.txt
rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_for_submittedClaimIds.rb claim_ids.txt

# Check single claim for PDF and retrieve all document identifiers
rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_for_submittedClaimId.rb ABC123456

# Complete analysis workflow (claim IDs + all document identifiers)
rails runner lib/disability_compensation/scripts/pdf_analysis/find_pdfs_from_from526submissions.rb

# Upload results to AWS S3
rails runner lib/disability_compensation/scripts/pdf_analysis/record_to_aws.rb combined_check_results_20260209.json
```