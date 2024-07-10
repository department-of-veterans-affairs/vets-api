# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/logingov/service'
require 'sign_in/idme/service'

RSpec.describe V0::SignIns::CallbackController, type: :controller do
  describe 'GET callback' do
    subject { get(:callback, params: {}.merge(code).merge(state).merge(error)) }

    let(:code) { { code: code_value } }
    let(:state) { { state: state_value } }
    let(:error) { { error: error_value } }
    let(:state_value) { 'some-state' }
    let(:code_value) { 'some-code' }
    let(:error_value) { 'some-error' }
    let(:statsd_tags) { ["type:#{type}", "client_id:#{client_id}", "ial:#{ial}", "acr:#{acr}"] }
    let(:type) {}
    let(:acr) { nil }
    let(:mpi_update_profile_response) { create(:add_person_response) }
    let(:mpi_add_person_response) { create(:add_person_response, parsed_codes: { icn: add_person_icn }) }
    let(:add_person_icn) { nil }
    let(:find_profile) { create(:find_profile_response, profile: mpi_profile) }
    let(:mpi_profile) { nil }
    let(:client_id) { client_config.client_id }
    let(:authentication) { SignIn::Constants::Auth::API }
    let!(:client_config) { create(:client_config, authentication:, enforced_terms:, terms_of_use_url:) }
    let(:enforced_terms) { nil }
    let(:terms_of_use_url) { 'some-terms-of-use-url' }

    before do
      allow(Rails.logger).to receive(:info)
      allow_any_instance_of(MPI::Service).to receive(:update_profile).and_return(mpi_update_profile_response)
      allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(find_profile)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(find_profile)
      allow_any_instance_of(MPI::Service).to receive(:add_person_implicit_search).and_return(mpi_add_person_response)
    end

    shared_examples 'api based error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:statsd_callback_failure) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE }
      let(:expected_error_log) { '[SignInService] [V0::SignIns::CallbackController] callback error' }
      let(:expected_error_message) do
        { errors: expected_error, client_id:, type:, acr: }
      end

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed callback' do
        expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_message)
        subject
      end

      it 'updates StatsD with a callback request failure' do
        expect { subject }.to trigger_statsd_increment(statsd_callback_failure)
      end
    end

    shared_examples 'error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:statsd_callback_failure) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE }

      context 'and client_id maps to a web based configuration' do
        let(:authentication) { SignIn::Constants::Auth::COOKIE }
        let(:expected_error_status) { :ok }
        let(:auth_param) { 'fail' }
        let(:expected_error_log) { '[SignInService] [V0::SignIns::CallbackController] callback error' }
        let(:expected_error_message) { { errors: expected_error, client_id:, type:, acr: } }
        let(:request_id) { SecureRandom.uuid }
        let(:meta_refresh_tag) { '<meta http-equiv="refresh" content="0;' }

        before do
          allow_any_instance_of(ActionController::TestRequest).to receive(:request_id).and_return(request_id)
        end

        it 'renders the oauth_get_form template with meta refresh tag' do
          expect(subject.body).to include(meta_refresh_tag)
        end

        it 'directs to the given redirect url set in the client configuration' do
          expect(subject.body).to include(client_config.redirect_uri)
        end

        it 'includes expected auth param' do
          expect(subject.body).to include(auth_param)
        end

        it 'includes expected code param' do
          expect(subject.body).to include(error_code)
        end

        it 'includes expected request_id param' do
          expect(subject.body).to include(request_id)
        end

        it 'returns expected status' do
          expect(subject).to have_http_status(expected_error_status)
        end

        it 'logs the failed callback' do
          expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_message)
          subject
        end

        it 'updates StatsD with a callback request failure' do
          expect { subject }.to trigger_statsd_increment(statsd_callback_failure)
        end
      end

      context 'and client_id maps to an api based configuration' do
        let(:authentication) { SignIn::Constants::Auth::API }

        it_behaves_like 'api based error response'
      end
    end

    context 'when error is not given' do
      let(:error) { {} }

      context 'when code is not given' do
        let(:code) { {} }
        let(:expected_error) { 'Code is not defined' }
        let(:client_id) { nil }

        it_behaves_like 'api based error response'
      end

      context 'when state is not given' do
        let(:state) { {} }
        let(:expected_error) { 'State is not defined' }
        let(:client_id) { nil }

        it_behaves_like 'api based error response'
      end

      context 'when state is arbitrary' do
        let(:state_value) { 'some-state' }
        let(:expected_error) { 'State JWT is malformed' }
        let(:client_id) { nil }

        it_behaves_like 'api based error response'
      end

      context 'when state is a JWT but with improper signature' do
        let(:state_value) { JWT.encode('some-state', private_key, encode_algorithm) }
        let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
        let(:encode_algorithm) { SignIn::Constants::Auth::JWT_ENCODE_ALGORITHM }
        let(:expected_error) { 'State JWT body does not match signature' }
        let(:client_id) { nil }

        it_behaves_like 'api based error response'
      end

      context 'when state is a proper, expected JWT' do
        let(:state_value) do
          SignIn::StatePayloadJwtEncoder.new(code_challenge:,
                                             code_challenge_method:,
                                             acr:,
                                             client_config:,
                                             type:,
                                             client_state:).perform
        end
        let(:uplevel_state_value) do
          SignIn::StatePayloadJwtEncoder.new(code_challenge:,
                                             code_challenge_method:,
                                             acr:,
                                             client_config:,
                                             type:,
                                             client_state:).perform
        end
        let(:code_challenge) { Base64.urlsafe_encode64('some-code-challenge') }
        let(:code_challenge_method) { SignIn::Constants::Auth::CODE_CHALLENGE_METHOD }
        let(:acr) { SignIn::Constants::Auth::ACR_VALUES.first }
        let(:type) { SignIn::Constants::Auth::CSP_TYPES.first }
        let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }

        context 'and code in state payload matches an existing state code' do
          context 'when type in state JWT is logingov' do
            let(:type) { SignIn::Constants::Auth::LOGINGOV }
            let(:response) { OpenStruct.new(access_token: token) }
            let(:token) { 'some-token' }
            let(:logingov_uuid) { 'some-logingov_uuid' }
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

            before do
              allow_any_instance_of(SignIn::Logingov::Service).to receive(:token).with(code_value).and_return(response)
              allow_any_instance_of(SignIn::Logingov::Service).to receive(:user_info).with(token).and_return(user_info)
            end

            context 'and code is given but does not match expected code for auth service' do
              let(:response) { nil }
              let(:expected_error) { 'Code is not valid' }
              let(:error_code) { SignIn::Constants::ErrorCode::INVALID_REQUEST }

              it_behaves_like 'error response'
            end

            context 'and code is given that matches expected code for auth service' do
              let(:response) { OpenStruct.new(access_token: token, logingov_acr:, expires_in:) }
              let(:expires_in) { 900 }
              let(:logingov_acr) { IAL::LOGIN_GOV_IAL2 }

              context 'and credential should be uplevelled' do
                let(:acr) { 'min' }
                let(:logingov_acr) { IAL::LOGIN_GOV_IAL1 }
                let(:expected_redirect_uri) { Settings.logingov.redirect_uri }
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
                let(:expected_log) { '[SignInService] [V0::SignIns::CallbackController] callback' }
                let(:statsd_callback_success) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS }
                let(:authentication_time) { 0 }
                let(:expected_logger_context) do
                  {
                    type:,
                    client_id:,
                    ial:,
                    acr:,
                    icn: mpi_profile.icn,
                    uuid: logingov_uuid,
                    authentication_time:
                  }
                end
                let(:mpi_profile) do
                  build(:mpi_profile,
                        ssn: user_info.social_security_number,
                        birth_date: Formatters::DateFormatter.format_date(user_info.birthdate),
                        given_names: [user_info.given_name],
                        family_name: user_info.family_name)
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

          context 'when type in state JWT is idme' do
            let(:type) { SignIn::Constants::Auth::IDME }
            let(:idme_uuid) { 'some-idme-uuid' }
            let(:user_info) do
              OpenStruct.new(
                sub: idme_uuid,
                level_of_assurance:,
                credential_ial:,
                social: '123456789',
                birth_date: '2022-01-01',
                fname: 'some-name',
                lname: 'some-family-name',
                email: 'some-email'
              )
            end
            let(:mpi_profile) do
              build(:mpi_profile,
                    ssn: user_info.social,
                    birth_date: Formatters::DateFormatter.format_date(user_info.birth_date),
                    given_names: [user_info.fname],
                    family_name: user_info.lname)
            end
            let(:response) { OpenStruct.new(access_token: token) }
            let(:level_of_assurance) { LOA::THREE }
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

              it_behaves_like 'error response'
            end

            context 'and code is given that matches expected code for auth service' do
              let(:response) { OpenStruct.new(access_token: token) }
              let(:level_of_assurance) { LOA::THREE }

              context 'and credential should be uplevelled' do
                let(:acr) { 'min' }
                let(:credential_ial) { LOA::ONE }
                let(:expected_redirect_uri) { Settings.idme.redirect_uri }
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
                let(:acr) { 'loa3' }
                let(:ial) { 2 }
                let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
                let(:client_code) { 'some-client-code' }
                let(:client_redirect_uri) { client_config.redirect_uri }
                let(:expected_log) { '[SignInService] [V0::SignIns::CallbackController] callback' }
                let(:statsd_callback_success) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS }
                let(:authentication_time) { 0 }
                let(:expected_logger_context) do
                  {
                    type:,
                    client_id:,
                    ial:,
                    acr:,
                    icn: mpi_profile.icn,
                    uuid: idme_uuid,
                    authentication_time:
                  }
                end
                let(:meta_refresh_tag) { '<meta http-equiv="refresh" content="0;' }

                before do
                  allow(SecureRandom).to receive(:uuid).and_return(client_code)
                end

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
                    let(:user_verification) { create(:idme_user_verification, idme_uuid:) }

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
                  expect { subject }.to trigger_statsd_increment(statsd_callback_success, tags: statsd_tags)
                end
              end
            end
          end

          context 'when type in state JWT is dslogon' do
            let(:type) { SignIn::Constants::Auth::DSLOGON }
            let(:backing_idme_uuid) { 'some-backing-idme-uuid' }
            let(:dslogon_uuid) { 'some-dslogon-uuid' }
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

              it_behaves_like 'error response'
            end

            context 'and code is given that matches expected code for auth service' do
              let(:response) { OpenStruct.new(access_token: token) }
              let(:level_of_assurance) { LOA::THREE }
              let(:acr) { SignIn::Constants::Auth::MIN }
              let(:ial) { 2 }
              let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
              let(:client_code) { 'some-client-code' }
              let(:client_redirect_uri) { client_config.redirect_uri }
              let(:expected_log) { '[SignInService] [V0::SignIns::CallbackController] callback' }
              let(:statsd_callback_success) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS }
              let(:authentication_time) { 0 }
              let(:expected_icn) { nil }
              let(:expected_logger_context) do
                {
                  type:,
                  client_id:,
                  ial:,
                  acr:,
                  icn: expected_icn,
                  uuid: backing_idme_uuid,
                  authentication_time:
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

          context 'when type in state JWT is mhv' do
            let(:type) { SignIn::Constants::Auth::MHV }
            let(:backing_idme_uuid) { 'some-backing-idme-uuid' }
            let(:mhv_uuid) { 'some-mhv-uuid' }
            let(:user_info) do
              OpenStruct.new(
                sub: backing_idme_uuid,
                level_of_assurance:,
                credential_ial:,
                mhv_uuid:,
                mhv_icn:,
                mhv_assurance:,
                email: 'some-email'
              )
            end
            let(:mhv_icn) { '987654321V123456' }
            let(:add_person_icn) { mhv_icn }
            let(:response) { OpenStruct.new(access_token: token) }
            let(:level_of_assurance) { LOA::THREE }
            let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
            let(:token) { 'some-token' }
            let(:mhv_assurance) { 'some-mhv-assurance' }
            let(:mpi_profile) do
              build(:mpi_profile,
                    icn: user_info.mhv_icn,
                    mhv_ids: [user_info.mhv_uuid])
            end

            before do
              allow_any_instance_of(SignIn::Idme::Service).to receive(:token).with(code_value).and_return(response)
              allow_any_instance_of(SignIn::Idme::Service).to receive(:user_info).with(token).and_return(user_info)
            end

            context 'and code is given but does not match expected code for auth service' do
              let(:response) { nil }
              let(:expected_error) { 'Code is not valid' }
              let(:error_code) { SignIn::Constants::ErrorCode::INVALID_REQUEST }

              it_behaves_like 'error response'
            end

            context 'and code is given that matches expected code for auth service' do
              let(:response) { OpenStruct.new(access_token: token) }
              let(:level_of_assurance) { LOA::THREE }
              let(:acr) { SignIn::Constants::Auth::MIN }
              let(:ial) { IAL::TWO }
              let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
              let(:client_code) { 'some-client-code' }
              let(:client_redirect_uri) { client_config.redirect_uri }
              let(:expected_log) { '[SignInService] [V0::SignIns::CallbackController] callback' }
              let(:statsd_callback_success) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS }
              let(:expected_icn) { mpi_profile.icn }
              let(:authentication_time) { 0 }
              let(:expected_logger_context) do
                {
                  type:,
                  client_id:,
                  ial:,
                  acr:,
                  icn: expected_icn,
                  uuid: backing_idme_uuid,
                  authentication_time:
                }
              end
              let(:meta_refresh_tag) { '<meta http-equiv="refresh" content="0;' }

              before do
                allow(SecureRandom).to receive(:uuid).and_return(client_code)
              end

              shared_context 'mhv successful callback' do
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
                  expect { subject }.to trigger_statsd_increment(statsd_callback_success, tags: statsd_tags)
                end
              end

              context 'and mhv account is not premium' do
                let(:mhv_assurance) { 'some-mhv-assurance' }
                let(:ial) { IAL::ONE }
                let(:expected_icn) { nil }

                it_behaves_like 'mhv successful callback'
              end

              context 'and mhv account is premium' do
                let(:mhv_assurance) { 'Premium' }
                let(:ial) { IAL::TWO }

                it_behaves_like 'mhv successful callback'

                context 'and client configuration is configured to enforce terms of use' do
                  let(:enforced_terms) { SignIn::Constants::Auth::VA_TERMS }

                  context 'and the authenticated user has previously accepted terms of use' do
                    let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }
                    let(:user_account) { user_verification.user_account }
                    let(:user_verification) { create(:mhv_user_verification, mhv_uuid:, backing_idme_uuid:) }

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

        context 'and code in state payload does not match an existing state code' do
          let(:expected_error) { 'Code in state is not valid' }
          let(:error_code) { SignIn::Constants::ErrorCode::INVALID_REQUEST }

          before { allow(SignIn::StateCode).to receive(:find).and_return(nil) }

          it_behaves_like 'error response'
        end
      end
    end

    context 'when error is given' do
      let(:state_value) do
        SignIn::StatePayloadJwtEncoder.new(code_challenge:,
                                           code_challenge_method:,
                                           acr:,
                                           client_config:,
                                           type:,
                                           client_state:).perform
      end
      let(:code_challenge) { Base64.urlsafe_encode64('some-code-challenge') }
      let(:code_challenge_method) { SignIn::Constants::Auth::CODE_CHALLENGE_METHOD }
      let(:acr) { SignIn::Constants::Auth::ACR_VALUES.first }
      let(:type) { SignIn::Constants::Auth::CSP_TYPES.first }
      let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }

      context 'and error is access denied value' do
        let(:error_value) { SignIn::Constants::Auth::ACCESS_DENIED }
        let(:expected_error) { 'User Declined to Authorize Client' }

        context 'and type from state is logingov' do
          let(:type) { SignIn::Constants::Auth::LOGINGOV }
          let(:error_code) { SignIn::Constants::ErrorCode::LOGINGOV_VERIFICATION_DENIED }

          it_behaves_like 'error response'
        end

        context 'and type from state is some other value' do
          let(:type) { SignIn::Constants::Auth::IDME }
          let(:error_code) { SignIn::Constants::ErrorCode::IDME_VERIFICATION_DENIED }

          it_behaves_like 'error response'
        end
      end

      context 'and error is an arbitrary value' do
        let(:error_value) { 'some-error-value' }
        let(:expected_error) { 'Unknown Credential Provider Issue' }
        let(:error_code) { SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE }

        it_behaves_like 'error response'
      end
    end
  end
end
