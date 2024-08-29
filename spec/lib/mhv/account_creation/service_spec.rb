# frozen_string_literal: true

require 'rails_helper'
require 'mhv/account_creation/service'

describe MHV::AccountCreation::Service do
  describe '#create_account' do
    subject { described_class.new.create_account(icn:, email:, tou_occurred_at:) }

    let(:icn) { '10101V964144' }
    let(:email) { 'some-email@email.com' }
    let(:tou_status) { 'accepted' }
    let(:tou_version) { 'v1' }
    let(:tou_occurred_at) { Time.current }
    let(:log_prefix) { '[MHV][AccountCreation][Service]' }

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
      allow_any_instance_of(SignInService::Sts).to receive(:base_url).and_return('https://staging-api.va.gov')
    end

    context 'when the response is successful' do
      let(:expected_log_message) { "#{log_prefix} create_account success" }
      let(:expected_log_payload) { { icn: } }
      let(:expected_response_body) do
        {
          mhv_userprofileid: '12345678',
          is_premium: true,
          is_champ_va: true,
          is_patient: true,
          is_sm_account_created: true,
          message: 'Existing MHV Account Found for ICN'
        }
      end

      it 'logs the create account request' do
        VCR.use_cassette('mhv/account_creation/account_creation_service_200_response') do
          subject
          expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
        end
      end

      it 'returns the expected response' do
        VCR.use_cassette('mhv/account_creation/account_creation_service_200_response') do
          expect(subject).to eq(expected_response_body)
        end
      end
    end

    context 'when the response is a client error' do
      let(:expected_log_message) { "#{log_prefix} create_account client_error" }
      let(:expected_log_payload) do
        {
          body: { errorCode: 812, message: 'Required ICN field is missing or invalid in the JWT' }.as_json,
          error_message: 'the server responded with status 400',
          icn:
        }
      end

      it 'logs the client error' do
        VCR.use_cassette('mhv/account_creation/account_creation_service_400_response') do
          subject
          expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
        end
      end
    end

    context 'when the response is a parsing error' do
      let(:expected_log_message) { "#{log_prefix} create_account parsing_error" }
      let(:expected_log_payload) do
        {
          body: 'Internal Server Error',
          error_message: "unexpected token at 'Internal Server Error'",
          icn:
        }
      end

      it 'logs the parsing error' do
        VCR.use_cassette('mhv/account_creation/account_creation_service_500_response') do
          subject
          expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
        end
      end
    end

    context 'when the STS token request fails' do
      let(:expected_log_message) { "#{log_prefix} sts token request failed" }
      let(:expected_log_payload) { { user_identifier: icn, error_message: 'Service account config not found' } }

      it 'logs the STS token request failure' do
        VCR.use_cassette('sign_in_service/sts/sts_token_400_response') do
          subject
          expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
        end
      end
    end
  end
end
