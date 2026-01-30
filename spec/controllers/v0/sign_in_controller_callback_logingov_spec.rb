# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/logingov/service'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'callback_setup'

  let(:csp_type) { SignIn::Constants::Auth::LOGINGOV }
  let(:logingov_uuid) { 'some-logingov-uuid' }

  describe 'GET callback' do
    context 'when state is a proper, expected JWT' do
      include_context 'callback_state_jwt_setup'

      let(:type) { csp_type }
      let(:acr) { SignIn::Constants::Auth::ACR_VALUES.first }

      context 'and code in state payload matches an existing state code' do
        before { Timecop.freeze }
        after { Timecop.return }

        context 'when type in state JWT is logingov' do
          let(:user_info) do
            OpenStruct.new(
              {
                verified_at: '1-1-2022',
                sub: logingov_uuid,
                social_security_number: '123456789',
                birthdate: '2022-01-01',
                given_name: 'some-name',
                family_name: 'some-family-name',
                email: 'some-email'
              }
            )
          end
          let(:mpi_profile) do
            build(:mpi_profile,
                  ssn: user_info.social_security_number,
                  birth_date: Formatters::DateFormatter.format_date(user_info.birthdate),
                  given_names: [user_info.given_name],
                  family_name: user_info.family_name)
          end
          let(:response) { OpenStruct.new(access_token: token, logingov_acr:, expires_in:) }
          let(:expires_in) { 900 }
          let(:logingov_acr) { IAL::LOGIN_GOV_IAL2 }
          let(:token) { 'some-token' }

          before do
            allow_any_instance_of(SignIn::Logingov::Service).to receive(:token).with(code_value).and_return(response)
            allow_any_instance_of(SignIn::Logingov::Service).to receive(:user_info).with(token).and_return(user_info)
          end

          context 'and code is given but does not match expected code for auth service' do
            let(:response) { nil }
            let(:expected_error) { 'Code is not valid' }
            let(:error_code) { SignIn::Constants::ErrorCode::INVALID_REQUEST }

            it_behaves_like 'callback_error_response'
          end

          context 'and code is given that matches expected code for auth service' do
            let(:response) { OpenStruct.new(access_token: token, logingov_acr:, expires_in:) }
            let(:expires_in) { 900 }
            let(:logingov_acr) { IAL::LOGIN_GOV_IAL2 }

            context 'and credential should be uplevelled' do
              let(:acr) { 'min' }
              let(:logingov_acr) { IAL::LOGIN_GOV_IAL1 }
              let(:expected_redirect_uri) { IdentitySettings.logingov.redirect_uri }
              let(:expected_redirect_uri_param) { { redirect_uri: expected_redirect_uri }.to_query }

              before do
                allow_any_instance_of(SignIn::StatePayloadJwtEncoder).to receive(:perform)
                  .and_return(uplevel_state_value)
              end

              it 'returns ok status' do
                expect(subject).to have_http_status(:ok)
              end

              it 'renders expected redirect_uri in template' do
                expect(subject.body).to match(expected_redirect_uri_param)
              end

              it 'generates a new state payload with a new StateCode' do
                expect_any_instance_of(SignIn::StatePayloadJwtEncoder).to receive(:perform)
                subject
              end

              it 'renders a new state' do
                expect(subject.body).to match(uplevel_state_value)
              end
            end

            context 'and credential should not be uplevelled' do
              let(:acr) { 'ial2' }
              let(:ial) { 2 }
              let(:client_code) { 'some-client-code' }
              let(:client_redirect_uri) { client_config.redirect_uri }
              let(:expected_log) { '[SignInService] [V0::SignInController] callback' }
              let(:statsd_callback_success) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS }
              let(:authentication_time) { 0 }
              let(:operation) { SignIn::Constants::Auth::AUTHORIZE }
              let(:expected_logger_context) do
                {
                  type:,
                  client_id:,
                  ial:,
                  acr:,
                  icn: mpi_profile.icn,
                  credential_uuid: logingov_uuid,
                  authentication_time:,
                  operation:
                }
              end
              let(:meta_refresh_tag) { '<meta http-equiv="refresh" content="0;' }

              before do
                allow(SecureRandom).to receive(:uuid).and_return(client_code)
                Timecop.freeze
              end

              after { Timecop.return }

              it 'returns ok status' do
                expect(subject).to have_http_status(:ok)
              end

              it 'renders the oauth_get_form template with meta refresh tag' do
                expect(subject.body).to include(meta_refresh_tag)
              end

              context 'and client configuration is configured to enforce terms of use' do
                let(:enforced_terms) { SignIn::Constants::Auth::VA_TERMS }

                context 'and the authenticated user has previously accepted terms of use' do
                  let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }
                  let(:user_account) { user_verification.user_account }
                  let(:user_verification) { create(:logingov_user_verification, logingov_uuid:) }

                  it 'directs to the given redirect url set in the client configuration' do
                    expect(subject.body).to include(client_redirect_uri)
                  end
                end

                context 'and the authenticated user has not previously accepted terms of use' do
                  let(:terms_of_use_redirect_uri) { "#{terms_of_use_url}?#{embedded_params}" }
                  let(:embedded_params) { { redirect_url: client_redirect_uri }.to_query }

                  it 'directs to the terms of use url and embeds redirect url set in the client configuration' do
                    expect(subject.body).to include(terms_of_use_redirect_uri)
                  end
                end
              end

              context 'and client configuration is not configured to enforce terms of use' do
                let(:enforced_terms) { nil }

                it 'directs to the given redirect url set in the client configuration' do
                  expect(subject.body).to include(client_redirect_uri)
                end
              end

              it 'includes expected code param' do
                expect(subject.body).to include(client_code)
              end

              it 'includes expected state param' do
                expect(subject.body).to include(client_state)
              end

              it 'includes expected type param' do
                expect(subject.body).to include(type)
              end

              it 'logs the successful callback' do
                expect(Rails.logger).to receive(:info).with(expected_log, expected_logger_context)
                subject
              end

              it 'updates StatsD with a callback request success' do
                expect { subject }.to trigger_statsd_increment(statsd_callback_success, tags: statsd_tags)
              end
            end
          end
        end
      end
    end
  end
end
