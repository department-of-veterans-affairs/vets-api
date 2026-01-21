# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'token_setup'

  describe 'POST token' do
    context 'when grant_type is jwt-bearer' do
      let(:grant_type_value) { SignIn::Constants::Auth::JWT_BEARER_GRANT }
      let(:assertion_value) { nil }

      context 'and assertion is not a valid jwt' do
        let(:assertion_value) { 'some-assertion-value' }
        let(:expected_error) { 'Assertion is malformed' }

        it_behaves_like 'token_error_response'
      end

      context 'and assertion is a valid jwt' do
        let(:private_key) { OpenSSL::PKey::RSA.new(File.read(private_key_path)) }
        let(:private_key_path) { 'spec/fixtures/sign_in/sts_client.pem' }
        let(:assertion_payload) do
          {
            iss:,
            aud:,
            sub:,
            jti:,
            iat:,
            exp:,
            service_account_id:,
            scopes:
          }
        end
        let(:iss) { audience }
        let(:aud) { "https://#{Settings.hostname}#{SignIn::Constants::Auth::TOKEN_ROUTE_PATH}" }
        let(:sub) { user_identifier }
        let(:jti) { 'some-jti' }
        let(:iat) { 1.month.ago.to_i }
        let(:exp) { 1.month.since.to_i }
        let(:user_identifier) { 'some-user-identifier' }
        let(:service_account_id) { service_account_config.service_account_id }
        let(:scopes) { [service_account_config.scopes.first] }
        let(:audience) { service_account_config.access_token_audience }
        let(:expiration_time) { SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES.since.to_i }
        let(:created_time) { Time.zone.now.to_i }
        let(:uuid) { 'some-uuid' }
        let(:version) { SignIn::Constants::AccessToken::CURRENT_VERSION }
        let(:assertion_certificate) do
          create(:sign_in_certificate, pem: File.read('spec/fixtures/sign_in/sts_client.crt'))
        end
        let(:service_account_config) { create(:service_account_config, certs: [assertion_certificate]) }
        let(:assertion_encode_algorithm) { SignIn::Constants::Auth::ASSERTION_ENCODE_ALGORITHM }
        let(:assertion_value) do
          JWT.encode(assertion_payload, private_key, assertion_encode_algorithm)
        end
        let(:expected_log) { '[SignInService] [V0::SignInController] token' }
        let(:expected_log_values) { {} }

        before do
          allow(Rails.logger).to receive(:info)
          allow(SecureRandom).to receive(:uuid).and_return(uuid)
          Timecop.freeze
        end

        after do
          Timecop.return
        end

        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
        end

        it 'returns expected body with access token' do
          expect(JSON.parse(subject.body)['data']).to have_key('access_token')
        end

        it 'logs the successful token request' do
          expect(Rails.logger).to receive(:info).with(expected_log, expected_log_values)
          subject
        end

        it 'updates StatsD with a token request success' do
          expect { subject }.to trigger_statsd_increment(statsd_token_success)
        end
      end
    end
  end
end
