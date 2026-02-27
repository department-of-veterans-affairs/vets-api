**Simple Forms API — File Upload Testing Documentation**

## Overview

Corrupt files, unusual encodings, and malformed data are frequent sources of upload failures. This document covers the validation strategy for the `scanned_form_upload` and `supporting_documents_upload` endpoints — including historical failure patterns, the test file library, automated test coverage, and CI integration.

## Historical Failure Cases

Failure categories were identified through production log analysis, incident post-mortems, and dependency audits of PDF::Reader, Shrine, and Common::VirusScan.

| Failure Category | Description | Status |
|---|---|---|
| Malformed PDFs | Valid header but corrupt internal structure | Covered |
| Zero-page PDFs | Structurally valid, zero pages | Covered |
| Non-PDF with .pdf extension | Plain text or binary masquerading as PDF | Covered |
| Zero-byte files | Empty files submitted to endpoint | Covered |
| Encrypted PDFs | Password-protected files without clear error messaging | Covered |
| Oversized files | Files exceeding max upload size | Covered |
| Virus-infected files | Files flagged by VirusScan | Covered |
| Edge case filenames | Long names, Unicode, shell injection attempts | Covered |
| MIME type mismatches | Declared type doesn't match content | Partial |

## Edge Case File Library

Test fixtures reside in `spec/fixtures/files/`. Programmatically generated files (zero-page, corrupt) are created inline via `Tempfile` within test blocks.

| Filename | Purpose | Expected Result |
|---|---|---|
| `doctors-note.pdf` | Valid PDF baseline | 200 OK |
| `doctors-note.jpg` | Valid JPEG | 200 OK |
| `doctors-note.gif` | Valid GIF | 200 OK |
| `malformed-pdf.pdf` | Valid header, corrupt structure | 422 |
| `test_encryption.pdf` | Password-protected (pw: `test`) | 422 without password / 200 with |
| `too_large.pdf` | Exceeds size limit | 422 |
| Zero-page PDF (inline) | Valid structure, 0-page count | ValidationError |
| Corrupt binary (inline) | Random data with .pdf extension | ConversionError |
| Empty Tempfile (inline) | Zero-byte file | 422 |

## Test Coverage

### Scanned Form Upload (`POST /simple_forms_api/v1/scanned_form_upload`)

- **File formats:** Valid PDF and JPEG uploads create PersistentAttachments::VAForm records.
- **Corrupt/malformed files:** Malformed PDFs, corrupt data, and zero-byte files return 422 with no attachment created.
- **Encrypted PDFs:** Missing password returns 422 with error matching `/password|locked|encrypted/`; correct password succeeds.
- **Filenames:** Long (200+ chars), Unicode, and shell injection filenames all return 200.
- **Virus scanning:** Mocked VirusScan returning false triggers 422.

### Supporting Documents Upload (`POST /simple_forms_api/v1/supporting_documents_upload`)

- **File formats:** JPEG and GIF uploads create PersistentAttachments::MilitaryRecords records.
- **Corrupt/malformed files:** Same coverage as scanned form endpoint.
- **Sequential uploads:** Two files for the same form_id both succeed (count +2).
- **Virus scanning:** Same coverage as scanned form endpoint.
- **Feature toggle:** All tests gate behind the `simple_forms_upload_supporting_documents` Flipper flag.

### ScannedFormProcessor Unit Tests

Tests exercise the processor directly with crafted attachments, bypassing HTTP routing:

- **Zero-page PDF** → raises `ValidationError` ("File validation error")
- **Invalid PDF structure** → raises `ValidationError` (detail matches `/corrupt|unreadable/`)
- **Non-PDF content** → raises `ConversionError` ("File conversion error")

## Validation Infrastructure

### Shrine Plugin: ValidatePdfIntegrity

A custom Shrine plugin catches malformed PDFs at the attachment layer using PDF::Reader:

1. **MIME type gate** — only processes `application/pdf` files.
2. **Page count check** — rejects PDFs with zero pages.
3. **Structural integrity** — catches `MalformedPDFError` and `UnsupportedFeatureError`.

### Error Classification

| Error Type | Trigger | User Message |
|---|---|---|
| File validation error | Recognizable PDF but zero pages or malformed structure | "We couldn't open your PDF. Please save it and try uploading it again." |
| File conversion error | Not recognizable as PDF at all | "We were unable to convert your file. Please try again with a different file." |

## CI Integration

- All tests run as part of the standard RSpec suite with no additional infrastructure.
- Virus scanning is mocked in non-security tests via `allow(Common::VirusScan).to receive(:scan).and_return(true)`.
- Inline Tempfiles are cleaned up with `close` and `unlink` in each test.
- Tests are organized under descriptive RSpec contexts: `"with corrupt and malformed files"`, `"with encrypted PDFs"`, `"with edge case filenames"`, etc.

## Key Code Locations

| Component | Path |
|---|---|
| Scanned form upload spec | `modules/simple_forms_api/spec/requests/simple_forms_api/v1/scanned_form_uploads_spec.rb |
| Supporting docs upload spec | `modules/simple_forms_api/spec/requests/simple_forms_api/v1/scanned_form_uploads_spec.rb` |
| ScannedFormProcessor spec | `modules/simple_forms_api/spec/services/scanned_form_processor_spec.rb` |
| ValidatePdfIntegrity plugin | `lib/shrine/plugins/validate_pdf_integrity.rb` |
| Test fixtures | `spec/fixtures/files/` |

## Adding New Edge Case Tests

1. Reproduce the failure with a test file (add sanitized version to fixtures if possible).
2. Classify as validation error (structurally recognizable but invalid) or conversion error (not recognizable).
3. Add integration test under the appropriate context block.
4. Add unit test if the failure reaches ScannedFormProcessor.