# Claims Evidence API

## Overview

The Claims Evidence API module provides a standardized interface for uploading veteran claim evidence documents to the VA's Claims Evidence service. It handles secure file uploads, validation, and metadata submission for disability compensation claims and other VA benefit forms.

This module provides a modern interface to the Claims Evidence API, replacing legacy VBMS eFolder uploads with improved reliability and monitoring.

There is already virus scanning as part of the evidence upload on the site (persistent attachment creation), but this also runs clamav scanning as part of the validation during upload via the service

PDF stamping can be handled by the Uploader, but is not required.  The stamping is performed by using PDFUtilies::PDFStamper, and providing the name of a predefined set or an array of stamp parameters.  Different sets can be applied to the generated claim pdf and the attachment pdfs.  The `evidence.created_at` is passed as the timestamp to the stamping function - `PDFUtilities::PDFStamper.new(stamp_set).run(file_path, timestamp: evidence.created_at)`.

**Key Features:**
- Secure document upload with JWT authentication
- File validation and virus scanning
- Folder-based organization by veteran ICN
- Comprehensive error handling and monitoring
- PDF stamping support

**Related VA Services:** Claims Evidence API (VEFS), VBMS eFolder

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
| Claims Evidence API | - | VA external service |

## Configuration

Configure the module through the main application settings:

```yaml
# config/settings.yml
claims_evidence_api:
  base_url: <%= ENV['claims_evidence_api__base_url'] %>
  breakers_error_threshold: 80
  include_request: false
  jwt_secret: <%= ENV['claims_evidence_api__jwt_secret'] %>
  mock: false
  ssl: true
  timeout:
    open: 30
    read: 30
```

For local development you can establish a tunnel to a VA forward-proxy, mapping a local port.
The local settings would then contain `base_url: https://localhost:[PORT]/api/v1/rest` and
the jwt_secret would be the same for staging/dev (no connection to prod)

See `script/forward-proxy-tunnel.sh`

## Usage Examples

### Primary Interface (Uploader)

```ruby
# Upload claim evidence
uploader = ClaimsEvidenceApi::Uploader.new('VETERAN:ICN:1234567890V123456')
file_uuid = uploader.upload_evidence(
  saved_claim_id: claim.id,
  persistent_attachment_id: attachment.id,
  form_id: '686C-674',
  doctype: 10
)

# OR

claim_pdf_uuid = uploader.upload_saved_claim_evidence(claim.id)
```

#### With providing stamp sets

```ruby
claim_stamp_set = [ { text: 'VA.GOV', x: 5, y: 5 }, { text: 'FDC Reviewed', x: 430, y: 820 } ]
attachment_stamp_set = :va_received_at # predefined by 'registering' the set `::PDFUtilities::PDFStamper.register_stamps(identifier, stamps)`
claim_pdf_uuid = uploader.upload_saved_claim_evidence(claim.id, claim_stamp_set:, attachment_stamp_set:)
```

### Service Layer Access

```ruby
# Direct API service usage
service = ClaimsEvidenceApi::Service::Files.new
service.folder_identifier = 'VETERAN:ICN:1234567890V123456'
response = service.upload('/path/to/document.pdf', provider_data: metadata)
```

## API Reference

https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html

### ClaimsEvidenceApi::Uploader

| Method | Parameters | Description |
|--------|------------|-------------|
| `upload_evidence` | `saved_claim_id`, `persistent_attachment_id`, `form_id`, `doctype` | Upload single evidence document |
| `upload_saved_claim_evidence` | `saved_claim_id`, `claim_stamp_set`, `attachment_stamp_set` | Upload claim with all attachments |

### ClaimsEvidenceApi::Service::Files

| Method | Parameters | Description |
|--------|------------|-------------|
| `upload` | `file_path`, `provider_data` | Direct file upload to API |
| `retrieve` | `uuid`, `include_raw_text` | Get file data by UUID |
| `update` | `uuid`, `provider_data` | Update file metadata |
| `overwrite` | `uuid`, `file_path`, `provider_data` | Replace file content |

### ClaimsEvidenceApi::Service::Search

| Method | Parameters | Description |
|--------|------------|-------------|
| `find` | `results_per_page`, `page`, `filters`, `sort`, `transform` | find documents a folder_identifier |

### ClaimsEvidenceApi::Service::Association

| Method | Parameters | Description |
|--------|------------|-------------|
| `retrieve` | `uuid` | retrieve the list of associated claims |
| `update` | `uuid`, `claim_ids` | update associated claims for a specific UUID |

### ClaimsEvidenceApi::Service::ContentSources

| Method | Parameters | Description |
|--------|------------|-------------|
| `retrieve` | &nbsp; | retrieve the list of content sources |

### ClaimsEvidenceApi::Service::DocumentTypes

| Method | Parameters | Description |
|--------|------------|-------------|
| `retrieve` | &nbsp; | retrieve the list of document types |

### ClaimsEvidenceApi::Service::UploadSources

| Method | Parameters | Description |
|--------|------------|-------------|
| `retrieve` | &nbsp; | retrieve the list of upload sources |

## Testing

```bash
# Run module tests
bundle exec rspec modules/claims_evidence_api
```

To check the connection, use the DocumentTypes service:
```ruby
response = ClaimsEvidenceApi::Service::DocumentTypes.get
response.body # should display the list of document types
```

To check if a folder_identifier is valid, use ContentSources or UploadSources:
```ruby
service = ClaimsEvidenceApi::Service::ContentSources.new
service.folder_identifier = 'VETERAN:ICN:1234567890V123456'
response = service.retrieve
response.body # should display the list of content sources
```
