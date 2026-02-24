# frozen_string_literal: true

require 'rails_helper'

require 'digital_forms_api/service/request_schema'

require_relative 'shared/service'

RSpec.describe DigitalFormsApi::Service::RequestSchema do
  let(:service) { described_class.new }
  let(:request_schema) { build(:digital_forms_api_request_schema) }
  let(:openapi) do
    path = Rails.root.join(
      'modules',
      'digital_forms_api',
      'config',
      'schemas',
      'forms_api_submissions_request_schema.json'
    )
    JSON.parse(File.read(path))
  end

  it_behaves_like 'a DigitalFormsApi::Service class'

  describe '#fetch' do
    before do
      allow(Rails.cache).to receive(:fetch).and_yield
    end

    it 'retrieves and returns OpenAPI document from /openapi.json' do
      response = instance_double(Faraday::Response, body: openapi)

      expect(Rails.cache).to receive(:fetch)
        .with(described_class::CACHE_KEY, expires_in: described_class::CACHE_TTL)
        .and_yield
      expect(service).to receive(:perform).with(:get, '/openapi.json', {}, {}).and_return(response)

      expect(service.fetch).to eq(openapi)
    end

    it 'falls back to local backup file when openapi retrieval fails' do
      monitor = instance_double(DigitalFormsApi::Monitor::Service)
      allow(DigitalFormsApi::Monitor::Service).to receive(:new).and_return(monitor)
      allow(service).to receive(:perform).with(:get, '/openapi.json', {}, {}).and_raise(StandardError, 'boom')

      expect(monitor).to receive(:track_schema_payload_error).with(
        'submissions_request',
        'Failed to load submissions request schema from openapi.json: StandardError: boom',
        call_location: instance_of(Thread::Backtrace::Location)
      )

      result = service.fetch

      expect(result).to be_a(Hash)
      expect(result).to have_key('paths')
    end

    it 'raises a clear error when request_schema setting is missing' do
      monitor = instance_double(DigitalFormsApi::Monitor::Service)
      allow(DigitalFormsApi::Monitor::Service).to receive(:new).and_return(monitor)
      allow(monitor).to receive(:track_schema_payload_error)

      allow(service).to receive(:perform).with(:get, '/openapi.json', {}, {}).and_raise(StandardError, 'boom')
      allow(Settings).to receive(:digital_forms_api).and_return(OpenStruct.new(request_schema: nil))

      expect { service.fetch }.to raise_error(
        ArgumentError,
        'Settings.digital_forms_api.request_schema must be configured with the backup OpenAPI path'
      )

      expect(monitor).to have_received(:track_schema_payload_error).with(
        'submissions_request',
        'Settings.digital_forms_api.request_schema must be configured with the backup OpenAPI path',
        call_location: instance_of(Thread::Backtrace::Location)
      )
    end
  end

  describe '#fetch_submission_request_schema' do
    before do
      allow(Rails.cache).to receive(:fetch).and_yield
    end

    it 'extracts submissions request schema from OpenAPI document' do
      response = instance_double(Faraday::Response, body: openapi)

      expect(service).to receive(:perform).with(:get, '/openapi.json', {}, {}).and_return(response)

      expect(service.fetch_submission_request_schema).to eq(request_schema)
    end

    it 'resolves requestBody schema references from components' do
      openapi_with_ref = {
        'openapi' => '3.0.3',
        'paths' => {
          '/submissions' => {
            'post' => {
              'requestBody' => {
                '$ref' => '#/components/requestBodies/SubmissionsRequestBody'
              }
            }
          }
        },
        'components' => {
          'requestBodies' => {
            'SubmissionsRequestBody' => {
              'content' => {
                'application/json' => {
                  'schema' => {
                    '$ref' => '#/components/schemas/SubmissionsRequest'
                  }
                }
              }
            }
          },
          'schemas' => {
            'SubmissionsRequest' => request_schema
          }
        }
      }

      response = instance_double(Faraday::Response, body: openapi_with_ref)
      expect(service).to receive(:perform).with(:get, '/openapi.json', {}, {}).and_return(response)

      expect(service.fetch_submission_request_schema).to eq(request_schema)
    end

    it 'prefers the exact /submissions path when multiple submission-like paths exist' do
      alternate_schema = {
        'type' => 'object',
        'properties' => {
          'wrong' => { 'type' => 'boolean' }
        },
        'required' => ['wrong']
      }

      openapi_with_multiple_paths = {
        'openapi' => '3.0.3',
        'paths' => {
          '/v1/submissions' => {
            'post' => {
              'requestBody' => {
                'content' => {
                  'application/json' => {
                    'schema' => alternate_schema
                  }
                }
              }
            }
          },
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

      response = instance_double(Faraday::Response, body: openapi_with_multiple_paths)
      expect(service).to receive(:perform).with(:get, '/openapi.json', {}, {}).and_return(response)

      expect(service.fetch_submission_request_schema).to eq(request_schema)
    end
  end
end
