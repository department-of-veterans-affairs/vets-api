# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/idme/service'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'callback_setup'

  let(:csp_type) { SignIn::Constants::Auth::DSLOGON }
  let(:backing_idme_uuid) { 'some-backing-idme-uuid' }
  let(:dslogon_uuid) { 'some-dslogon-uuid' }

  describe 'GET callback' do
    context 'when state is a proper, expected JWT' do
      include_context 'callback_state_jwt_setup'

      let(:type) { csp_type }
      let(:acr) { SignIn::Constants::Auth::ACR_VALUES.first }

      context 'and code in state payload matches an existing state code' do
        before { Timecop.freeze }
        after { Timecop.return }

        context 'when type in state JWT is dslogon' do
          let(:user_info) do
            OpenStruct.new(
              sub: backing_idme_uuid,
              level_of_assurance:,
              credential_ial:,
              dslogon_idvalue: '123456789',
              dslogon_birth_date: '1-1-2022',
              dslogon_fname: 'some-name',
              dslogon_mname: 'some-middle-name',
              dslogon_lname: 'some-family-name',
              dslogon_uuid:,
              dslogon_assurance:,
              email: 'some-email'
            )
          end
          let(:mpi_profile) do
            build(:mpi_profile,
                  ssn: user_info.dslogon_idvalue,
                  birth_date: Formatters::DateFormatter.format_date(user_info.dslogon_birth_date),
                  given_names: [user_info.dslogon_fname, user_info.dslogon_mname],
                  family_name: user_info.dslogon_lname,
                  edipi: user_info.dslogon_uuid)
          end
          let(:response) { OpenStruct.new(access_token: token) }
          let(:level_of_assurance) { LOA::THREE }
          let(:dslogon_assurance) { 'some-dslogon-assurance' }
          let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
          let(:token) { 'some-token' }

          before do
            allow_any_instance_of(SignIn::Idme::Service).to receive(:token).with(code_value).and_return(response)
            allow_any_instance_of(SignIn::Idme::Service).to receive(:user_info).with(token).and_return(user_info)
          end

          context 'and code is given but does not match expected code for auth service' do
            let(:response) { nil }
            let(:expected_error) { 'Code is not valid' }
            let(:error_code) { SignIn::Constants::ErrorCode::INVALID_REQUEST }

            it_behaves_like 'callback_error_response'
          end

          context 'and code is given that matches expected code for auth service' do
            let(:response) { OpenStruct.new(access_token: token) }
            let(:level_of_assurance) { LOA::THREE }
            let(:acr) { SignIn::Constants::Auth::MIN }
            let(:ial) { 2 }
            let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
            let(:client_code) { 'some-client-code' }
            let(:client_redirect_uri) { client_config.redirect_uri }
            let(:expected_log) { '[SignInService] [V0::SignInController] callback' }
            let(:statsd_callback_success) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS }
            let(:authentication_time) { 0 }
            let(:expected_icn) { nil }
            let(:operation) { SignIn::Constants::Auth::AUTHORIZE }
            let(:expected_logger_context) do
              {
                type:,
                client_id:,
                ial:,
                acr:,
                icn: expected_icn,
                credential_uuid: backing_idme_uuid,
                authentication_time:,
                operation:
              }
            end
            let(:meta_refresh_tag) { '<meta http-equiv="refresh" content="0;' }

            before do
              allow(SecureRandom).to receive(:uuid).and_return(client_code)
            end

            shared_context 'dslogon successful callback' do
              it 'returns ok status' do
                expect(subject).to have_http_status(:ok)
              end

              it 'renders the oauth_get_form template with meta refresh tag' do
                expect(subject.body).to include(meta_refresh_tag)
              end

              it 'directs to the given redirect url set in the client configuration' do
                expect(subject.body).to include(client_redirect_uri)
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

            context 'and dslogon account is not premium' do
              let(:dslogon_assurance) { 'some-dslogon-assurance' }
              let(:ial) { IAL::ONE }

              it_behaves_like 'dslogon successful callback'
            end

            context 'and dslogon account is premium' do
              let(:dslogon_assurance) { LOA::DSLOGON_ASSURANCE_THREE }
              let(:ial) { IAL::TWO }
              let(:expected_icn) { mpi_profile.icn }

              it_behaves_like 'dslogon successful callback'

              context 'and client configuration is configured to enforce terms of use' do
                let(:enforced_terms) { SignIn::Constants::Auth::VA_TERMS }

                context 'and the authenticated user has previously accepted terms of use' do
                  let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }
                  let(:user_account) { user_verification.user_account }
                  let(:user_verification) { create(:dslogon_user_verification, dslogon_uuid:, backing_idme_uuid:) }

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
            end
          end
        end
      end
    end
  end
end
