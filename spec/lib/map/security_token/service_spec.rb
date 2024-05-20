# frozen_string_literal: true

require 'rails_helper'
require 'map/security_token/service'
require 'map/security_token/map_sts_token'

describe MAP::SecurityToken::Service do
  describe '#token' do
    subject { described_class.new.token(application:, icn:) }

    let(:application) { :some_application }
    let(:icn) { 'some-icn' }
    let(:log_prefix) { '[MAP][SecurityToken][Service]' }
    let(:expected_request_message) { "#{log_prefix} token request" }
    let(:expected_request_payload) { { application:, icn: } }

    shared_examples 'STS token request' do
      it 'logs the token request' do
        VCR.use_cassette('map/security_token_service_200_response') do
          expect(Rails.logger).to receive(:info).with(expected_request_message, expected_request_payload)
          expect(Rails.logger).to receive(:info).and_call_original
          subject
        end
      end

      context 'when the "cache" flag is enabled' do
        let(:map_sts_token) { SecureRandom.hex(100) }
        let(:expected_log_message) { "#{log_prefix} token success" }

        shared_examples 'new token request' do
          it 'does not return a cached token and calls for a new token',
             vcr: { cassette_name: 'map/security_token_service_200_response' } do
            expect(Rails.logger).to receive(:info).once.and_call_original
            expect(Rails.logger).to receive(:info).with(expected_log_message, { application:, icn:, cache: false })
            expect(subject[:access_token]).not_to eq(map_sts_token)
          end
        end

        context 'when a token with a matching ICN is cached' do
          let(:expiration) { 1.hour.from_now }
          let(:cached_token_application) { application }
          let(:cached_token) do
            {
              icn:,
              application: cached_token_application.to_s,
              expiration: expiration.utc.iso8601,
              access_token: map_sts_token
            }
          end

          before { MAP::SecurityToken::MapStsToken.create(cached_token) }

          context 'when the cached token has a different application' do
            let(:cached_token_application) { :some_other_application }

            it_behaves_like 'new token request'
          end

          context 'when the cached token is expired' do
            let(:expiration) { 1.hour.ago }

            it_behaves_like 'new token request'
          end

          context 'when the chached token is valid' do
            it 'returns the cached token' do
              expect(Rails.logger).to receive(:info).once.and_call_original
              expect(Rails.logger).to receive(:info).with(expected_log_message, { application:, icn:, cache: true })
              expect(subject[:access_token]).to eq(map_sts_token)
            end
          end
        end

        context 'when a token with a matching ICN is not cached' do
          it_behaves_like 'new token request'
        end
      end

      context 'when response is not successful with a 401 error' do
        let(:context) { { error: expected_error_message } }
        let(:expected_error_message) { 'invalid_client' }
        let(:expected_error_status) { 401 }
        let(:expected_message) { "#{log_prefix} token failed, client error" }
        let(:expected_error_response) do
          "#{expected_message}, status: #{expected_error_status}, application: #{application}, " \
            "icn: #{icn}, context: #{context}"
        end
        let(:expected_error) { Common::Client::Errors::ClientError }
        let(:expected_log_values) { { status: expected_error_status, application:, icn:, context: } }

        it 'raises a client error with expected message and creates a log' do
          VCR.use_cassette('map/security_token_service_401_response') do
            expect(Rails.logger).to receive(:error).with(expected_message, expected_log_values)
            expect { subject }.to raise_error(expected_error, expected_error_response)
          end
        end
      end

      context 'and response is successful' do
        let(:expected_log_message) { "#{log_prefix} token success" }
        let(:expected_log_payload) { { application:, icn:, cache: false } }

        it 'logs a token success message',
           vcr: { cassette_name: 'map/security_token_service_200_response' } do
          expect(Rails.logger).to receive(:info).once.and_call_original
          expect(Rails.logger).to receive(:info).with(expected_log_message, expected_log_payload)
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

    context 'when input application is appointments' do
      let(:application) { :appointments }

      it_behaves_like 'STS token request'
    end

    context 'when input application is arbitrary' do
      let(:application) { :some_application }
      let(:expected_error) { MAP::SecurityToken::Errors::ApplicationMismatchError }
      let(:expected_error_message) { "#{log_prefix} token failed, application mismatch detected" }
      let(:expected_log_values) { { application:, icn: } }

      it 'raises an application mismatch error and creates a log' do
        expect(Rails.logger).to receive(:error).with(expected_error_message, expected_log_values)
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when input ICN is missing' do
      let(:icn) { nil }
      let(:expected_error) { MAP::SecurityToken::Errors::MissingICNError }
      let(:expected_error_message) { "#{log_prefix} token failed, ICN not present in access token" }
      let(:expected_log_values) { { application: } }

      it 'raises a missing ICN error and creates a log' do
        expect(Rails.logger).to receive(:error).with(expected_error_message, expected_log_values)
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end
  end
end
