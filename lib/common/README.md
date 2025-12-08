# Common Library

The `lib/common` directory contains shared utilities and services that can be used across the vets-api application, including by different modules and teams (web, mobile, etc.).

## Services Available

### File & Document Processing

See [FILE_PROCESSING.md](FILE_PROCESSING.md) for comprehensive documentation.

- **`Common::DocumentProcessor`** - Complete document processing pipeline (conversion, decryption, validation)
- **`Common::FileValidation`** - File validation service with configurable rules
- **`Common::ConvertToPdf`** - Convert images to PDF format
- **`Common::PdfHelpers`** - PDF manipulation utilities (decryption, etc.)
- **`Common::FileHelpers`** - General file utilities (temp files, cleanup, etc.)
- **`Common::VirusScan`** - Virus scanning integration

### Client Infrastructure

- **`Common::Client`** - Base classes and concerns for API clients
  - Session management
  - Error handling
  - Monitoring and logging
  - Request/response middleware
- **`Common::Client::Configuration`** - Configuration for REST and SOAP clients

### Data Models

- **`Common::Models`** - Base model classes and concerns
  - Attribute types (dates, times, strings)
  - Collections and resources
  - Redis caching (cache_aside concern)
- **`Common::HashHelpers`** - Hash manipulation utilities

### Exceptions

Common::Exceptions is a library intended to help make exception classes serializable.

It is particularly suited for helping to render JSONAPI style errors. It is divided into
two types, `internal` exceptions that are raised within the various models and controllers
of your Rails application and `external` exceptions that are raised by backend services.

The external exceptions will need to be setup properly using custom middlewares.

## Purpose

To be able to jump out of the call stack and render an error response as part of an
orchestration layer for various backend service integrations.

## Usage

Each exception class has a unique way of being invoked. To customize the messages for these
error classes an i18n locales file is available.

## For Mobile Teams

The common library services are designed to be reusable by the mobile API:

1. **Backend Validation**: All validation happens on the backend - no need to duplicate logic in mobile apps
2. **Consistent Error Format**: All services return structured error messages
3. **Flexible Configuration**: Validation rules can be adjusted per endpoint
4. **Complete Processing**: Handle image conversion, PDF decryption, and validation in one place

See [FILE_PROCESSING.md](FILE_PROCESSING.md) for specific mobile integration patterns.

## Adding New Common Services

When adding new services to the common library:

1. Ensure the service is truly reusable across multiple modules/teams
2. Provide clear documentation with examples
3. Include comprehensive tests
4. Use consistent error handling patterns
5. Make configuration options explicit and documented
6. Consider backward compatibility
