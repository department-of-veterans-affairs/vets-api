# frozen_string_literal: true

require 'rails_helper'

require 'digital_forms_api/service/schema'

require_relative 'shared/service'

RSpec.describe DigitalFormsApi::Service::Schema do
  let(:service) { described_class.new }

  it_behaves_like 'a DigitalFormsApi::Service class'

  describe '#fetch' do
    let(:form_id) { '21-686c' }

    before do
      allow(Rails.cache).to receive(:fetch).and_yield
    end

    it 'retrieves and returns the schema when it is the top-level body' do
      response = instance_double(Faraday::Response, body: build(:digital_forms_api_schema))
      expect(Rails.cache).to receive(:fetch)
        .with("digital_forms_api:schema:#{form_id}", expires_in: described_class::CACHE_TTL)
        .and_yield
      expect(service).to receive(:perform).with(:get, "schemas/#{form_id}", {}, {}).and_return(response)

      expect(service.fetch(form_id)).to eq(response.body)
    end

    it 'extracts schema when nested under data.schema' do
      schema = build(:digital_forms_api_schema)
      body = build(:digital_forms_api_schema_response, nested: true, schema_body: schema)
      response = instance_double(Faraday::Response, body:)

      expect(service).to receive(:perform).with(:get, "schemas/#{form_id}", {}, {}).and_return(response)

      expect(service.fetch(form_id)).to eq(schema)
    end

    it 'extracts schema when wrapped under schema key' do
      schema = build(:digital_forms_api_schema)
      response = instance_double(Faraday::Response, body: { 'schema' => schema })

      expect(service).to receive(:perform).with(:get, "schemas/#{form_id}", {}, {}).and_return(response)

      expect(service.fetch(form_id)).to eq(schema)
    end

    it 'tracks and raises an error when schema payload is invalid' do
      monitor = instance_double(DigitalFormsApi::Monitor::Service)
      allow(DigitalFormsApi::Monitor::Service).to receive(:new).and_return(monitor)

      response = instance_double(Faraday::Response, body: 'not-a-schema')
      expect(service).to receive(:perform).with(:get, "schemas/#{form_id}", {}, {}).and_return(response)
      expect(monitor).to receive(:track_schema_payload_error).with(
        form_id,
        "Schema response for form_id '#{form_id}' did not include a JSON schema (expected Hash, got String)",
        call_location: instance_of(Thread::Backtrace::Location)
      )

      expect { service.fetch(form_id) }.to raise_error(ArgumentError)
    end
  end
end
