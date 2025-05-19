# frozen_string_literal: true

require 'rails_helper'
require 'mhv/account_creation/service'

describe MHV::AccountCreation::Service do
  describe '#create_account' do
    subject { described_class.new.create_account(icn:, email:, tou_occurred_at:, break_cache:, from_cache_only:) }

    let(:icn) { '10101V964144' }
    let(:email) { 'some-email@email.com' }
    let(:tou_status) { 'accepted' }
    let(:tou_version) { 'v1' }
    let(:tou_occurred_at) { Time.zone.now }
    let(:log_prefix) { '[MHV][AccountCreation][Service]' }
    let(:account_creation_base_url) { 'https://apigw-intb.aws.myhealth.va.gov' }
    let(:account_creation_path) { 'v1/usermgmt/account-service/account' }
    let(:break_cache) { false }
    let(:from_cache_only) { false }
    let(:start_time) { Time.zone.now }
    let(:end_time) { start_time + 10.seconds }

    let(:user_profile_id) { '12345678' }
    let(:premium) { true }
    let(:champ_va) { true }
    let(:patient) { true }
    let(:sm_account_created) { true }
    let(:message) { 'Existing MHV Account Found for ICN' }
    let(:expected_response_body) do
      { user_profile_id:, premium:, champ_va:, patient:, sm_account_created:, message: }
    end

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
      allow_any_instance_of(SignInService::Sts).to receive(:base_url).and_return('https://staging-api.va.gov')
      allow(Time).to receive(:current).and_return(start_time, end_time)
    end

    context 'when making a request' do
      let(:expected_tou_datetime) { tou_occurred_at.iso8601 }
      let(:expected_log_message) { "#{log_prefix} create_account request" }
      let(:expected_log_payload) { { icn: } }

      it 'sends vaTermsOfUseDateTime in the correct format' do
        VCR.use_cassette('mhv/account_creation/account_creation_service_200_created') do
          subject
          expect(a_request(:post, "#{account_creation_base_url}/#{account_creation_path}")
            .with(body: /"vaTermsOfUseDateTime":"#{expected_tou_datetime}"/)).to have_been_made
        end
      end

      it 'logs the create account request' do
        VCR.use_cassette('mhv/account_creation/account_creation_service_200_created') do
          subject
          expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
        end
      end
    end

    context 'when from_cache_only is true' do
      let(:from_cache_only) { true }
      let(:expected_cache_key) { "mhv_account_creation_#{icn}" }

      context 'when the account is in the cache' do
        before do
          allow(Rails.cache).to receive(:read).with(expected_cache_key).and_return(expected_response_body)
        end

        it 'returns the cached response' do
          expect(subject).to eq(expected_response_body)
        end

        it 'does not make a request to the account creation service' do
          subject
          expect(a_request(:post, "#{account_creation_base_url}/#{account_creation_path}")).not_to have_been_made
          expect(Rails.logger).not_to have_received(:info).with("#{log_prefix} create_account request",
                                                                anything)
        end
      end

      context 'when the account is not in the cache' do
        before do
          allow(Rails.cache).to receive(:read).with(expected_cache_key).and_return(nil)
        end

        it 'returns nil' do
          expect(subject).to be_nil
        end

        it 'does not make a request to the account creation service' do
          subject
          expect(a_request(:post, "#{account_creation_base_url}/#{account_creation_path}")).not_to have_been_made
          expect(Rails.logger).not_to have_received(:info).with("#{log_prefix} create_account request",
                                                                anything)
        end
      end
    end

    context 'when the response is successful' do
      let(:successful_response_cassette) { 'mhv/account_creation/account_creation_service_200_found' }
      let(:expected_log_message) { "#{log_prefix} create_account success" }
      let(:expected_log_payload) do
        { icn:, account: expected_response_body, from_cache: expected_from_cache_log,
          duration_ms: expected_duration }.compact
      end

      let(:expected_duration) { 10_000.0 }

      shared_examples 'a successful external request' do
        it 'makes a request to the account creation service' do
          VCR.use_cassette(successful_response_cassette) do
            subject
            expect(a_request(:post, "#{account_creation_base_url}/#{account_creation_path}")).to have_been_made
          end
        end

        it 'logs the create account success' do
          VCR.use_cassette(successful_response_cassette) do
            subject
            expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
          end
        end

        it 'returns the expected response' do
          VCR.use_cassette(successful_response_cassette) do
            expect(subject).to eq(expected_response_body)
          end
        end
      end

      context 'when the MHV account does not exist' do
        let(:expected_from_cache_log) { false }

        context 'when the user is not a VA patient' do
          let(:successful_response_cassette) { 'mhv/account_creation/account_creation_service_200_created_no_sm' }
          let(:champ_va) { false }
          let(:patient) { false }
          let(:sm_account_created) { false }
          let(:message) { 'MHV Account Created but SM Account not created' }

          it_behaves_like 'a successful external request'
        end

        context 'when the user is a VA patient' do
          let(:successful_response_cassette) { 'mhv/account_creation/account_creation_service_200_created' }
          let(:champ_va) { false }
          let(:message) { 'MHV Account Created' }

          it_behaves_like 'a successful external request'
        end
      end

      context 'when the account is not in the cache' do
        let(:expected_from_cache_log) { false }

        it_behaves_like 'a successful external request'
      end

      context 'when the account is in the cache' do
        let(:expected_from_cache_log) { true }
        let(:expected_cache_key) { "mhv_account_creation_#{icn}" }
        let(:expected_expires_in) { 1.day }

        context 'when break_cache is false' do
          let(:expected_duration) { nil }

          before do
            allow(Rails.cache).to receive(:fetch)
              .with(expected_cache_key, force: break_cache, expires_in: expected_expires_in)
              .and_return(expected_response_body)
          end

          it 'does not make a request to the account creation service' do
            subject
            expect(a_request(:post, "#{account_creation_base_url}/#{account_creation_path}")).not_to have_been_made
          end

          it 'logs the create account request' do
            subject
            expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
          end

          it 'returns the expected response from the cache' do
            expect(subject).to eq(expected_response_body)
          end
        end

        context 'when break_cache is true' do
          let(:break_cache) { true }
          let(:expected_from_cache_log) { false }

          before do
            allow(Rails.cache).to receive(:fetch)
              .with(expected_cache_key, force: break_cache, expires_in: expected_expires_in).and_call_original
          end

          it 'calls Rails.cache.fetch with force: true' do
            VCR.use_cassette('mhv/account_creation/account_creation_service_200_created') do
              subject
              expect(Rails.cache).to have_received(:fetch)
                .with(expected_cache_key, force: true, expires_in: expected_expires_in)
            end
          end

          it_behaves_like 'a successful external request'
        end
      end
    end

    context 'when the response is a client error' do
      shared_examples 'client error handling' do
        it 'logs and re-raises the client error' do
          VCR.use_cassette(client_error_cassette) do
            expect { subject }.to raise_error(Common::Client::Errors::ClientError)
            expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
          end
        end
      end

      context 'when the ICN is missing or does not match the STS token value' do
        let(:client_error_cassette) { 'mhv/account_creation/account_creation_service_400_invalid_icn' }
        let(:expected_log_message) { "#{log_prefix} create_account client_error" }
        let(:expected_log_payload) do
          {
            body: { errorCode: 812, message: 'Required ICN field is missing or invalid in the JWT' }.as_json,
            error_message: 'the server responded with status 400',
            status: 400,
            icn:
          }
        end

        it_behaves_like 'client error handling'
      end

      context 'when the MHV account exists and has been deactivated' do
        let(:client_error_cassette) { 'mhv/account_creation/account_creation_service_400_deactivated_account' }
        let(:expected_log_message) { "#{log_prefix} create_account client_error" }
        let(:expected_log_payload) do
          {
            body: { errorCode: 805, message: 'Deactivated Account found in MHV for ICN' }.as_json,
            error_message: 'the server responded with status 400',
            status: 400,
            icn:
          }
        end

        it_behaves_like 'client error handling'
      end

      context 'when the STS token is invalid' do
        let(:client_error_cassette) { 'mhv/account_creation/account_creation_service_403_invalid_sts' }
        let(:expected_log_message) { "#{log_prefix} create_account client_error" }
        let(:expected_log_payload) do
          {
            body: { errorCode: 808, message: 'Application authentication failed' }.as_json,
            error_message: 'the server responded with status 403',
            status: 403,
            icn:
          }
        end

        it_behaves_like 'client error handling'
      end
    end

    context 'when the response is a parsing error' do
      let(:expected_log_message) { "#{log_prefix} create_account parsing_error" }
      let(:expected_log_payload) do
        {
          body: 'Internal Server Error',
          error_message: "unexpected token 'Internal Server Error' at line 1 column 1",
          status: 500,
          icn:
        }
      end

      it 'logs and re-raises the parsing error' do
        VCR.use_cassette('mhv/account_creation/account_creation_service_500_response') do
          expect { subject }.to raise_error(Common::Client::Errors::ParsingError)
          expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
        end
      end
    end

    context 'when the STS token request fails' do
      let(:expected_log_message) { "#{log_prefix} sts token request failed" }
      let(:expected_log_payload) { { user_identifier: icn, error_message: 'Service account config not found' } }

      it 'logs and re-raises the STS token request failure' do
        VCR.use_cassette('sign_in_service/sts/sts_token_400_response') do
          expect { subject }.to raise_error(Common::Client::Errors::ClientError)
          expect(Rails.logger).to have_received(:error).with(expected_log_message, expected_log_payload)
        end
      end
    end
  end
end
