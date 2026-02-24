# frozen_string_literal: true

require 'rails_helper'

require 'digital_forms_api/service/request_schema'

require_relative 'shared/service'

RSpec.describe DigitalFormsApi::Service::RequestSchema do
  let(:service) { described_class.new }
  let(:request_schema) { build(:digital_forms_api_request_schema) }

  it_behaves_like 'a DigitalFormsApi::Service class'

  describe '#fetch' do
    before do
      allow(Rails.cache).to receive(:fetch).and_yield
    end

    it 'retrieves and returns submissions request schema from openapi.json' do
      openapi = {
        'paths' => {
          '/submissions' => {
            'post' => {
              'requestBody' => {
                'content' => {
                  'application/json' => {
                    'schema' => request_schema
                  }
                }
              }
            }
          }
        }
      }
      response = instance_double(Faraday::Response, body: openapi)

      expect(Rails.cache).to receive(:fetch)
        .with(described_class::CACHE_KEY, expires_in: described_class::CACHE_TTL)
        .and_yield
      expect(service).to receive(:perform).with(:get, 'openapi.json', {}, {}).and_return(response)

      expect(service.fetch).to eq(request_schema)
    end

    it 'accepts a direct schema payload from openapi endpoint' do
      response = instance_double(Faraday::Response, body: request_schema)

      expect(service).to receive(:perform).with(:get, 'openapi.json', {}, {}).and_return(response)

      expect(service.fetch).to eq(request_schema)
    end

    it 'falls back to local backup file when openapi retrieval fails' do
      monitor = instance_double(DigitalFormsApi::Monitor::Service)
      allow(DigitalFormsApi::Monitor::Service).to receive(:new).and_return(monitor)
      allow(service).to receive(:perform).with(:get, 'openapi.json', {}, {}).and_raise(StandardError, 'boom')

      expect(monitor).to receive(:track_schema_payload_error).with(
        'submissions_request',
        'Failed to load submissions request schema from openapi.json: StandardError: boom',
        call_location: instance_of(Thread::Backtrace::Location)
      )

      result = service.fetch

      expect(result).to be_a(Hash)
      expect(result['required']).to include('envelope')
    end
  end
end
