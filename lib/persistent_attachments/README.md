# PersistentAttachment README

## Overview

PersistentAttachment is a Rails model that provides secure, encrypted file upload capabilities for the VA.gov platform. It serves as the persistent backing for Shrine file uploads, primarily used by SavedClaim and form submission processes to handle veteran document uploads with strong security and validation requirements.

## What It Does

- **Secure File Storage**: Encrypts uploaded files using AWS KMS encryption
- **Document Validation**: Validates file types, sizes, and PDF integrity for claim evidence
- **Form Integration**: Links uploaded documents to specific VA forms and saved claims
- **PDF Processing**: Converts various document formats to PDF and applies VA.gov timestamps
- **Audit Trail**: Tracks document upload attempts, successes, and failures for monitoring

## Key Features

### Security & Encryption
- All file data encrypted at rest using KMS keys
- Sensitive file paths filtered from error logs
- Password-protected PDF unlocking with secure error handling
- Automatic KMS key rotation support

### Supported Document Types
- PDF (`.pdf`)
- JPEG Images (`.jpg`, `.jpeg`)
- PNG Images (`.png`)

### File Validation
- Minimum file size: 1KB
- PDF corruption detection
- Stamped PDF validation for Benefits Intake API compatibility
- File extension allowlist enforcement

## How It's Used

### Document Upload Flow

1. **Upload Request**: Veterans upload documents through ClaimDocumentsController
2. **Type Selection**: Controller selects appropriate PersistentAttachment subclass based on form ID
3. **Validation**: File type, size, and PDF integrity validation
4. **Encryption**: File data encrypted and stored securely
5. **Association**: Linked to SavedClaim for claim processing

### Form-Specific Attachments

Different VA forms use specialized attachment classes:

```ruby
# Dependency claims (686C family)
PersistentAttachments::DependencyClaim

# Legacy claims
PersistentAttachments::LgyClaim

# General claim evidence (default)
PersistentAttachments::ClaimEvidence
```

### PDF Processing Pipeline

```ruby
# Convert to PDF if needed
attachment.to_pdf

# Apply VA.gov timestamp
PDFUtilities::DatestampPdf.new(pdf).run(text: 'VA.GOV', x: 5, y: 5)

# Validate for Benefits Intake API
BenefitsIntake::Service.new.valid_document?(document: pdf)
```

## Database Schema

```ruby
create_table "persistent_attachments" do |t|
  t.uuid "guid"                                    # Unique identifier
  t.string "type"                                  # STI for subclasses
  t.string "form_id"                               # Associated VA form
  t.integer "saved_claim_id"                       # Link to SavedClaim
  t.integer "doctype"                              # Document type code
  t.text "file_data_ciphertext"                    # Encrypted file data
  t.text "encrypted_kms_key"                       # KMS encryption key
  t.boolean "needs_kms_rotation", default: false   # Key rotation flag
  t.datetime "completed_at"                        # Processing completion
  t.timestamps
end
```

## Usage Examples

### Basic Document Upload

```ruby
# Controller creates attachment based on form ID
attachment = PersistentAttachments::ClaimEvidence.new(
  form_id: '21-526EZ',
  doctype: 10
)
attachment.file = uploaded_file
attachment.save!
```

## Attachment Sanitization

The `PersistentAttachments::Sanitizer` handles corrupted or undecryptable attachments:

- Attempts to decrypt all attachments for a claim
- Destroys attachments that cannot be decrypted
- Updates form data to remove references to destroyed attachments
- Maintains data integrity for claim processing

## Integration Points

- **SavedClaim**: Primary association for claim processing
- **InProgressForm**: Links to form drafts and submissions
- **Benefits Intake API**: PDF validation and submission
- **Shrine**: File upload and storage management
- **ClaimDocumentsController**: Primary upload endpoint