# frozen_string_literal: true

require 'rails_helper'
require 'digital_forms_api/service/base'
require 'digital_forms_api/validation/schema'
RSpec.describe DigitalFormsApi::Validation::Schema do
  let(:schema) { build(:digital_forms_api_schema) }
  let(:schema_with_required) { build(:digital_forms_api_schema, :with_required) }
  let(:search_schema) { build(:digital_forms_api_schema, :search) }

  let(:response) { instance_double(Faraday::Env, body: schema) }
  let(:service) { instance_double(DigitalFormsApi::Service::Base, perform: response) }

  before do
    Thread.current[:digital_forms_api_schema_monitor] = nil
    allow(DigitalFormsApi::Service::Base).to receive(:new).and_return(service)
  end

  after do
    Thread.current[:digital_forms_api_schema_monitor] = nil
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
      allow(response).to receive(:body)
        .and_return(build(:digital_forms_api_schema_response,
                          nested: true,
                          schema_body: schema))

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

  describe '.validate_search_file_request' do
    it 'validates the search file request successfully' do
      allow(response).to receive(:body).and_return(search_schema)

      payload = subject.validate_search_file_request('21-686c', filters: nil, sort: nil)
      expect(payload).to eq({
                              pageRequest: { resultsPerPage: 10, page: 1 },
                              filters: {},
                              sort: []
                            })
    end

    it 'raises an error for invalid search file request' do
      allow(response).to receive(:body).and_return(search_schema)

      expect do
        subject.validate_search_file_request('21-686c', filters: { foo: 'bar' })
      end.to raise_error(JSON::Schema::ValidationError)
    end
  end

  describe '.validate_against_schema' do
    it 'validates a payload against the schema successfully' do
      expect do
        subject.validate_against_schema(schema_with_required,
                                        { contentName: 'test.pdf', providerData: { key: 'value' } })
      end.not_to raise_error
    end

    it 'raises an error for invalid payload' do
      expect do
        subject.validate_against_schema(schema_with_required, { contentName: 'test.pdf' })
      end.to raise_error(JSON::Schema::ValidationError)
    end

    it 'tracks and raises when the schema cannot be parsed' do
      monitor = instance_double(DigitalFormsApi::Monitor::Service)
      Thread.current[:digital_forms_api_schema_monitor] = monitor

      allow(JSON::Validator).to receive(:validate!).and_raise(JSON::Schema::SchemaParseError.new('parse failed'))

      expect(monitor).to receive(:track_api_request).with(
        :get,
        'schemas',
        500,
        'form_id=21-686c parse failed',
        call_location: instance_of(Thread::Backtrace::Location)
      )

      expect do
        subject.validate_against_schema(schema_with_required, { contentName: 'test.pdf' }, form_id: '21-686c')
      end.to raise_error(JSON::Schema::ValidationError)
    end
  end

  describe '.normalize_integer' do
    it 'returns the integer value when a valid integer string is provided' do
      expect(subject.normalize_integer('5', 10)).to eq(5)
    end

    it 'returns the default value when nil is provided' do
      expect(subject.normalize_integer(nil, 10)).to eq(10)
    end

    it 'returns the default value when an invalid string is provided' do
      expect(subject.normalize_integer('invalid', 10)).to eq(10)
    end
  end

  describe '.track_schema_error' do
    it 'logs the error with form_id context' do
      monitor = instance_double(DigitalFormsApi::Monitor::Service)
      Thread.current[:digital_forms_api_schema_monitor] = monitor

      expect(monitor).to receive(:track_api_request).with(
        :get,
        'schemas',
        500,
        'form_id=21-686c validation failed',
        call_location: instance_of(Thread::Backtrace::Location)
      )

      subject.track_schema_error('21-686c', 'validation failed')
    end

    it 'logs the error with form_id and custom message' do
      monitor = instance_double(DigitalFormsApi::Monitor::Service)
      Thread.current[:digital_forms_api_schema_monitor] = monitor

      expect(monitor).to receive(:track_api_request).with(
        :get,
        'schemas',
        500,
        'form_id=21-686c custom error message',
        call_location: instance_of(Thread::Backtrace::Location)
      )

      subject.track_schema_error('21-686c', 'custom error message')
    end
  end

  describe '.monitor' do
    it 'returns a monitor instance' do
      monitor_instance = instance_double(DigitalFormsApi::Monitor::Service)
      allow(DigitalFormsApi::Monitor::Service).to receive(:new).and_return(monitor_instance)

      expect(subject.monitor).to eq(monitor_instance)
    end

    it 'returns the thread-local monitor when set' do
      monitor_instance = instance_double(DigitalFormsApi::Monitor::Service)
      Thread.current[:digital_forms_api_schema_monitor] = monitor_instance

      expect(subject.monitor).to eq(monitor_instance)
    end

    it 'memoizes the monitor instance' do
      monitor_instance = instance_double(DigitalFormsApi::Monitor::Service)
      allow(DigitalFormsApi::Monitor::Service).to receive(:new).and_return(monitor_instance)

      expect(subject.monitor).to eq(monitor_instance)
      expect(subject.monitor).to eq(monitor_instance)
    end
  end

  describe '.extract_schema_from_response' do
    it 'extracts the schema when it is the top-level body' do
      allow(response).to receive(:body).and_return(schema)

      expect(subject.extract_schema_from_response(response.body)).to eq(schema)
    end

    it 'extracts the schema when nested under data.schema' do
      nested_schema = { 'data' => { 'schema' => schema } }
      allow(response).to receive(:body).and_return(nested_schema)

      expect(subject.extract_schema_from_response(response.body)).to eq(schema)
    end
  end
end
