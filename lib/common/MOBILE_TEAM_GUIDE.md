# Quick Start Guide: Common File Processing for Mobile Team

This guide helps the mobile team quickly integrate with the new common file processing services in vets-api.

## TL;DR

We've created reusable backend services for document processing that handle:
- ✅ Image to PDF conversion (.jpg, .png, .gif, .tiff → PDF)
- ✅ PDF decryption (password-protected files)
- ✅ File validation (size, dimensions, encryption)
- ✅ Structured error responses

**You don't need to duplicate any of this validation on mobile** - just send files to the backend and handle the response.

## Quick Example

### Mobile App Flow

1. User selects a file (image or PDF) on mobile device
2. User optionally enters password for encrypted PDFs
3. Mobile app uploads file to your backend endpoint
4. Backend processes and validates the file
5. Backend returns success with document ID or structured errors
6. Mobile app displays result to user

### Backend Endpoint (Copy & Paste)

```ruby
class Mobile::V0::DocumentsController < Mobile::ApplicationController
  # POST /mobile/v0/documents
  def upload
    processor = Common::DocumentProcessor.new(
      params[:file],
      password: params[:password],
      validation_options: {
        size_limit_in_bytes: 25.megabytes,      # Adjust for mobile
        check_page_dimensions: true,
        check_encryption: true,
        width_limit_in_inches: 21,
        height_limit_in_inches: 21
      }
    )
    
    result = processor.process
    
    if result.success?
      # Save the processed PDF
      document = Document.create!(
        user: current_user,
        file_path: result.file_path,
        document_type: params[:document_type]
      )
      
      render json: { 
        success: true, 
        document_id: document.id,
        message: 'Document uploaded successfully'
      }, status: :created
    else
      render json: { 
        success: false, 
        errors: result.errors 
      }, status: :unprocessable_entity
    end
  end
end
```

### Mobile API Response Format

**Success Response:**
```json
{
  "success": true,
  "document_id": "abc123",
  "message": "Document uploaded successfully"
}
```

**Error Response:**
```json
{
  "success": false,
  "errors": [
    {
      "title": "File validation error",
      "detail": "Document exceeds the file size limit of 25 MB"
    }
  ]
}
```

## What Gets Validated on Backend

| Validation | Default | Configurable | Error Message |
|-----------|---------|--------------|---------------|
| File size | 100 MB | Yes | "Document exceeds the file size limit of X MB" |
| File format | PDF, JPG, PNG, GIF, TIFF | No | "PDF conversion failed, unsupported file type: {type}" |
| PDF encryption | Check enabled | Yes | "Document is locked with a user password" |
| Page dimensions | 21" × 21" | Yes | "Document exceeds the page size limit of X × Y in." |
| PDF validity | Always checked | No | "Document is not a valid PDF" |

## Configuration Options

```ruby
# Recommended for mobile (smaller limits)
{
  size_limit_in_bytes: 25.megabytes,      # Mobile network friendly
  check_page_dimensions: true,
  check_encryption: true,
  width_limit_in_inches: 21,              # Standard letter size
  height_limit_in_inches: 21
}

# For larger documents
{
  size_limit_in_bytes: 50.megabytes,
  check_page_dimensions: true,
  check_encryption: true,
  width_limit_in_inches: 78,              # Large scanned forms
  height_limit_in_inches: 101
}

# Skip encryption check (if passwords not supported)
{
  size_limit_in_bytes: 25.megabytes,
  check_page_dimensions: true,
  check_encryption: false                 # Allows encrypted PDFs
}
```

## Handling Encrypted PDFs

If your mobile app supports password-protected PDFs:

```ruby
# Mobile sends password in params
def upload
  processor = Common::DocumentProcessor.new(
    params[:file],
    password: params[:password]  # Mobile provides this
  )
  
  result = processor.process
  
  # If password is wrong, you'll get this error:
  # {
  #   title: "Invalid password",
  #   detail: "The password you entered is incorrect. Please try again."
  # }
end
```

If you don't want to support encrypted PDFs, just don't pass a password - the validation will reject encrypted files automatically.

## Mobile UI Recommendations

### Before Upload
1. **File Size Check**: Pre-validate file size on mobile to avoid unnecessary uploads
   ```swift
   // iOS example
   let maxSize = 25 * 1024 * 1024 // 25 MB
   if fileSize > maxSize {
       showError("File too large. Maximum size is 25 MB")
   }
   ```

2. **File Type Check**: Only allow supported types in file picker
   - Supported: PDF, JPG, PNG, GIF, TIFF

### During Upload
1. **Show Progress**: Upload can take time for large files
2. **Allow Cancellation**: User should be able to cancel

### After Upload
1. **Parse Backend Response**: Check `success` field
2. **Display Errors**: Show user-friendly messages from `errors` array
3. **Handle Success**: Navigate to success screen or show confirmation

### Error Message Mapping

Map backend error details to user-friendly messages:

```javascript
// Example mapping
const errorMessages = {
  'exceeds the file size limit': 'Your file is too large. Please choose a file under 25 MB.',
  'unsupported file type': 'This file type is not supported. Please use PDF or image files.',
  'locked with a user password': 'This PDF is password-protected. Please enter the password.',
  'Invalid password': 'The password you entered is incorrect. Please try again.',
  'exceeds the page size limit': 'The document pages are too large. Please use standard-sized pages.',
  'not a valid PDF': 'This file appears to be corrupted. Please try a different file.'
}
```

## Common Issues & Solutions

### Issue: Upload fails with "conversion error"
**Solution**: File may be corrupted. Ask user to try a different file.

### Issue: Upload succeeds but PDF is blank
**Solution**: This shouldn't happen with the new service - it validates PDFs are readable. Report as bug.

### Issue: Large files time out
**Solution**: Consider implementing resumable uploads or reducing file size limit for mobile.

### Issue: User password not working
**Solution**: Verify mobile app sends password in correct parameter. Backend expects `params[:password]`.

## Testing Your Integration

### Test Cases to Cover

1. **Valid PDF upload**: Should succeed
2. **Valid image upload (JPG)**: Should succeed and convert to PDF
3. **File too large**: Should return validation error
4. **Unsupported file type (e.g., .docx)**: Should return conversion error
5. **Encrypted PDF without password**: Should return encryption error
6. **Encrypted PDF with wrong password**: Should return password error
7. **Encrypted PDF with correct password**: Should succeed
8. **Corrupted PDF**: Should return validation error

### Sample Test Files

Test files available in vets-api:
- Valid PDF: `spec/fixtures/files/doctors-note.pdf`
- Valid JPG: `spec/fixtures/files/doctors-note.jpg`
- Encrypted PDF: `spec/fixtures/files/test_encryption.pdf` (password: "test")

## API Endpoint Checklist

When creating your mobile document upload endpoint:

- [ ] Add `Common::DocumentProcessor.new` call with mobile-friendly options
- [ ] Handle `result.success?` for success path
- [ ] Handle `result.errors` for error path
- [ ] Return consistent JSON response format
- [ ] Set appropriate HTTP status codes (201 for success, 422 for validation errors)
- [ ] Save processed file from `result.file_path`
- [ ] Add endpoint to your routes
- [ ] Add authentication/authorization checks
- [ ] Write request specs for the endpoint
- [ ] Test with actual mobile app

## Need More Info?

Detailed documentation:
- **Complete Guide**: `lib/common/FILE_PROCESSING.md`
- **Migration Examples**: `lib/common/MIGRATION_GUIDE.md`
- **Test Examples**: `spec/lib/common/document_processor_spec.rb`

Questions? Reach out to the platform team or check the Slack thread.

## Example Mobile Request

```bash
# Using curl (simulating mobile app)
curl -X POST \
  https://api.va.gov/mobile/v0/documents \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@/path/to/document.pdf" \
  -F "password=secret123" \
  -F "document_type=medical_record"
```

## Quick Reference

```ruby
# Basic usage - most common pattern
processor = Common::DocumentProcessor.new(params[:file])
result = processor.process

if result.success?
  # result.file_path contains processed PDF
  # Save it, create record, etc.
else
  # result.errors contains structured error array
  # Return to mobile app
end

# With password
processor = Common::DocumentProcessor.new(
  params[:file],
  password: params[:password]
)

# With custom validation
processor = Common::DocumentProcessor.new(
  params[:file],
  validation_options: { size_limit_in_bytes: 25.megabytes }
)
```

That's it! You're ready to integrate document processing into your mobile API. 🎉
