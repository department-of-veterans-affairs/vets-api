# SchemaValidator Guide

The `SchemaValidator` is a generic service object for validating data against JSON schemas. It supports both direct schema validation and automatic Swagger schema extraction.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Swagger Schema Validation](#swagger-schema-validation)
- [Advanced Usage](#advanced-usage)
- [Testing](#testing)
- [Examples](#examples)
- [Best Practices](#best-practices)

## Basic Usage

### With a Direct Schema

```ruby
schema = {
  type: 'object',
  required: %w[name email],
  properties: {
    name: { type: 'string' },
    email: { type: 'string', format: 'email' }
  }
}

data = { 'name' => 'John Doe', 'email' => 'john@example.com' }

validator = SchemaValidator.new(data, schema: schema)

# Check if valid
if validator.valid?
  # Data is valid
else
  # Data is invalid
  validator.errors.each { |error| puts error }
end

# Or raise an exception if invalid
validator.validate! # raises Common::Exceptions::SchemaValidationErrors if invalid
```

## Swagger Schema Validation

The most powerful feature is automatic schema extraction from your Swagger documentation.

### In Controllers

```ruby
class V0::MyFormController < ApplicationController
  def download_pdf
    parsed_form = parse_form_data
    
    # Validate against Swagger schema
    SchemaValidator.new(
      parsed_form,
      swagger_path: '/v0/my_form',
      swagger_method: :post
    ).validate!
    
    # Continue processing...
  end
end
```

### How It Works

1. The validator looks up your Swagger definition at the specified path and method
2. Extracts the schema from the first parameter (or specify `swagger_param_index`)
3. Validates your data against that schema
4. Caches the schema for performance

## Advanced Usage

### Custom Parameter Index

If your endpoint has multiple parameters, specify which one contains the schema:

```ruby
SchemaValidator.new(
  data,
  swagger_path: '/v0/endpoint',
  swagger_method: :post,
  swagger_param_index: 1  # Use the second parameter's schema
).validate!
```

### Using Cached Schemas

For better performance in high-traffic scenarios:

```ruby
# The schema is automatically cached on first use
SchemaValidator.cached_swagger_schema('/v0/form214192', :post)

# Clear cache if needed (e.g., in tests or after schema updates)
SchemaValidator.clear_cache!
```

### Checking Validity Without Raising

```ruby
validator = SchemaValidator.new(data, schema: schema)

if validator.valid?
  # Process valid data
  process_data(data)
else
  # Handle errors
  log_errors(validator.errors)
  notify_user(validator.errors)
end
```

## Testing

### Testing Your Controller

```ruby
RSpec.describe V0::MyFormController, type: :controller do
  describe 'POST #submit' do
    it 'validates against Swagger schema' do
      expect(SchemaValidator).to receive(:new).with(
        hash_including('requiredField'),
        swagger_path: '/v0/my_form',
        swagger_method: :post
      ).and_call_original

      post :submit, params: { form: valid_form_data.to_json }
      expect(response).to have_http_status(:ok)
    end

    it 'rejects invalid data' do
      allow_any_instance_of(SchemaValidator).to receive(:validate!)
        .and_raise(Common::Exceptions::SchemaValidationErrors, ['Invalid data'])

      post :submit, params: { form: invalid_data.to_json }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
```

### Testing Custom Schemas

```ruby
RSpec.describe 'My validation logic' do
  let(:schema) do
    {
      type: 'object',
      required: %w[field1],
      properties: {
        field1: { type: 'string' }
      }
    }
  end

  it 'validates data against schema' do
    validator = SchemaValidator.new({ 'field1' => 'value' }, schema: schema)
    expect(validator.valid?).to be true
  end

  it 'rejects invalid data' do
    validator = SchemaValidator.new({}, schema: schema)
    expect(validator.valid?).to be false
    expect(validator.errors).to include(a_string_matching(/field1/))
  end
end
```

## Examples

### Example 1: PDF Download with Validation

```ruby
class V0::Form214192Controller < ApplicationController
  def download_pdf
    parsed_form = parse_and_validate_form_data
    generate_pdf(parsed_form)
  end

  private

  def parse_and_validate_form_data
    parsed_form = JSON.parse(params[:form])

    SchemaValidator.new(
      parsed_form,
      swagger_path: '/v0/form214192',
      swagger_method: :post
    ).validate!

    parsed_form
  rescue JSON::ParserError => e
    raise Common::Exceptions::BadRequest.new(detail: 'Invalid JSON')
  end
end
```

### Example 2: Background Job with Validation

```ruby
class ProcessFormJob < ApplicationJob
  def perform(form_data, form_type)
    validator = SchemaValidator.new(
      form_data,
      swagger_path: "/v0/#{form_type}",
      swagger_method: :post
    )

    unless validator.valid?
      Rails.logger.error("Invalid form data: #{validator.errors.join(', ')}")
      return false
    end

    # Process the valid form data
    process_form(form_data)
  end
end
```

### Example 3: Service Object with Custom Schema

```ruby
class MyService
  SCHEMA = {
    type: 'object',
    required: %w[user_id action],
    properties: {
      user_id: { type: 'string' },
      action: { type: 'string', enum: %w[create update delete] },
      metadata: { type: 'object' }
    }
  }.freeze

  def initialize(data)
    @data = data
    validate_input!
  end

  def perform
    # Your service logic here
  end

  private

  def validate_input!
    SchemaValidator.new(@data, schema: SCHEMA).validate!
  end
end
```

## Best Practices

### 1. Use Swagger Schemas for API Endpoints

For API endpoints, always prefer Swagger schema validation over custom schemas:

```ruby
# Good: Uses your existing Swagger documentation
SchemaValidator.new(data, swagger_path: '/v0/form', swagger_method: :post).validate!

# Avoid: Duplicates schema definition
SchemaValidator.new(data, schema: { ... custom schema ... }).validate!
```

### 2. Handle Errors Appropriately

```ruby
def create
  validator = SchemaValidator.new(params[:form], swagger_path: '/v0/form', swagger_method: :post)
  
  unless validator.valid?
    Rails.logger.error("Validation failed: #{validator.errors}")
    StatsD.increment('api.validation.failures')
    # Let Rails exception handling deal with it
  end
  
  validator.validate! # Raises appropriate exception
end
```

### 3. Keep Swagger Documentation Updated

The validator is only as good as your Swagger docs. Always ensure:

- Swagger schemas accurately reflect your API requirements
- Required fields are properly marked
- Data types and formats are correct
- Schemas are tested

### 4. Use Caching in Production

The validator automatically caches Swagger schemas, but you can pre-warm the cache:

```ruby
# In an initializer or Rails.application.config.after_initialize block
if Rails.env.production?
  SchemaValidator.cached_swagger_schema('/v0/form214192', :post)
  SchemaValidator.cached_swagger_schema('/v0/other_form', :post)
end
```

### 5. Clear Cache in Tests

Always clear the cache in your test setup:

```ruby
RSpec.configure do |config|
  config.before do
    SchemaValidator.clear_cache!
  end
end
```

### 6. Log Validation Failures

The validator automatically logs errors, but add context for better debugging:

```ruby
begin
  SchemaValidator.new(data, swagger_path: path, swagger_method: method).validate!
rescue Common::Exceptions::SchemaValidationErrors => e
  Rails.logger.error("User #{user.id} submitted invalid form", errors: e.message)
  raise
end
```

## Schema Format

The validator uses [JSONSchemer](https://github.com/davishmcclurg/json_schemer) which supports JSON Schema Draft 7. Common patterns:

```ruby
{
  type: 'object',                    # Object type
  required: %w[field1 field2],       # Required fields
  properties: {
    field1: { 
      type: 'string',                # String type
      minLength: 1,                  # Minimum length
      maxLength: 100                 # Maximum length
    },
    field2: {
      type: 'integer',               # Integer type
      minimum: 0,                    # Minimum value
      maximum: 100                   # Maximum value
    },
    field3: {
      type: 'string',
      format: 'email'                # Format validation
    },
    field4: {
      type: 'array',                 # Array type
      items: {
        type: 'string'               # Array item type
      }
    },
    field5: {
      type: 'string',
      enum: %w[option1 option2]      # Enum values
    }
  },
  additionalProperties: false        # Disallow extra fields
}
```

## Troubleshooting

### Schema Not Found

If the validator can't find your Swagger schema:

1. Check that your Swagger path and method are correct
2. Ensure your Swagger documentation includes the schema
3. Verify the parameter index (default is 0)
4. Check logs for extraction errors

### Validation Passing When It Shouldn't

1. Verify your Swagger schema is correct
2. Check that required fields are marked as required
3. Test your schema independently

### Performance Issues

1. Use `cached_swagger_schema` for frequently accessed schemas
2. Pre-warm cache in initializers
3. Check that eager loading is enabled in production

## Support

For questions or issues:

1. Check existing Swagger documentation in `app/swagger/`
2. Review test examples in `spec/services/schema_validator_spec.rb`
3. See controller examples in `spec/controllers/v0/form214192_controller_spec.rb`

## Migration Guide

### Replacing `.permit!`

**Before:**
```ruby
def download_form_params
  params.require(:form).permit!
end
```

**After:**
```ruby
def parse_and_validate_form_data
  parsed_form = params.require(:form).to_h
  
  SchemaValidator.new(
    parsed_form,
    swagger_path: '/v0/my_form',
    swagger_method: :post
  ).validate!
  
  parsed_form
end
```

### Replacing Custom Validation

**Before:**
```ruby
def validate_form_data(data)
  raise 'Missing field' unless data['field1'].present?
  raise 'Invalid type' unless data['field2'].is_a?(Integer)
  # ... many more manual checks
end
```

**After:**
```ruby
def validate_form_data(data)
  SchemaValidator.new(
    data,
    swagger_path: '/v0/endpoint',
    swagger_method: :post
  ).validate!
end
```

The schema validation handles all checks automatically based on your Swagger documentation!

