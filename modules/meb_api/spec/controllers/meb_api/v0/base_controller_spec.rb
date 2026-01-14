# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MebApi::V0::BaseController, type: :controller do
  let(:user) { build(:user, :loa3) }
  let(:mock_request) { instance_double(ActionDispatch::Request, request_id: 'test-request-id-123') }
  let(:test_controller) do
    Class.new(described_class) do
      def test_log_error(error, message)
        log_submission_error(error, message)
      end
    end.new
  end

  before do
    allow(test_controller).to receive(:request).and_return(mock_request)
    test_controller.instance_variable_set(:@current_user, user)
  end

  describe '#log_submission_error' do
    context 'with a StandardError' do
      let(:error) { StandardError.new('Something went wrong') }

      it 'logs error with ICN, error class, error message, and request_id' do
        expect(Rails.logger).to receive(:error).with(
          'Test error message',
          {
            icn: user.icn,
            error_class: 'StandardError',
            error_message: 'Something went wrong',
            request_id: 'test-request-id-123'
          }
        )
        expect(StatsD).to receive(:increment).with(
          'api.meb.submit_claim.error',
          tags: ['error_class:StandardError']
        )

        test_controller.test_log_error(error, 'Test error message')
      end

      it 'does not include status or response_body for non-ClientError' do
        expect(Rails.logger).to receive(:error).with(
          'Test error message',
          hash_excluding(:status, :response_body)
        )
        allow(StatsD).to receive(:increment)

        test_controller.test_log_error(error, 'Test error message')
      end

      it 'increments error metric with error class tag' do
        allow(Rails.logger).to receive(:error)
        expect(StatsD).to receive(:increment).with(
          'api.meb.submit_claim.error',
          tags: ['error_class:StandardError']
        )

        test_controller.test_log_error(error, 'Test error message')
      end
    end

    context 'with a Common::Client::Errors::ClientError' do
      let(:error_body) { { error: 'Downstream service error' }.to_json }
      let(:client_error) { Common::Client::Errors::ClientError.new('DGI failed', 500, error_body) }

      it 'logs error with HTTP status and response body' do
        expect(Rails.logger).to receive(:error).with(
          'Test error message',
          {
            icn: user.icn,
            error_class: 'Common::Client::Errors::ClientError',
            error_message: 'DGI failed',
            request_id: 'test-request-id-123',
            status: 500,
            response_body: error_body
          }
        )
        allow(StatsD).to receive(:increment)

        test_controller.test_log_error(client_error, 'Test error message')
      end

      it 'increments error metric with ClientError class tag' do
        allow(Rails.logger).to receive(:error)
        expect(StatsD).to receive(:increment).with(
          'api.meb.submit_claim.error',
          tags: ['error_class:Common::Client::Errors::ClientError']
        )

        test_controller.test_log_error(client_error, 'Test error message')
      end

      context 'when response body is nil' do
        let(:client_error_no_body) { Common::Client::Errors::ClientError.new('DGI failed', 500, nil) }

        it 'does not include response_body in log params' do
          expect(Rails.logger).to receive(:error).with(
            'Test error message',
            {
              icn: user.icn,
              error_class: 'Common::Client::Errors::ClientError',
              error_message: 'DGI failed',
              request_id: 'test-request-id-123',
              status: 500
            }
          )
          allow(StatsD).to receive(:increment)

          test_controller.test_log_error(client_error_no_body, 'Test error message')
        end
      end

      context 'when response body exceeds 250 characters' do
        let(:long_body) { 'x' * 300 }
        let(:client_error_long) { Common::Client::Errors::ClientError.new('DGI failed', 500, long_body) }

        it 'truncates response body to 250 characters' do
          expect(Rails.logger).to receive(:error).with(
            'Test error message',
            hash_including(
              response_body: have_attributes(length: 250)
            )
          )
          allow(StatsD).to receive(:increment)

          test_controller.test_log_error(client_error_long, 'Test error message')
        end
      end
    end

    context 'when error message is blank' do
      let(:error_blank_message) { StandardError.new('') }

      it 'uses fallback message' do
        expect(Rails.logger).to receive(:error).with(
          'Test error message',
          hash_including(error_message: 'No error message provided')
        )
        allow(StatsD).to receive(:increment)

        test_controller.test_log_error(error_blank_message, 'Test error message')
      end
    end
  end
end
