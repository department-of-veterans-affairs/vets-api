# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SchemaValidator do
  let(:valid_data) do
    {
      'name' => 'John Doe',
      'email' => 'john@example.com',
      'age' => 30
    }
  end

  let(:invalid_data) do
    {
      'name' => 'John Doe',
      'email' => 'invalid-email'
      # missing required 'age' field
    }
  end

  let(:simple_schema) do
    {
      type: 'object',
      required: %w[name email age],
      properties: {
        name: { type: 'string' },
        email: { type: 'string', format: 'email' },
        age: { type: 'integer', minimum: 0 }
      }
    }
  end

  before do
    # Clear cache before each test
    described_class.clear_cache!
  end

  describe '#initialize' do
    it 'initializes with data and direct schema' do
      validator = described_class.new(valid_data, schema: simple_schema)
      expect(validator.data).to eq(valid_data)
      expect(validator.errors).to be_empty
    end

    it 'initializes with data and Swagger path/method' do
      validator = described_class.new(
        valid_data,
        swagger_path: '/v0/example',
        swagger_method: :post
      )
      expect(validator.data).to eq(valid_data)
      expect(validator.errors).to be_empty
    end

    it 'accepts swagger_param_index parameter' do
      validator = described_class.new(
        valid_data,
        swagger_path: '/v0/example',
        swagger_method: :post,
        swagger_param_index: 1
      )
      expect(validator.data).to eq(valid_data)
    end
  end

  describe '#valid?' do
    context 'with direct schema' do
      it 'returns true for valid data' do
        validator = described_class.new(valid_data, schema: simple_schema)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'returns false for invalid data' do
        validator = described_class.new(invalid_data, schema: simple_schema)
        expect(validator.valid?).to be false
        expect(validator.errors).not_to be_empty
      end

      it 'populates errors for missing required fields' do
        validator = described_class.new(invalid_data, schema: simple_schema)
        validator.valid?

        expect(validator.errors).to include(a_string_matching(/age/))
      end

      it 'populates errors for format violations' do
        data = valid_data.dup
        data['email'] = 'not-an-email'

        validator = described_class.new(data, schema: simple_schema)
        validator.valid?

        expect(validator.errors).to include(a_string_matching(/email/))
      end

      it 'populates errors for type mismatches' do
        data = valid_data.dup
        data['age'] = 'not a number'

        validator = described_class.new(data, schema: simple_schema)
        validator.valid?

        expect(validator.errors).to include(a_string_matching(/age/))
      end
    end

    context 'with Swagger schema extraction' do
      let(:mock_swagger_schema) do
        {
          type: 'object',
          required: %w[veteranInformation],
          properties: {
            veteranInformation: {
              type: 'object',
              properties: {
                fullName: { type: 'object' }
              }
            }
          }
        }
      end

      before do
        allow(described_class).to receive(:extract_swagger_schema)
          .with('/v0/form214192', :post, 0)
          .and_return(mock_swagger_schema)
      end

      it 'extracts and uses Swagger schema for validation' do
        data = { 'veteranInformation' => { 'fullName' => { 'first' => 'John' } } }
        validator = described_class.new(
          data,
          swagger_path: '/v0/form214192',
          swagger_method: :post
        )

        expect(validator.valid?).to be true
      end

      it 'returns false when data does not match Swagger schema' do
        data = { 'invalidKey' => 'value' }
        validator = described_class.new(
          data,
          swagger_path: '/v0/form214192',
          swagger_method: :post
        )

        expect(validator.valid?).to be false
        expect(validator.errors).not_to be_empty
      end
    end

    context 'with no schema provided' do
      it 'logs warning and returns true' do
        expect(Rails.logger).to receive(:warn)
          .with(a_string_matching(/No schema or Swagger path provided/))

        validator = described_class.new(valid_data)
        expect(validator.valid?).to be true
      end
    end
  end

  describe '#validate!' do
    context 'with valid data' do
      it 'returns true without raising an error' do
        validator = described_class.new(valid_data, schema: simple_schema)
        expect(validator.validate!).to be true
      end
    end

    context 'with invalid data' do
      it 'raises Common::Exceptions::SchemaValidationErrors' do
        validator = described_class.new(invalid_data, schema: simple_schema)

        expect do
          validator.validate!
        end.to raise_error(Common::Exceptions::SchemaValidationErrors)
      end

      it 'logs validation errors' do
        validator = described_class.new(invalid_data, schema: simple_schema)

        expect(Rails.logger).to receive(:error)
          .with(a_string_matching(/Schema validation errors/))

        expect { validator.validate! }.to raise_error(Common::Exceptions::SchemaValidationErrors)
      end

      it 'includes error details in the exception' do
        validator = described_class.new(invalid_data, schema: simple_schema)

        begin
          validator.validate!
        rescue Common::Exceptions::SchemaValidationErrors => e
          expect(e.message).to be_a(Array)
          expect(e.message).not_to be_empty
        end
      end
    end
  end

  describe '.extract_swagger_schema' do
    before do
      allow(Rails.application).to receive(:eager_load!)
      allow(Rails.application.config).to receive(:eager_load).and_return(false)
    end

    it 'extracts schema from Swagger::Blocks' do
      # This will use the actual Swagger definitions if they exist
      schema = described_class.extract_swagger_schema('/v0/form214192', :post, 0)

      # If the endpoint exists in Swagger, it should return a schema
      # Otherwise it should return nil
      expect(schema).to be_a(Hash).or be_nil
    end

    it 'returns nil when path does not exist' do
      schema = described_class.extract_swagger_schema('/v0/nonexistent', :post, 0)
      expect(schema).to be_nil
    end

    it 'logs error when extraction fails' do
      allow(ObjectSpace).to receive(:each_object).and_raise(StandardError, 'Test error')

      expect(Rails.logger).to receive(:error)
        .with(a_string_matching(/Failed to extract Swagger schema/))

      schema = described_class.extract_swagger_schema('/v0/test', :post, 0)
      expect(schema).to be_nil
    end

    it 'eager loads application if not already loaded' do
      allow(Rails.application.config).to receive(:eager_load).and_return(false)

      expect(Rails.application).to receive(:eager_load!)

      described_class.extract_swagger_schema('/v0/test', :post, 0)
    end

    it 'does not eager load if already loaded' do
      allow(Rails.application.config).to receive(:eager_load).and_return(true)

      expect(Rails.application).not_to receive(:eager_load!)

      described_class.extract_swagger_schema('/v0/test', :post, 0)
    end
  end

  describe '.cached_swagger_schema' do
    let(:mock_schema) { { type: 'object' } }

    before do
      allow(described_class).to receive(:extract_swagger_schema)
        .with('/v0/test', :post, 0)
        .and_return(mock_schema)
    end

    it 'caches extracted schemas' do
      # First call should extract
      schema1 = described_class.cached_swagger_schema('/v0/test', :post, 0)
      expect(schema1).to eq(mock_schema)

      # Second call should use cache
      expect(described_class).to receive(:extract_swagger_schema).exactly(0).times
      schema2 = described_class.cached_swagger_schema('/v0/test', :post, 0)
      expect(schema2).to eq(mock_schema)
    end

    it 'uses different cache keys for different parameters' do
      allow(described_class).to receive(:extract_swagger_schema)
        .with('/v0/test', :get, 0)
        .and_return({ type: 'string' })

      schema_post = described_class.cached_swagger_schema('/v0/test', :post, 0)
      schema_get = described_class.cached_swagger_schema('/v0/test', :get, 0)

      expect(schema_post).not_to eq(schema_get)
    end

    it 'caches nil results' do
      allow(described_class).to receive(:extract_swagger_schema)
        .with('/v0/nonexistent', :post, 0)
        .and_return(nil)

      # First call
      described_class.cached_swagger_schema('/v0/nonexistent', :post, 0)

      # Should not call extract again
      expect(described_class).to receive(:extract_swagger_schema).exactly(0).times
      described_class.cached_swagger_schema('/v0/nonexistent', :post, 0)
    end
  end

  describe '.clear_cache!' do
    it 'clears the schema cache' do
      mock_schema = { type: 'object' }
      allow(described_class).to receive(:extract_swagger_schema).and_return(mock_schema)

      # Populate cache
      described_class.cached_swagger_schema('/v0/test', :post, 0)

      # Clear cache
      described_class.clear_cache!

      # Should extract again after clearing
      expect(described_class).to receive(:extract_swagger_schema).and_return(mock_schema)
      described_class.cached_swagger_schema('/v0/test', :post, 0)
    end
  end

  describe 'error formatting' do
    let(:schema_with_nested_fields) do
      {
        type: 'object',
        required: %w[user],
        properties: {
          user: {
            type: 'object',
            required: %w[profile],
            properties: {
              profile: {
                type: 'object',
                required: %w[name],
                properties: {
                  name: { type: 'string' }
                }
              }
            }
          }
        }
      }
    end

    it 'formats errors with data pointers' do
      data = { 'user' => { 'profile' => {} } }
      validator = described_class.new(data, schema: schema_with_nested_fields)
      validator.valid?

      expect(validator.errors.first).to include('/user/profile')
    end

    it 'includes error descriptions' do
      data = { 'user' => { 'profile' => {} } }
      validator = described_class.new(data, schema: schema_with_nested_fields)
      validator.valid?

      expect(validator.errors.first).to match(/name/)
    end
  end

  describe 'integration with JSONSchemer' do
    it 'validates complex nested structures' do
      complex_schema = {
        type: 'object',
        properties: {
          items: {
            type: 'array',
            items: {
              type: 'object',
              required: %w[id name],
              properties: {
                id: { type: 'integer' },
                name: { type: 'string' }
              }
            }
          }
        }
      }

      valid_complex_data = {
        'items' => [
          { 'id' => 1, 'name' => 'Item 1' },
          { 'id' => 2, 'name' => 'Item 2' }
        ]
      }

      invalid_complex_data = {
        'items' => [
          { 'id' => 1, 'name' => 'Item 1' },
          { 'id' => 'not-a-number', 'name' => 'Item 2' }
        ]
      }

      valid_validator = described_class.new(valid_complex_data, schema: complex_schema)
      expect(valid_validator.valid?).to be true

      invalid_validator = described_class.new(invalid_complex_data, schema: complex_schema)
      expect(invalid_validator.valid?).to be false
      expect(invalid_validator.errors).to include(a_string_matching(/items.*1.*id/))
    end
  end
end

