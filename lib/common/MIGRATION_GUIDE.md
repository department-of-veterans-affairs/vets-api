# Migration Guide: Using Common Document Processing Services

This guide helps teams migrate from module-specific document processing to the shared `Common::DocumentProcessor` and `Common::FileValidation` services.

## Why Migrate?

- **Code Reuse**: Eliminate duplicate validation and conversion logic
- **Consistency**: Ensure all document processing follows the same patterns
- **Maintainability**: Updates to validation rules happen in one place
- **Testability**: Shared services have comprehensive test coverage
- **Mobile Support**: Services designed for use across web and mobile APIs

## Migration Patterns

### Pattern 1: SimpleFormsApi::ScannedFormProcessor

**Before:**
```ruby
class ScannedFormUploadsController < ApplicationController
  def upload_scanned_form
    attachment = PersistentAttachments::VAForm.new
    attachment.form_id = params['form_id']
    attachment.file_attacher.attach(params['file'], validate: false)

    processor = SimpleFormsApi::ScannedFormProcessor.new(
      attachment,
      password: params['password']
    )
    processor.process!

    render json: PersistentAttachmentVAFormSerializer.new(attachment)
  rescue SimpleFormsApi::ScannedFormProcessor::ConversionError,
         SimpleFormsApi::ScannedFormProcessor::ValidationError => e
    render json: { errors: e.errors }, status: :unprocessable_entity
  end
end
```

**After (Option 1: Keep SimpleFormsApi wrapper, use Common internally):**
```ruby
# In SimpleFormsApi::ScannedFormProcessor
def process!
  # Use Common::DocumentProcessor for core processing
  processor = Common::DocumentProcessor.new(
    attachment.file,
    password: password,
    validation_options: PDF_VALIDATOR_OPTIONS
  )
  
  pdf_path = processor.process!
  
  # Update attachment with processed file
  File.open(pdf_path, 'rb') do |pdf_file|
    attachment.file = pdf_file
    attachment.save
  end
  
  attachment
end
```

**After (Option 2: Use Common::DocumentProcessor directly):**
```ruby
class ScannedFormUploadsController < ApplicationController
  def upload_scanned_form
    attachment = PersistentAttachments::VAForm.new
    attachment.form_id = params['form_id']
    
    # Process file first
    processor = Common::DocumentProcessor.new(
      params['file'],
      password: params['password'],
      validation_options: {
        size_limit_in_bytes: 100.megabytes,
        check_page_dimensions: true,
        check_encryption: true,
        width_limit_in_inches: 78,
        height_limit_in_inches: 101
      }
    )
    result = processor.process
    
    if result.success?
      # Attach processed file
      attachment.file_attacher.attach(File.open(result.file_path), validate: false)
      attachment.save
      
      render json: PersistentAttachmentVAFormSerializer.new(attachment)
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end
end
```

### Pattern 2: Direct PDF Validation

**Before:**
```ruby
validator = PDFUtilities::PDFValidator::Validator.new(
  file_path,
  {
    size_limit_in_bytes: 100.megabytes,
    check_page_dimensions: true,
    check_encryption: true,
    width_limit_in_inches: 21,
    height_limit_in_inches: 21
  }
)
result = validator.validate

if result.valid_pdf?
  # Process file
else
  # Handle errors: result.errors
end
```

**After:**
```ruby
# Use Common::FileValidation for cleaner API
validator = Common::FileValidation::Validator.new(
  file_path,
  Common::FileValidation::STANDARD_PDF_OPTIONS
)
result = validator.validate

if result.valid?
  # Process file
else
  # Handle errors: result.errors
end

# Or use validate! to raise on failure
begin
  validator.validate!
  # Process file
rescue Common::FileValidation::ValidationError => e
  # Handle errors: e.validation_errors
end
```

### Pattern 3: Image to PDF Conversion

**Before:**
```ruby
def convert_image_to_pdf(uploaded_file)
  converter = Common::ConvertToPdf.new(uploaded_file)
  pdf_path = converter.run
  
  # Validate the converted PDF
  validator = PDFUtilities::PDFValidator::Validator.new(pdf_path, options)
  validation_result = validator.validate
  
  unless validation_result.valid_pdf?
    File.delete(pdf_path)
    raise ValidationError, validation_result.errors
  end
  
  pdf_path
rescue => e
  File.delete(pdf_path) if pdf_path && File.exist?(pdf_path)
  raise
end
```

**After:**
```ruby
def convert_image_to_pdf(uploaded_file)
  # DocumentProcessor handles conversion, validation, and cleanup
  processor = Common::DocumentProcessor.new(
    uploaded_file,
    validation_options: {
      size_limit_in_bytes: 50.megabytes,
      check_page_dimensions: true
    }
  )
  
  result = processor.process
  
  if result.success?
    result.file_path
  else
    raise ValidationError.new('Processing failed', result.errors)
  end
end
```

### Pattern 4: Mobile API Integration

**Mobile Controller Example:**
```ruby
class Mobile::V0::DocumentsController < Mobile::ApplicationController
  def upload
    processor = Common::DocumentProcessor.new(
      params[:file],
      password: params[:password],
      validation_options: mobile_validation_options
    )
    
    result = processor.process
    
    if result.success?
      document = save_document(result.file_path, params)
      render json: { 
        success: true, 
        document_id: document.id 
      }, status: :created
    else
      render json: { 
        success: false, 
        errors: result.errors 
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def mobile_validation_options
    {
      size_limit_in_bytes: 25.megabytes,  # Smaller for mobile uploads
      check_page_dimensions: true,
      check_encryption: true,
      width_limit_in_inches: 21,
      height_limit_in_inches: 21
    }
  end
end
```

## Configuration Migration

### Validation Options

The new services use consistent configuration options:

| Old Parameter | New Parameter | Notes |
|--------------|---------------|-------|
| `size_limit_in_bytes` | `size_limit_in_bytes` | Same |
| `check_page_dimensions` | `check_page_dimensions` | Same |
| `check_encryption` | `check_encryption` | Same |
| `width_limit_in_inches` | `width_limit_in_inches` | Same |
| `height_limit_in_inches` | `height_limit_in_inches` | Same |

### Standard Presets

Use predefined configuration presets:

```ruby
# For standard documents (smaller pages)
Common::FileValidation::STANDARD_PDF_OPTIONS
# => { size_limit_in_bytes: 100.megabytes, width_limit_in_inches: 21, height_limit_in_inches: 21 }

# For large documents (bigger pages, like scanned forms)
Common::FileValidation::LARGE_PDF_OPTIONS
# => { size_limit_in_bytes: 100.megabytes, width_limit_in_inches: 78, height_limit_in_inches: 101 }
```

## Error Handling Migration

### Error Response Format

**Before (module-specific):**
```ruby
# Different modules had different error formats
{ errors: ['Error message 1', 'Error message 2'] }
# or
{ error: { code: 'VALIDATION_ERROR', message: 'Details' } }
```

**After (consistent):**
```ruby
# All Common services use structured errors
{
  errors: [
    { title: 'File validation error', detail: 'Document exceeds the file size limit of 100 MB' },
    { title: 'File validation error', detail: 'Document exceeds the page size limit of 21 in. x 21 in.' }
  ]
}
```

### Exception Handling

**Before:**
```ruby
begin
  processor.process!
rescue ModuleSpecific::ProcessingError => e
  # Handle error
end
```

**After:**
```ruby
begin
  processor.process!
rescue Common::DocumentProcessor::ConversionError => e
  # Handle conversion errors: e.errors
rescue Common::DocumentProcessor::ValidationError => e
  # Handle validation errors: e.errors
end

# Or use the non-raising API
result = processor.process
if result.success?
  # Success path
else
  # Handle result.errors
end
```

## Testing Migration

### Test Setup

**Before:**
```ruby
let(:file) { File.open(pdf_path, 'rb') }
let(:processor) { ModuleSpecific::Processor.new(file) }
```

**After:**
```ruby
# Use Rack::Test::UploadedFile for proper file objects
let(:file) { Rack::Test::UploadedFile.new(pdf_path, 'application/pdf') }
let(:processor) { Common::DocumentProcessor.new(file) }

# Don't forget to add the helper
RSpec.describe YourController, :uploader_helpers do
  stub_virus_scan
  # ... tests
end
```

### Test Assertions

**Before:**
```ruby
expect { processor.process! }.not_to raise_error
expect(attachment.persisted?).to be true
```

**After:**
```ruby
result = processor.process
expect(result.success?).to be true
expect(result.file_path).to be_present
expect(File.exist?(result.file_path)).to be true
```

## Backward Compatibility

The new Common services are **additive** - they don't replace existing module-specific services immediately. Teams can:

1. **Keep existing code**: SimpleFormsApi::ScannedFormProcessor continues to work
2. **Gradual migration**: Update one endpoint at a time
3. **Internal refactoring**: Update module services to use Common internally
4. **New features**: Use Common services for all new document processing

## Benefits Summary

✅ **Reduced Code Duplication**: One implementation for all document processing
✅ **Consistent Validation**: Same rules applied across all modules
✅ **Better Testing**: Comprehensive test coverage in common library
✅ **Mobile Ready**: Services designed for mobile API use cases
✅ **Documented**: Complete documentation with examples
✅ **Configurable**: Flexible validation options per use case

## Questions?

Refer to:
- [FILE_PROCESSING.md](FILE_PROCESSING.md) - Complete service documentation
- [README.md](README.md) - Common library overview
- Example tests in `spec/lib/common/document_processor_spec.rb`
