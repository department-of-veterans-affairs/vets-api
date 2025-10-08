# Claims Evidence API

## Overview

The Claims Evidence API module provides a standardized interface for uploading veteran claim evidence documents to the VA's Claims Evidence service. It handles secure file uploads, validation, and metadata submission for disability compensation claims and other VA benefit forms.

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
  base_url: 'https://claimevidence-api.dev.bip.va.gov'
  ssl: true
  timeout: 60
  jwt_secret: <%= ENV['CLAIMS_EVIDENCE_JWT_SECRET'] %>
```

**Required Environment Variables:**
- `CLAIMS_EVIDENCE_JWT_SECRET` - JWT signing secret for API authentication

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
```

### Service Layer Access

```ruby
# Direct API service usage
service = ClaimsEvidenceApi::Service::Files.new
service.folder_identifier = 'VETERAN:ICN:1234567890V123456'
response = service.upload('/path/to/document.pdf', provider_data: metadata)
```

## API Reference

### ClaimsEvidenceApi::Uploader

| Method | Parameters | Description |
|--------|------------|-------------|
| `upload_evidence` | `saved_claim_id`, `persistent_attachment_id`, `form_id`, `doctype` | Upload single evidence document |
| `upload_saved_claim_evidence` | `saved_claim_id`, `claim_stamp_set`, `attachment_stamp_set` | Upload claim with all attachments |

### ClaimsEvidenceApi::Service::Files

| Method | Parameters | Description |
|--------|------------|-------------|
| `upload` | `file_path`, `provider_data` | Direct file upload to API |
| `retrieve` | `file_uuid`, `include_raw_text` | Get file data by UUID |
| `update` | `file_uuid`, `provider_data` | Update file metadata |
| `overwrite` | `file_uuid`, `file_path`, `provider_data` | Replace file content |

## Testing

```bash
# Run module tests
bundle exec rspec modules/claims_evidence_api/spec/
```

### Feature Flag Testing

```ruby
# Stub feature flags in tests
allow(Flipper).to receive(:enabled?)
  .with(:claims_evidence_api_upload)
  .and_return(true)
```

This module provides a modern interface to the Claims Evidence API, replacing legacy VBMS eFolder uploads with improved reliability and monitoring.