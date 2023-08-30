# frozen_string_literal: true

require 'rails_helper'
require 'mobile_application_platform/security_token/service'

describe MobileApplicationPlatform::SecurityToken::Service do
  describe '#token' do
    subject { described_class.new.token(application:, icn:) }

    let(:application) { :some_application }
    let(:icn) { 'some-icn' }
    let(:log_prefix) { '[MobileApplicationPlatform][SecurityToken][Service]' }

    shared_examples 'STS token request' do
      context 'when an issue occurs with the client request' do
        let(:expected_error) { Common::Client::Errors::ClientError }
        let(:expected_error_message) do
          "#{log_prefix} Token failed, client error, status: #{status}, description: #{description}," \
            " application: #{application}, icn: #{icn}"
        end
        let(:status) { 'some-status' }
        let(:description) { 'some-description' }
        let(:raised_error) { Common::Client::Errors::ClientError.new(nil, status, { error_description: description }) }

        before do
          allow_any_instance_of(described_class).to receive(:perform).and_raise(raised_error)
        end

        it 'raises a client error with expected message' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'and response is malformed' do
        let(:expected_error) { NoMethodError }
        let(:expected_error_message) do
          "#{log_prefix} Token failed, response unknown, application: #{application}, icn: #{icn}"
        end
        let(:status) { 'some-status' }
        let(:description) { 'some-description' }
        let(:empty_response) { nil }

        before do
          allow_any_instance_of(described_class).to receive(:perform).and_return(empty_response)
        end

        it 'raises an unknown response error with expected message' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'and response is successful' do
        let(:expected_log_message) { "#{log_prefix} Token Success, application: #{application}, icn: #{icn}" }

        it 'logs a token success message',
           vcr: { cassette_name: 'mobile_application_platform/security_token_service_200_response' } do
          expect(Rails.logger).to receive(:info).with(expected_log_message)
          subject
        end

        it 'returns an access token field',
           vcr: { cassette_name: 'mobile_application_platform/security_token_service_200_response' } do
          expect(subject[:access_token]).not_to be_nil
        end

        it 'returns an expiration field',
           vcr: { cassette_name: 'mobile_application_platform/security_token_service_200_response' } do
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

    context 'when input application is arbitrary' do
      let(:application) { :some_application }
      let(:expected_error) { MobileApplicationPlatform::SecurityToken::Errors::ApplicationMismatchError }
      let(:expected_error_message) { "#{log_prefix} Application mismatch detected" }

      it 'raises an application mismatch error' do
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end
  end
end
