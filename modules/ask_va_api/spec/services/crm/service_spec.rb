# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crm::Service do
  let(:service) { described_class.new(icn: '123') }

  # Helper method to create a mock response
  def mock_response(status:, body:)
    instance_double(Faraday::Response, status:, body: body.to_json)
  end

  # Shared examples for error handling
  shared_examples 'error handling' do |status, message|
    let(:body) { 'Sample error message' }

    it "returns a formatted message for status #{status}" do
      response = mock_response(status:, body:)
      expected_error_message = "#{message} to #{endpoint}: \"#{body}\""

      expect do
        Crm::ErrorHandler.handle(endpoint, response)
      end.to raise_error(Crm::ErrorHandler::ServiceError, expected_error_message)
    end
  end

  describe '#call' do
    let(:endpoint) { 'inquiries' }

    context 'server response' do
      context 'with valid JSON' do
        let(:response) do
          mock_response(
            status: 200,
            body: {
              data: [
                {
                  respond_reply_id: 'Original Question',
                  inquiryNumber: 'A-1',
                  inquiryTopic: 'Topic',
                  inquiryProcessingStatus: 'Close',
                  lastUpdate: '08/07/23',
                  submitterQuestions: 'When is Sergeant Joe Smith birthday?',
                  attachments: [{ activity: 'activity_1', date_sent: '08/7/23' }],
                  icn: '0001740097'
                }
              ]
            }
          )
        end

        before do
          allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
          allow_any_instance_of(Faraday::Connection).to receive(:get).with('eis/vagov.lob.ava/api/inquiries',
                                                                           icn: '123',
                                                                           organizationName: 'iris-dev')
                                                                     .and_return(response)
        end

        it 'returns a parsed response' do
          res = JSON.parse(response.body, symbolize_names: true)
          expect(service.call(endpoint:)[:data].first).to eq(res[:data].first)
        end
      end
    end

    describe 'error message formatting' do
      context 'when response is nil' do
        it 'returns a message indicating no response was received' do
          expect do
            Crm::ErrorHandler.handle(endpoint,
                                     nil)
          end.to raise_error(Crm::ErrorHandler::ServiceError, "Server Error to #{endpoint}: ")
        end
      end

      context 'with specific response status codes' do
        include_examples 'error handling', 400, 'Bad request'
        include_examples 'error handling', 401, 'Unauthorized'
        include_examples 'error handling', 403, 'Forbidden: You do not have permission to access'
        include_examples 'error handling', 404, 'Resource not found'
      end

      context 'with unspecified response status codes' do
        let(:body) { 'General error message' }

        it 'returns a generic error message' do
          response = mock_response(status: 418, body:)
          expect do
            Crm::ErrorHandler.handle(endpoint, response)
          end.to raise_error(Crm::ErrorHandler::ServiceError, "Service Error to #{endpoint}: \"#{body}\"")
        end
      end
    end

    context 'when the server returns an error' do
      let(:resp) { mock_response(body: { error: 'server error' }, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
        allow_any_instance_of(Faraday::Connection).to receive(:get).with('eis/vagov.lob.ava/api/inquiries',
                                                                         { icn: '123',
                                                                           organizationName: 'iris-dev' })
                                                                   .and_raise(exception)
      end

      it 'raises a service error' do
        response = service.call(endpoint:)
        expect(response.status).to eq(resp.status)
      end
    end
  end
end
