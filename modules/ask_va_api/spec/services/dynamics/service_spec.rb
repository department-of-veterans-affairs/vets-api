# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dynamics::Service do
  let(:icn) { 'test_icn' }
  let(:base_uri) { 'https://run.mocky.io/v3/' }
  let(:service) { described_class.new(icn:, base_uri:) }

  describe '#call' do
    let(:endpoint) { 'ada58e23-c461-4baf-9c03-ee36ba55c8cf' }

    before do
      allow_any_instance_of(Dynamics::Service).to receive(:token).and_return('token')
    end

    context 'with GET method' do
      it 'makes a successful API call' do
        VCR.use_cassette('ask_va_api/dynamics/service/get_request') do
          expect { service.call(endpoint:, method: :get) }.not_to raise_error
        end
      end
    end

    context 'server response' do
      before do
        stub_request(:get, endpoint)
          .to_return(status: 200, body: response_body)
      end

      context 'with invalid JSON' do
        let(:response_body) { 'invalid JSON' }

        it 'raises a service error' do
          expect(service.call(endpoint:)).to be_an(Array)
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
            icn: '0001740097'
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
          endpoint = 'ada58e23-c461-4baf-9c03-ee36ba55c8cf'
          expect do
            Dynamics::ErrorHandler.handle(endpoint, nil)
          end.to raise_error(Dynamics::ErrorHandler::ServiceError, "Server Error to #{endpoint}: ")
        end
      end

      context 'with specific response status codes' do
        let(:body) { 'Sample error message' }

        {
          400 => 'Bad request',
          401 => 'Unauthorized',
          403 => 'Forbidden: You do not have permission to access',
          404 => 'Resource not found'
        }.each do |status, message|
          it "returns a formatted message for status #{status}" do
            endpoint = 'ada58e23-c461-4baf-9c03-ee36ba55c8cf'
            response = instance_double(Faraday::Response, status:, body:)
            expect do
              Dynamics::ErrorHandler.handle(endpoint, response)
            end.to raise_error(Dynamics::ErrorHandler::ServiceError, "#{message} to #{endpoint}: #{body}")
          end
        end
      end

      context 'with unspecified response status codes' do
        let(:body) { 'General error message' }

        it 'returns a generic error message' do
          endpoint = 'ada58e23-c461-4baf-9c03-ee36ba55c8cf' # Replace with your desired endpoint
          response = instance_double(Faraday::Response, status: 418, body:)
          expect do
            Dynamics::ErrorHandler.handle(endpoint, response)
          end.to raise_error(Dynamics::ErrorHandler::ServiceError, "Service Error to #{endpoint}: #{body}")
        end
      end
    end

    context 'when the server returns an error' do
      before do
        stub_request(:get, endpoint)
          .to_return(status: 500, body: '{"error":"Internal Server Error"}')
      end

      it 'raises a service error' do
        expect(service.call(endpoint:)).to be_an(Array)
      end
    end
  end
end
