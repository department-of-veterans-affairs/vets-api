# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dynamics::Service do
  let(:base_uri) { 'https://run.mocky.io/v3/' }
  let(:sec_id) { 'test_sec_id' }
  let(:service) { described_class.new(base_uri:, sec_id:) }

  describe '#initialize' do
    it 'requires base_uri' do
      expect { described_class.new(sec_id:) }.to raise_error(ArgumentError)
    end

    it 'requires sec_id' do
      expect { described_class.new(base_uri:) }.to raise_error(ArgumentError)
    end
  end

  describe '#call' do
    let(:endpoint) { 'ada58e23-c461-4baf-9c03-ee36ba55c8cf' }

    Dynamics::Service::SUPPORTED_METHODS.each do |method|
      context "with #{method.upcase} method" do
        it 'makes a successful API call' do
          VCR.use_cassette("ask_va_api/dynamics/service/#{method}_request") do
            expect { service.call(endpoint:, method:) }.not_to raise_error
          end
        end
      end
    end

    it 'raises an ArgumentError for unsupported HTTP methods' do
      expect { service.call(endpoint:, method: :unsupported) }
        .to raise_error(ArgumentError, 'Unsupported HTTP method: unsupported')
    end

    context 'server response' do
      before do
        stub_request(:get, "#{base_uri}#{endpoint}")
          .to_return(status: 200, body: response_body)
      end

      context 'with invalid JSON' do
        let(:response_body) { 'invalid JSON' }

        it 'raises a service error' do
          expect { service.call(endpoint:) }
            .to raise_error(Dynamics::ErrorHandler::ServiceError,
                            'No response received from ada58e23-c461-4baf-9c03-ee36ba55c8cf')
        end
      end

      context 'when JSON parsing fails' do
        let(:response_body) { nil }

        before do
          allow(JSON).to receive(:parse).and_raise(JSON::ParserError.new('Unexpected token'))
        end

        it 'logs an error and raises a ServiceError' do
          expect(service).to receive(:log_error).with(endpoint, 'JSON::ParserError')
          VCR.use_cassette('ask_va_api/dynamics/service/get_request') do
            expect do
              service.call(endpoint:)
            end.to raise_error(
              Dynamics::ErrorHandler::ServiceError,
              "Error parsing response from #{endpoint}: Unexpected token"
            )
          end
        end
      end

      context 'with valid JSON' do
        let(:response_body) do
          [{
            respond_reply_id: 'Original Question',
            inquiryNumber: 'A-1',
            inquiryTopic: 'Topic',
            inquiryProcessingStatus: 'Close',
            lastUpdate: '08/07/23',
            submitterQuestions: 'When is Sergeant Joe Smith birthday?',
            attachments: [
              {
                activity: 'activity_1',
                date_sent: '08/7/23'
              }
            ],
            sec_id: '0001740097'
          }]
        end

        it 'returns a parsed response' do
          VCR.use_cassette('ask_va_api/dynamics/service/get_request') do
            expect(service.call(endpoint:)[:data].first).to eq(response_body.first)
          end
        end
      end
    end

    describe 'error message formatting' do
      context 'when response is nil' do
        it 'returns a message indicating no response was received' do
          expect(Dynamics::ErrorHandler.formatted_error_message(endpoint, nil))
            .to eq("No response received from #{endpoint}")
        end
      end

      context 'with specific response status codes' do
        let(:body) { 'Sample error message' }

        {
          400 => 'Bad request to',
          401 => 'Unauthorized request to',
          403 => 'Forbidden: You do not have permission to access',
          404 => 'Resource not found at'
        }.each do |status, message|
          it "returns a formatted message for status #{status}" do
            response = instance_double(Faraday::Response, status:, body:)
            expect(Dynamics::ErrorHandler.formatted_error_message(endpoint, response))
              .to eq("#{message} #{endpoint}: #{body}")
          end
        end
      end

      context 'with unspecified response status codes' do
        let(:body) { 'General error message' }

        it 'returns a generic error message' do
          response = instance_double(Faraday::Response, status: 418, body:)
          expect(Dynamics::ErrorHandler.formatted_error_message(endpoint, response))
            .to eq("Error on request to #{endpoint}: #{body}")
        end
      end
    end

    context 'when making a mock call' do
      let(:endpoint) { 'get_inquiries_mock_data' }
      let(:service) { described_class.new(base_uri:, sec_id:, mock: true) }
      let(:mock_response) do
        {
          respond_reply_id: 'Original Question',
          inquiryNumber: 'A-1',
          inquiryTopic: 'Topic',
          inquiryProcessingStatus: 'Close',
          lastUpdate: '08/07/23',
          submitterQuestions: 'When is Sergeant Joe Smith birthday?',
          attachments: [{
            activity: 'activity_1', date_sent: '08/7/23'
          }],
          sec_id: '0001740097'
        }
      end

      it 'returns mock data' do
        expect(service.call(endpoint:, criteria: { inquiry_number: 'A-1' })).to eq(mock_response)
      end
    end

    context 'when the server returns an error' do
      before do
        stub_request(:get, "#{base_uri}#{endpoint}")
          .to_return(status: 500, body: '{"error":"Internal Server Error"}')
      end

      it 'raises a service error' do
        expect { service.call(endpoint:) }
          .to raise_error(Dynamics::ErrorHandler::ServiceError,
                          'No response received from ada58e23-c461-4baf-9c03-ee36ba55c8cf')
      end
    end
  end
end
