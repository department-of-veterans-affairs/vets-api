# frozen_string_literal: true

require 'rails_helper'
require 'digital_forms_api/service/base'
require 'digital_forms_api/validation/schema'
RSpec.describe DigitalFormsApi::Validation::Schema do
  let(:schema) do
    {
      'type' => 'object',
      'properties' => {
        'contentName' => { 'type' => 'string' },
        'providerData' => { 'type' => 'object' }
      }
    }
  end

  let(:schema_with_required) do
    {
      'type' => 'object',
      'properties' => {
        'contentName' => { 'type' => 'string' },
        'providerData' => { 'type' => 'object' }
      },
      'required' => %w[contentName providerData]
    }
  end

  let(:response) { instance_double(Faraday::Response, body: schema) }
  let(:service) { instance_double(DigitalFormsApi::Service::Base, perform: response) }

  before do
    allow(DigitalFormsApi::Service::Base).to receive(:new).and_return(service)
  end

  describe '.validate_schema_property' do
    it 'validates a property successfully' do
      expect(subject.validate_schema_property('21-686c', :contentName, 'test.pdf')).to eql 'test.pdf'
    end

    it 'raises an error for invalid property' do
      allow(response).to receive(:body).and_return(schema_with_required)

      expect do
        subject.validate_schema_property('21-686c', :contentName, nil)
      end.to raise_error(JSON::Schema::ValidationError)
    end

    it 'includes form_id when schema is missing' do
      allow(response).to receive(:body).and_return('not-a-schema')

      expect do
        subject.validate_schema_property('21-686c', :contentName, 'test.pdf')
      end.to raise_error(JSON::Schema::ValidationError,
                         /form_id '21-686c' did not include a JSON schema \(expected Hash, got String\)/)
    end
  end

  describe '.validate_upload_payload' do
    it 'validates the upload payload successfully' do
      payload = subject.validate_upload_payload('21-686c', 'test.pdf', { key: 'value' })
      expect(payload).to eq({ contentName: 'test.pdf', providerData: { key: 'value' } })
    end

    it 'raises an error for invalid payload' do
      allow(response).to receive(:body).and_return(schema_with_required)

      expect do
        subject.validate_upload_payload('21-686c', 'test.pdf', nil)
      end.to raise_error(JSON::Schema::ValidationError)
    end
  end

  describe '.validate_provider_data' do
    it 'validates the provider data successfully' do
      provider_data = subject.validate_provider_data('21-686c', { key: 'value' })
      expect(provider_data).to eq({ key: 'value' })
    end

    it 'raises an error for invalid provider data' do
      allow(response).to receive(:body).and_return(schema_with_required)

      expect do
        subject.validate_provider_data('21-686c', nil)
      end.to raise_error(JSON::Schema::ValidationError)
    end
  end

  describe '.fetch_form_schema' do
    it 'returns the schema when it is the top-level body' do
      allow(response).to receive(:body).and_return(schema)

      expect(subject.fetch_form_schema('21-686c')).to eq(schema)
    end

    it 'returns the schema when nested under data.schema' do
      nested_schema = { 'data' => { 'schema' => schema } }
      allow(response).to receive(:body).and_return(nested_schema)

      expect(subject.fetch_form_schema('21-686c')).to eq(schema)
    end

    it 'raises when the response body is not a hash' do
      allow(response).to receive(:body).and_return('not-a-schema')

      expect do
        subject.fetch_form_schema('21-686c')
      end.to raise_error(JSON::Schema::ValidationError,
                         /form_id '21-686c' did not include a JSON schema \(expected Hash, got String\)/)
    end
  end
end
