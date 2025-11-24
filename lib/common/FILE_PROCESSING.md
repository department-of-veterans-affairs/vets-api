# Common File Processing Services

This document describes the common file processing services available in `lib/common` that can be used across the vets-api application, including by mobile teams and other modules.

## Overview

The common library provides a suite of utilities for processing uploaded documents:

- **File Validation**: Validate file sizes, PDF dimensions, and encryption
- **Image Conversion**: Convert images to PDF format
- **PDF Decryption**: Unlock password-protected PDFs
- **Document Processing**: Combined service for end-to-end document processing

## Services

### 1. Common::DocumentProcessor

The main service that combines conversion, decryption, and validation into a single workflow.

**Location**: `lib/common/document_processor.rb`

**Use Cases**:
- Processing user-uploaded documents for forms
- Mobile API document uploads
- Scanned form processing
- Any workflow requiring document conversion and validation

**Example Usage**:

```ruby
# Basic usage
processor = Common::DocumentProcessor.new(uploaded_file)
result = processor.process

if result.success?
  # Use the processed file
  processed_file = File.open(result.file_path, 'rb')
else
  # Handle errors
  errors = result.errors # Array of error hashes with :title and :detail
end

# With password for encrypted PDFs
processor = Common::DocumentProcessor.new(
  uploaded_file,
  password: 'user_password'
)
result = processor.process

# With custom validation options
processor = Common::DocumentProcessor.new(
  uploaded_file,
  validation_options: {
    size_limit_in_bytes: 50.megabytes,
    check_encryption: false
  }
)
result = processor.process

# Raise exceptions on failure (alternative API)
begin
  pdf_path = processor.process!
  # Use pdf_path
rescue Common::DocumentProcessor::ConversionError => e
  # Handle conversion errors
  errors = e.errors
rescue Common::DocumentProcessor::ValidationError => e
  # Handle validation errors
  errors = e.errors
end
```

**Configuration Options**:

```ruby
{
  # Maximum file size in bytes (default: 100 MB)
  size_limit_in_bytes: 100.megabytes,
  
  # Whether to check PDF page dimensions (default: true)
  check_page_dimensions: true,
  
  # Whether to check for PDF encryption (default: true)
  check_encryption: true,
  
  # Maximum page width in inches (default: 78)
  width_limit_in_inches: 78,
  
  # Maximum page height in inches (default: 101)
  height_limit_in_inches: 101
}
```

### 2. Common::FileValidation

Validates files according to configurable rules, primarily focused on PDFs.

**Location**: `lib/common/file_validation.rb`

**What is Validated**:
- File size (must not exceed configured limit)
- PDF page dimensions (width/height in inches)
- PDF encryption status (user password vs owner password)
- PDF validity (can be parsed and read)

**Example Usage**:

```ruby
# Basic validation
validator = Common::FileValidation::Validator.new(
  file_path,
  size_limit_in_bytes: 50.megabytes
)
result = validator.validate

if result.valid?
  # File is valid
else
  # Handle validation errors
  result.errors.each do |error|
    puts error
  end
end

# Validate and raise exception on failure
begin
  validator.validate!
rescue Common::FileValidation::ValidationError => e
  errors = e.validation_errors
end

# Use standard presets
Common::FileValidation::STANDARD_PDF_OPTIONS
# => { size_limit_in_bytes: 100MB, check_page_dimensions: true, 
#      width_limit_in_inches: 21, height_limit_in_inches: 21 }

Common::FileValidation::LARGE_PDF_OPTIONS
# => { size_limit_in_bytes: 100MB, check_page_dimensions: true,
#      width_limit_in_inches: 78, height_limit_in_inches: 101 }
```

### 3. Common::ConvertToPdf

Converts image files to PDF format.

**Location**: `lib/common/convert_to_pdf.rb`

**Supported Input Formats**:
- All image formats supported by ImageMagick (jpg, png, gif, tiff, etc.)
- PDFs (pass-through, no conversion needed)

**Example Usage**:

```ruby
converter = Common::ConvertToPdf.new(uploaded_file)
pdf_path = converter.run

# pdf_path is a temporary file path to the converted PDF
# The caller is responsible for managing this file
```

**Note**: This service uses ImageMagick via the MiniMagick gem. Files are converted at 72 DPI on letter-sized pages.

### 4. Common::PdfHelpers

Utilities for PDF manipulation, primarily decryption.

**Location**: `lib/common/pdf_helpers.rb`

**Features**:
- Decrypt password-protected PDFs
- Remove encryption from PDFs

**Example Usage**:

```ruby
# Decrypt a password-protected PDF
Common::PdfHelpers.unlock_pdf(
  input_file_path,
  password,
  output_file_path
)

# This will raise Common::Exceptions::UnprocessableEntity if:
# - Password is incorrect
# - PDF is invalid or corrupt
```

### 5. Common::FileHelpers

General file manipulation utilities.

**Location**: `lib/common/file_helpers.rb`

**Features**:
- Generate random file paths
- Create temporary files
- Delete files safely
- Generate ClamAV-compatible temp files

**Example Usage**:

```ruby
# Generate a random file path
path = Common::FileHelpers.random_file_path('.pdf')
# => "tmp/a1b2c3d4e5f6.pdf"

# Create a temporary file with content
path = Common::FileHelpers.generate_random_file(file_content, '.pdf')

# Create a ClamAV temp file (for virus scanning)
path = Common::FileHelpers.generate_clamav_temp_file(file_content)

# Safely delete a file if it exists
Common::FileHelpers.delete_file_if_exists(file_path)
```

## Backend Validation Details

The following validations are performed by the backend services:

### 1. File Size Validation
- **What**: Checks that file size doesn't exceed the configured limit
- **Default**: 100 MB
- **Configurable**: Yes, via `size_limit_in_bytes` option
- **Error Message**: "Document exceeds the file size limit of X MB"

### 2. File Format Validation
- **What**: Ensures file is a valid PDF or convertible image format
- **Supported Formats**: PDF, JPG, PNG, GIF, TIFF (any ImageMagick-supported image)
- **Error Message**: "PDF conversion failed, unsupported file type: {type}"

### 3. PDF Encryption Validation
- **What**: Checks for PDF encryption (user password or owner password)
- **User Password**: Document cannot be opened without password - **rejected if no password provided**
- **Owner Password**: Document is encrypted but can be opened - **rejected**
- **Configurable**: Yes, via `check_encryption` option
- **Error Messages**:
  - "Document is locked with a user password"
  - "Document is encrypted with an owner password"

### 4. PDF Page Dimension Validation
- **What**: Ensures PDF pages don't exceed maximum dimensions
- **Default Limits**: 78 inches width x 101 inches height
- **Configurable**: Yes, via `width_limit_in_inches` and `height_limit_in_inches`
- **Error Message**: "Document exceeds the page size limit of X in. x Y in."

### 5. PDF Validity Check
- **What**: Ensures the PDF can be parsed and read
- **Error Message**: "Document is not a valid PDF"

### 6. Password-Protected PDF Decryption
- **What**: Unlocks PDFs encrypted with a user password
- **Requires**: Password provided by user
- **Error Message**: "The password you entered is incorrect. Please try again."
- **Note**: After decryption, the PDF is validated again to ensure it meets all requirements

## Configuration Requirements

### Dependencies

The file processing services require:

1. **ImageMagick**: For image-to-PDF conversion
   - Install: `apt-get install imagemagick` or `brew install imagemagick`
   - Used by: `Common::ConvertToPdf`

2. **HexaPDF gem**: For PDF decryption
   - Installed via Gemfile
   - Used by: `Common::PdfHelpers`

3. **PdfInfo**: For PDF metadata reading
   - Install: `apt-get install poppler-utils` or `brew install poppler`
   - Used by: `PDFUtilities::PDFValidator`

4. **MiniMagick gem**: Ruby interface to ImageMagick
   - Installed via Gemfile
   - Used by: `Common::ConvertToPdf`

### Environment Setup

No special environment variables are required. All configuration is done via method parameters.

### Temporary File Management

All services that create temporary files will attempt to clean them up, but callers should also be aware:

- `Common::ConvertToPdf`: Returns a temp file path in `tmp/` or `clamav_tmp/`
- `Common::DocumentProcessor`: Automatically cleans up temp files on success or failure
- `Common::PdfHelpers`: Writes to provided output path (caller manages)

### Error Handling

All services use consistent error handling:

1. **Validation Errors**: Return structured error hashes with `:title` and `:detail`
2. **Exceptions**: Raise `Common::Exceptions::UnprocessableEntity` for known error conditions
3. **Logging**: All errors are logged to Rails logger

Example error format:
```ruby
{
  title: 'File validation error',
  detail: 'Document exceeds the file size limit of 100 MB'
}
```

## Migration Guide for SimpleFormsApi

If you're migrating from `SimpleFormsApi::ScannedFormProcessor` to `Common::DocumentProcessor`:

**Before**:
```ruby
processor = SimpleFormsApi::ScannedFormProcessor.new(
  attachment,
  password: params['password']
)
processor.process!
```

**After**:
```ruby
processor = Common::DocumentProcessor.new(
  attachment.file,
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
  attachment.file = File.open(result.file_path, 'rb')
  attachment.save
else
  # Handle errors from result.errors
end
```

## For Mobile Team

The common file processing services are designed to be used by the mobile API:

1. **No Frontend Validation Required**: All validation happens on the backend
2. **Consistent Error Format**: All services return structured error messages
3. **Flexible Configuration**: Validation rules can be adjusted per endpoint
4. **Password Support**: Can handle encrypted PDFs with user-provided passwords
5. **Image Upload Support**: Automatically converts images to PDF

**Recommended Flow for Mobile**:

1. User selects file in mobile app
2. Mobile app uploads file to backend endpoint
3. Backend uses `Common::DocumentProcessor` to process file
4. Backend returns success with confirmation or error with details
5. Mobile app shows appropriate message to user

**Error Handling Example**:

```ruby
# In your mobile controller
def upload_document
  processor = Common::DocumentProcessor.new(
    params[:file],
    password: params[:password]
  )
  result = processor.process

  if result.success?
    render json: { success: true, document_id: save_document(result.file_path) }
  else
    render json: { 
      success: false, 
      errors: result.errors 
    }, status: :unprocessable_entity
  end
end
```

## Testing

Example test patterns for using these services:

```ruby
RSpec.describe 'Document Processing' do
  let(:pdf_path) { Rails.root.join('spec', 'fixtures', 'files', 'test.pdf') }
  let(:jpg_path) { Rails.root.join('spec', 'fixtures', 'files', 'test.jpg') }

  describe Common::DocumentProcessor do
    it 'processes a PDF file' do
      processor = Common::DocumentProcessor.new(File.open(pdf_path, 'rb'))
      result = processor.process
      
      expect(result.success?).to be true
      expect(result.file_path).to be_present
      expect(File.exist?(result.file_path)).to be true
    end

    it 'converts an image to PDF' do
      processor = Common::DocumentProcessor.new(File.open(jpg_path, 'rb'))
      result = processor.process
      
      expect(result.success?).to be true
      pdf_content = File.read(result.file_path)
      expect(pdf_content).to start_with('%PDF-')
    end

    it 'handles validation errors' do
      allow_any_instance_of(Common::FileValidation::Validator)
        .to receive(:validate)
        .and_return(double(valid?: false, errors: ['File too large']))

      processor = Common::DocumentProcessor.new(File.open(pdf_path, 'rb'))
      result = processor.process
      
      expect(result.success?).to be false
      expect(result.errors).to be_present
    end
  end
end
```

## Support

For questions or issues with these services:
1. Check the source code in `lib/common/`
2. Review existing tests in `spec/lib/common/`
3. Consult this documentation
4. Reach out to the platform team
