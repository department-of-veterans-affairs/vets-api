# frozen_string_literal: true

require 'rails_helper'
require 'meb_api/email_error_logger'

RSpec.describe MebApi::EmailErrorLogger do
  let(:form_type) { '1990MEB' }
  let(:form_tag) { 'form:1990meb' }
  let(:claim_status) { 'ELIGIBLE' }
  let(:template_id) { 'test_template_id' }
  let(:user_icn) { '1234567890V123456' }

  describe '#log_params' do
    context 'with a standard error' do
      let(:error) { StandardError.new('Something went wrong') }
      let(:logger) { described_class.new(error:, form_type:, form_tag:) }

      it 'returns basic error parameters' do
        result = logger.log_params(
          claim_status:,
          template_id:,
          email_present: true,
          user_icn:
        )

        expect(result).to include(
          form_type:,
          claim_status:,
          template_id:,
          email_present: true,
          error_class: 'StandardError',
          error_message: 'Something went wrong',
          icn: user_icn
        )
        expect(result).not_to have_key(:http_status)
        expect(result).not_to have_key(:response_body)
      end
    end

    context 'with an error that has a blank message' do
      let(:error) { StandardError.new('') }
      let(:logger) { described_class.new(error:, form_type:, form_tag:) }

      it 'uses default error message' do
        result = logger.log_params(
          claim_status:,
          template_id:,
          email_present: false,
          user_icn:
        )

        expect(result[:error_message]).to eq('No error message provided')
      end
    end

    context 'with a Common::Client::Errors::ClientError' do
      let(:error) do
        error = Common::Client::Errors::ClientError.new
        allow(error).to receive_messages(status: 503, body: { error: 'Service unavailable' })
        error
      end
      let(:logger) { described_class.new(error:, form_type:, form_tag:) }

      it 'includes HTTP status and response body' do
        result = logger.log_params(
          claim_status:,
          template_id:,
          email_present: true,
          user_icn:
        )

        expect(result[:http_status]).to eq(503)
        expect(result[:response_body]).to include('Service unavailable')
      end
    end

    context 'with an error that has a very long response body' do
      let(:long_body) { 'x' * 300 }
      let(:error) do
        error = Common::Client::Errors::ClientError.new
        allow(error).to receive_messages(status: 500, body: long_body)
        error
      end
      let(:logger) { described_class.new(error:, form_type:, form_tag:) }

      it 'truncates response body to 250 characters' do
        result = logger.log_params(
          claim_status:,
          template_id:,
          email_present: true,
          user_icn:
        )

        expect(result[:response_body].length).to eq(250)
        expect(result[:response_body]).to end_with('...')
      end
    end

    context 'with email_present false' do
      let(:error) { StandardError.new('Test error') }
      let(:logger) { described_class.new(error:, form_type:, form_tag:) }

      it 'correctly includes email_present: false' do
        result = logger.log_params(
          claim_status:,
          template_id:,
          email_present: false,
          user_icn:
        )

        expect(result[:email_present]).to be false
      end
    end
  end
end
