# frozen_string_literal: true

require 'rails_helper'
require 'map/security_token/service'

describe MAP::SecurityToken::Service do
  describe '#token' do
    subject { described_class.new.token(application:, icn:) }

    let(:application) { :some_application }
    let(:icn) { 'some-icn' }
    let(:log_prefix) { '[MAP][SecurityToken][Service]' }

    shared_examples 'STS token request' do
      context 'when response is not successful with a 401 error' do
        let(:context) { { error: expected_error_message } }
        let(:expected_error_message) { 'invalid_client' }
        let(:expected_error_status) { 401 }
        let(:expected_message) do
          "#{log_prefix} token failed, client error, status: #{expected_error_status}, application: #{application}, " \
            "icn: #{icn}, context: #{context}"
        end
        let(:expected_error) { Common::Client::Errors::ClientError }

        it 'raises a client error with expected message' do
          VCR.use_cassette('map/security_token_service_401_response') do
            expect { subject }.to raise_error(expected_error, expected_message)
          end
        end
      end

      context 'and response is successful' do
        let(:expected_log_message) { "#{log_prefix} token success, application: #{application}, icn: #{icn}" }

        it 'logs a token success message',
           vcr: { cassette_name: 'map/security_token_service_200_response' } do
          expect(Rails.logger).to receive(:info).with(expected_log_message)
          subject
        end

        it 'returns an access token field',
           vcr: { cassette_name: 'map/security_token_service_200_response' } do
          expect(subject[:access_token]).not_to be_nil
        end

        it 'returns an expiration field',
           vcr: { cassette_name: 'map/security_token_service_200_response' } do
          expect(subject[:expiration]).not_to be_nil
        end
      end
    end

    context 'when input application is chatbot' do
      let(:application) { :chatbot }

      it_behaves_like 'STS token request'
    end

    context 'when input application is sign up service' do
      let(:application) { :sign_up_service }

      it_behaves_like 'STS token request'
    end

    context 'when input application is check in' do
      let(:application) { :check_in }

      it_behaves_like 'STS token request'
    end

    context 'when input application is arbitrary' do
      let(:application) { :some_application }
      let(:expected_error) { MAP::SecurityToken::Errors::ApplicationMismatchError }
      let(:expected_error_message) { "#{log_prefix} application mismatch detected" }

      it 'raises an application mismatch error' do
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end
  end
end
