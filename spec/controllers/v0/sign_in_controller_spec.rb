# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  let(:request_id) { SecureRandom.uuid }

  before do
    allow_any_instance_of(ActionController::TestRequest).to receive(:request_id).and_return(request_id)
  end

  describe 'GET authorize' do
    subject do
      get(:authorize, params: authorize_params)
    end

    let(:authorize_params) do
      {}.merge(type).merge(code_challenge).merge(code_challenge_method).merge(client_state).merge(client_id).merge(acr)
    end
    let(:acr) { { acr: acr_value } }
    let(:acr_value) { 'some-acr' }
    let(:code_challenge) { { code_challenge: 'some-code-challenge' } }
    let(:code_challenge_method) { { code_challenge_method: 'some-code-challenge-method' } }
    let(:client_id) { { client_id: client_id_value } }
    let(:client_id_value) { 'some-client-id' }
    let(:client_state) { {} }
    let(:client_state_minimum_length) { SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH }
    let(:type) { { type: type_value } }
    let(:type_value) { 'some-type' }
    let(:statsd_tags) { ["type:#{type_value}", "client_id:#{client_id_value}", "acr:#{acr_value}"] }

    before { allow(Rails.logger).to receive(:info) }

    shared_examples 'api based error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:statsd_auth_failure) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] authorize error' }
      let(:expected_error_message) do
        { errors: expected_error, client_id: client_id_value, type: type_value, acr: acr_value }
      end

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed authorize attempt' do
        expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_message)
        subject
      end

      it 'updates StatsD with a auth request failure' do
        expect { subject }.to trigger_statsd_increment(statsd_auth_failure)
      end
    end

    shared_examples 'error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:statsd_auth_failure) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] authorize error' }
      let(:expected_error_message) do
        { errors: expected_error, client_id: client_id_value, type: type_value, acr: acr_value }
      end

      context 'and client_id is a web based setting' do
        let(:client_id_value) { SignIn::Constants::ClientConfig::COOKIE_AUTH.first }
        let(:expected_error_status) { :redirect }
        let(:expected_redirect_params) do
          { auth: 'fail', code: SignIn::Constants::ErrorCode::INVALID_REQUEST, request_id: request_id }.to_query
        end
        let(:expected_redirect) do
          uri = URI.parse(Settings.sign_in.client_redirect_uris.web)
          uri.query = expected_redirect_params
          uri.to_s
        end

        it 'redirects to frontend failure page' do
          expect(subject).to redirect_to(expected_redirect)
        end

        it 'returns expected status' do
          expect(subject).to have_http_status(expected_error_status)
        end

        it 'logs the failed authorize attempt' do
          expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_message)
          subject
        end

        it 'updates StatsD with a auth request failure' do
          expect { subject }.to trigger_statsd_increment(statsd_auth_failure)
        end
      end

      context 'and client_id is an api based setting' do
        let(:client_id_value) { SignIn::Constants::ClientConfig::API_AUTH.first }

        it_behaves_like 'api based error response'
      end
    end

    context 'when client_id is not given' do
      let(:client_id) { {} }
      let(:client_id_value) { nil }
      let(:expected_error) { 'Client id is not valid' }
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:statsd_auth_failure) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE }

      it_behaves_like 'api based error response'
    end

    context 'when client_id is an arbitrary value' do
      let(:client_id_value) { 'some-client-id' }
      let(:expected_error) { 'Client id is not valid' }
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:statsd_auth_failure) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE }

      it_behaves_like 'api based error response'
    end

    context 'when client_id is in CLIENT_IDS' do
      let(:client_id_value) { SignIn::Constants::ClientConfig::CLIENT_IDS.first }

      context 'when type param is not given' do
        let(:type) { {} }
        let(:type_value) { nil }
        let(:expected_error) { 'Type is not valid' }

        it_behaves_like 'error response'
      end

      context 'when type param is given but not in REDIRECT_URLS' do
        let(:type_value) { 'some-undefined-type' }
        let(:type) { { type: type_value } }
        let(:expected_error) { 'Type is not valid' }

        it_behaves_like 'error response'
      end

      context 'when type param is logingov' do
        let(:type_value) { 'logingov' }

        context 'and acr param is not given' do
          let(:acr) { {} }
          let(:acr_value) { nil }
          let(:expected_error) { 'ACR is not valid' }

          it_behaves_like 'error response'
        end

        context 'and acr param is given but not in ACR_VALUES' do
          let(:acr_value) { 'some-undefiend-acr' }
          let(:expected_error) { 'ACR is not valid' }

          it_behaves_like 'error response'
        end

        context 'and acr param is given and in ACR_VALUES but not valid for logingov' do
          let(:acr_value) { 'loa1' }
          let(:expected_error) { 'Invalid ACR for logingov' }

          it_behaves_like 'error response'
        end

        context 'and acr param is given and in ACR_VALUES and valid for logingov' do
          let(:acr_value) { 'ial1' }

          context 'and code_challenge_method is not given' do
            let(:code_challenge_method) { {} }
            let(:expected_error) { 'Code Challenge Method is not defined' }

            it_behaves_like 'error response'
          end

          context 'and code_challenge_method is S256' do
            let(:code_challenge_method) { { code_challenge_method: 'S256' } }

            context 'and code_challenge is not given' do
              let(:code_challenge) { {} }
              let(:expected_error) { 'Code Challenge is not defined' }

              it_behaves_like 'error response'
            end

            context 'and code_challenge is not properly URL encoded' do
              let(:code_challenge) { { code_challenge: '///some+unsafe code+challenge//' } }
              let(:expected_error) { 'Code Challenge is not valid' }
              let(:expected_error_json) { { 'errors' => expected_error } }

              it_behaves_like 'error response'
            end

            context 'and code_challenge is properly URL encoded' do
              let(:code_challenge) { { code_challenge: Base64.urlsafe_encode64('some-safe-code-challenge') } }
              let(:state) { 'some-state' }
              let(:expected_redirect_uri) { Settings.logingov.redirect_uri }
              let(:statsd_auth_success) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_SUCCESS }
              let(:expected_log) { '[SignInService] [V0::SignInController] authorize' }
              let(:expected_logger_context) do
                {
                  type: type[:type],
                  client_id: client_id_value,
                  acr: acr_value
                }
              end

              before do
                allow(JWT).to receive(:encode).and_return(state)
              end

              shared_context 'successful response' do
                it 'returns ok status' do
                  expect(subject).to have_http_status(:ok)
                end

                it 'renders expected state' do
                  expect(subject.body).to match(state)
                end

                it 'renders expected redirect_uri in template' do
                  expect(subject.body).to match(expected_redirect_uri)
                end

                it 'logs the authentication attempt' do
                  expect(Rails.logger).to receive(:info).with(expected_log, expected_logger_context)
                  subject
                end

                it 'updates StatsD with a auth request success' do
                  expect { subject }.to trigger_statsd_increment(statsd_auth_success, tags: statsd_tags)
                end
              end

              context 'and client_state is not given' do
                let(:client_state) { {} }

                it_behaves_like 'successful response'
              end

              context 'and client_state is greater than minimum client state length' do
                let(:client_state) do
                  { state: SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH + 1) }
                end

                it_behaves_like 'successful response'
              end

              context 'and client_state is less than minimum client state length' do
                let(:client_state) do
                  { state: SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH - 1) }
                end
                let(:expected_error) { 'Attributes are not valid' }

                it_behaves_like 'error response'
              end
            end
          end

          context 'and code_challenge_method is not S256' do
            let(:code_challenge_method) { { code_challenge_method: 'some-code-challenge-method' } }
            let(:expected_error) { 'Code Challenge Method is not valid' }

            it_behaves_like 'error response'
          end
        end
      end

      shared_context 'an idme authentication service interface' do
        context 'and acr param is not given' do
          let(:acr) { {} }
          let(:acr_value) { nil }
          let(:expected_error) { 'ACR is not valid' }

          it_behaves_like 'error response'
        end

        context 'and acr param is given but not in ACR_VALUES' do
          let(:acr_value) { 'some-undefiend-acr' }
          let(:expected_error) { 'ACR is not valid' }

          it_behaves_like 'error response'
        end

        context 'and acr param is given and in ACR_VALUES but not valid for type' do
          let(:acr_value) { 'ial1' }
          let(:expected_error) { "Invalid ACR for #{type_value}" }

          it_behaves_like 'error response'
        end

        context 'and acr param is given and in ACR_VALUES and valid for type' do
          let(:acr_value) { 'loa1' }

          context 'and code_challenge_method is not given' do
            let(:code_challenge_method) { {} }
            let(:expected_error) { 'Code Challenge Method is not defined' }

            it_behaves_like 'error response'
          end

          context 'and code_challenge_method is S256' do
            let(:code_challenge_method) { { code_challenge_method: 'S256' } }

            context 'and code_challenge is not given' do
              let(:code_challenge) { {} }
              let(:expected_error) { 'Code Challenge is not defined' }

              it_behaves_like 'error response'
            end

            context 'and code_challenge is not properly URL encoded' do
              let(:code_challenge) { { code_challenge: '///some+unsafe code+challenge//' } }
              let(:expected_error) { 'Code Challenge is not valid' }

              it_behaves_like 'error response'
            end

            context 'and code_challenge is properly URL encoded' do
              let(:code_challenge) { { code_challenge: Base64.urlsafe_encode64('some-safe-code-challenge') } }
              let(:state) { 'some-state' }
              let(:statsd_auth_success) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_SUCCESS }
              let(:expected_log) { '[SignInService] [V0::SignInController] authorize' }
              let(:expected_redirect_uri) { Settings.idme.redirect_uri }
              let(:expected_logger_context) do
                {
                  type: type_value,
                  acr: acr_value,
                  client_id: client_id_value
                }
              end

              before do
                allow(JWT).to receive(:encode).and_return(state)
              end

              shared_context 'successful response' do
                it 'returns ok status' do
                  expect(subject).to have_http_status(:ok)
                end

                it 'renders expected state in template' do
                  expect(subject.body).to match(state)
                end

                it 'renders expected redirect_uri in template' do
                  expect(subject.body).to match(expected_redirect_uri)
                end

                it 'logs the authentication attempt' do
                  expect(Rails.logger).to receive(:info).with(expected_log, expected_logger_context)
                  subject
                end

                it 'updates StatsD with a auth request success' do
                  expect { subject }.to trigger_statsd_increment(statsd_auth_success, tags: statsd_tags)
                end
              end

              context 'and client_state is not given' do
                let(:client_state) { {} }

                it_behaves_like 'successful response'
              end

              context 'and client_state is greater than minimum client state length' do
                let(:client_state) do
                  { state: SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH + 1) }
                end

                it_behaves_like 'successful response'
              end

              context 'and client_state is less than minimum client state length' do
                let(:client_state) do
                  { state: SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH - 1) }
                end
                let(:expected_error) { 'Attributes are not valid' }

                it_behaves_like 'error response'
              end
            end
          end

          context 'and code_challenge_method is not S256' do
            let(:code_challenge_method) { { code_challenge_method: 'some-code-challenge-method' } }
            let(:expected_error) { 'Code Challenge Method is not valid' }

            it_behaves_like 'error response'
          end
        end
      end

      context 'when type param is idme' do
        let(:type_value) { 'idme' }
        let(:expected_type_value) { 'idme' }

        it_behaves_like 'an idme authentication service interface'
      end

      context 'when type param is dslogon' do
        let(:type_value) { 'dslogon' }
        let(:expected_type_value) { 'dslogon' }

        it_behaves_like 'an idme authentication service interface'
      end

      context 'when type param is mhv' do
        let(:type_value) { 'mhv' }
        let(:expected_type_value) { 'mhv' }

        it_behaves_like 'an idme authentication service interface'
      end
    end
  end

  describe 'GET callback' do
    subject { get(:callback, params: {}.merge(code).merge(state).merge(error)) }

    let(:code) { { code: code_value } }
    let(:state) { { state: state_value } }
    let(:error) { { error: error_value } }
    let(:state_value) { 'some-state' }
    let(:code_value) { 'some-code' }
    let(:error_value) { 'some-error' }
    let(:statsd_tags) { ["type:#{type}", "client_id:#{client_id}", "ial:#{ial}"] }
    let(:type) {}
    let(:acr) { nil }
    let(:client_id) { nil }
    let(:mpi_update_profile_response) { MPI::Responses::AddPersonResponse.new(status: 'OK') }
    let(:mpi_add_person_response) do
      MPI::Responses::AddPersonResponse.new(status: 'OK', mvi_codes: { icn: add_person_icn })
    end
    let(:add_person_icn) { nil }
    let(:find_profile) do
      MPI::Responses::FindProfileResponse.new(
        status: MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
        profile: mpi_profile
      )
    end
    let(:mpi_profile) { nil }

    before do
      allow(Rails.logger).to receive(:info)
      allow_any_instance_of(MPI::Service).to receive(:update_profile).and_return(mpi_update_profile_response)
      allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(find_profile)
      allow_any_instance_of(MPI::Service).to receive(:find_profile).and_return(find_profile)
      allow_any_instance_of(MPI::Service).to receive(:add_person_implicit_search).and_return(mpi_add_person_response)
    end

    shared_examples 'api based error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:statsd_callback_failure) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] callback error' }
      let(:expected_error_message) do
        { errors: expected_error, client_id: client_id, type: type, acr: acr }
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

      context 'and client_id is a web based setting' do
        let(:client_id) { SignIn::Constants::ClientConfig::COOKIE_AUTH.first }
        let(:expected_error_status) { :redirect }
        let(:expected_redirect_params) do
          { auth: 'fail', code: error_code, request_id: request_id }.to_query
        end
        let(:expected_redirect) do
          uri = URI.parse(Settings.sign_in.client_redirect_uris.web)
          uri.query = expected_redirect_params
          uri.to_s
        end
        let(:expected_error_log) { '[SignInService] [V0::SignInController] callback error' }
        let(:expected_error_message) do
          { errors: expected_error, client_id: client_id, type: type, acr: acr }
        end

        it 'redirects to frontend failure page' do
          expect(subject).to redirect_to(expected_redirect)
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

      context 'and client_id is an api based setting' do
        let(:client_id) { SignIn::Constants::ClientConfig::API_AUTH.first }

        it_behaves_like 'api based error response'
      end
    end

    context 'when error is not given' do
      let(:error) { {} }

      context 'when code is not given' do
        let(:code) { {} }
        let(:expected_error) { 'Code is not defined' }

        it_behaves_like 'api based error response'
      end

      context 'when state is not given' do
        let(:state) { {} }
        let(:expected_error) { 'State is not defined' }

        it_behaves_like 'api based error response'
      end

      context 'when state is arbitrary' do
        let(:state_value) { 'some-state' }
        let(:expected_error) { 'State JWT is malformed' }

        it_behaves_like 'api based error response'
      end

      context 'when state is a JWT but with improper signature' do
        let(:state_value) { JWT.encode('some-state', private_key, encode_algorithm) }
        let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
        let(:encode_algorithm) { SignIn::Constants::Auth::JWT_ENCODE_ALGORITHM }
        let(:expected_error) { 'State JWT body does not match signature' }

        it_behaves_like 'api based error response'
      end

      context 'when state is a proper, expected JWT' do
        let(:state_value) do
          SignIn::StatePayloadJwtEncoder.new(code_challenge: code_challenge,
                                             code_challenge_method: code_challenge_method,
                                             acr: acr,
                                             client_id: client_id,
                                             type: type,
                                             client_state: client_state).perform
        end
        let(:code_challenge) { Base64.urlsafe_encode64('some-code-challenge') }
        let(:code_challenge_method) { SignIn::Constants::Auth::CODE_CHALLENGE_METHOD }
        let(:acr) { SignIn::Constants::Auth::ACR_VALUES.first }
        let(:client_id) { SignIn::Constants::ClientConfig::CLIENT_IDS.first }
        let(:type) { SignIn::Constants::Auth::REDIRECT_URLS.first }
        let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }

        context 'and code in state payload matches an existing state code' do
          context 'when type in state JWT is logingov' do
            let(:type) { 'logingov' }
            let(:response) { OpenStruct.new(access_token: token) }
            let(:token) { 'some-token' }
            let(:logingov_uuid) { 'some-logingov_uuid' }
            let(:user_info) do
              OpenStruct.new(
                {
                  verified_at: '1-1-2022',
                  sub: logingov_uuid,
                  social_security_number: '123456789',
                  birthdate: '1-1-2022',
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
              let(:response) { OpenStruct.new(access_token: token, id_token: id_token, expires_in: expires_in) }
              let(:id_token) { JWT.encode(id_token_payload, OpenSSL::PKey::RSA.new(2048), 'RS256') }
              let(:expires_in) { 900 }
              let(:id_token_payload) { { acr: login_gov_response_acr } }
              let(:login_gov_response_acr) { IAL::LOGIN_GOV_IAL2 }

              context 'and credential should be uplevelled' do
                let(:acr) { 'min' }
                let(:login_gov_response_acr) { IAL::LOGIN_GOV_IAL1 }
                let(:expected_redirect_uri) { Settings.logingov.redirect_uri }

                it 'returns ok status' do
                  expect(subject).to have_http_status(:ok)
                end

                it 'renders expected state' do
                  expect(subject.body).to match(state_value)
                end

                it 'renders expected redirect_uri in template' do
                  expect(subject.body).to match(expected_redirect_uri)
                end
              end

              context 'and credential should not be uplevelled' do
                let(:acr) { 'ial2' }
                let(:ial) { 2 }
                let(:client_code) { 'some-client-code' }
                let(:client_redirect_uri) { Settings.sign_in.client_redirect_uris.mobile }
                let(:expected_url) do
                  "#{client_redirect_uri}?code=#{client_code}&state=#{client_state}&type=#{type}"
                end
                let(:expected_log) { '[SignInService] [V0::SignInController] callback' }
                let(:statsd_callback_success) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS }
                let(:expected_logger_context) do
                  {
                    type: type,
                    client_id: client_id,
                    ial: ial
                  }
                end
                let(:expected_user_attributes) do
                  {
                    ssn: user_info.social_security_number,
                    birth_date: Formatters::DateFormatter.format_date(user_info.birthdate),
                    first_name: user_info.given_name,
                    last_name: user_info.family_name
                  }
                end
                let(:expected_credential_info_attributes) { { id_token: id_token, csp_uuid: logingov_uuid } }
                let(:mpi_profile) do
                  build(:mvi_profile,
                        ssn: user_info.social_security_number,
                        birth_date: Formatters::DateFormatter.format_date(user_info.birthdate),
                        given_names: [user_info.given_name],
                        family_name: user_info.family_name)
                end

                before { allow(SecureRandom).to receive(:uuid).and_return(client_code) }

                it 'returns found status' do
                  expect(subject).to have_http_status(:found)
                end

                it 'redirects to expected url' do
                  expect(subject).to redirect_to(expected_url)
                end

                it 'logs the successful callback' do
                  expect(Rails.logger).to receive(:info).with(expected_log, expected_logger_context)
                  subject
                end

                it 'updates StatsD with a callback request success' do
                  expect { subject }.to trigger_statsd_increment(statsd_callback_success, tags: statsd_tags)
                end

                it 'creates a user with expected attributes' do
                  subject

                  user_uuid = UserVerification.last.credential_identifier
                  user = User.find(user_uuid)
                  expect(user).to have_attributes(expected_user_attributes)
                end

                it 'creates a credential_info with expected attributes' do
                  subject

                  credential_info = SignIn::CredentialInfo.find(logingov_uuid)
                  expect(credential_info).to have_attributes(expected_credential_info_attributes)
                end
              end
            end
          end

          context 'when type in state JWT is idme' do
            let(:type) { 'idme' }
            let(:user_info) do
              OpenStruct.new(
                sub: 'some-sub',
                level_of_assurance: level_of_assurance,
                credential_ial: credential_ial,
                social: '123456789',
                birth_date: '1-1-2022',
                fname: 'some-name',
                lname: 'some-family-name',
                email: 'some-email'
              )
            end
            let(:expected_user_attributes) do
              {
                ssn: user_info.social,
                birth_date: Formatters::DateFormatter.format_date(user_info.birth_date),
                first_name: user_info.fname,
                last_name: user_info.lname
              }
            end
            let(:mpi_profile) do
              build(:mvi_profile,
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

                it 'returns ok status' do
                  expect(subject).to have_http_status(:ok)
                end

                it 'renders expected state' do
                  expect(subject.body).to match(state_value)
                end

                it 'renders expected redirect_uri in template' do
                  expect(subject.body).to match(expected_redirect_uri)
                end
              end

              context 'and credential should not be uplevelled' do
                let(:acr) { 'loa3' }
                let(:ial) { 2 }
                let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
                let(:client_code) { 'some-client-code' }
                let(:client_redirect_uri) { Settings.sign_in.client_redirect_uris.mobile }
                let(:expected_url) do
                  "#{client_redirect_uri}?code=#{client_code}&state=#{client_state}&type=#{type}"
                end
                let(:expected_log) { '[SignInService] [V0::SignInController] callback' }
                let(:statsd_callback_success) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS }
                let(:expected_logger_context) do
                  {
                    type: type,
                    client_id: client_id,
                    ial: ial
                  }
                end

                before do
                  allow(SecureRandom).to receive(:uuid).and_return(client_code)
                end

                it 'returns found status' do
                  expect(subject).to have_http_status(:found)
                end

                it 'redirects to expected url' do
                  expect(subject).to redirect_to(expected_url)
                end

                it 'logs the successful callback' do
                  expect(Rails.logger).to receive(:info).with(expected_log, expected_logger_context)
                  expect { subject }.to trigger_statsd_increment(statsd_callback_success, tags: statsd_tags)
                end

                it 'creates a user with expected attributes' do
                  subject

                  user_uuid = UserVerification.last.credential_identifier
                  user = User.find(user_uuid)

                  expect(user).to have_attributes(expected_user_attributes)
                end
              end
            end
          end

          context 'when type in state JWT is dslogon' do
            let(:type) { 'dslogon' }
            let(:user_info) do
              OpenStruct.new(
                sub: 'some-sub',
                level_of_assurance: level_of_assurance,
                credential_ial: credential_ial,
                dslogon_idvalue: '123456789',
                dslogon_birth_date: '1-1-2022',
                dslogon_fname: 'some-name',
                dslogon_mname: 'some-middle-name',
                dslogon_lname: 'some-family-name',
                dslogon_uuid: '987654321',
                dslogon_assurance: dslogon_assurance,
                email: 'some-email'
              )
            end
            let(:expected_user_attributes) do
              {
                ssn: user_info.dslogon_idvalue,
                birth_date: Formatters::DateFormatter.format_date(user_info.dslogon_birth_date),
                first_name: user_info.dslogon_fname,
                middle_name: user_info.dslogon_mname,
                last_name: user_info.dslogon_lname,
                edipi: user_info.dslogon_uuid
              }
            end
            let(:mpi_profile) do
              build(:mvi_profile,
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
              let(:acr) { 'loa3' }
              let(:ial) { 2 }
              let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
              let(:client_code) { 'some-client-code' }
              let(:expected_url) do
                "#{Settings.sign_in.client_redirect_uris.mobile}?code=#{client_code}&state=#{client_state}&type=#{type}"
              end
              let(:expected_log) { '[SignInService] [V0::SignInController] callback' }
              let(:statsd_callback_success) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS }
              let(:expected_logger_context) do
                {
                  type: type,
                  client_id: client_id,
                  ial: ial
                }
              end

              before do
                allow(SecureRandom).to receive(:uuid).and_return(client_code)
              end

              shared_context 'dslogon successful callback' do
                it 'returns found status' do
                  expect(subject).to have_http_status(:found)
                end

                it 'redirects to expected url' do
                  expect(subject).to redirect_to(expected_url)
                end

                it 'logs the successful callback' do
                  expect(Rails.logger).to receive(:info).with(expected_log, expected_logger_context)
                  expect { subject }.to trigger_statsd_increment(statsd_callback_success, tags: statsd_tags)
                end

                it 'creates a user with expected attributes' do
                  subject

                  user_uuid = UserVerification.last.backing_credential_identifier
                  user = User.find(user_uuid)

                  expect(user).to have_attributes(expected_user_attributes)
                end
              end

              context 'and dslogon account is not premium' do
                let(:dslogon_assurance) { 'some-dslogon-assurance' }
                let(:ial) { 1 }
                let(:expected_user_attributes) do
                  {
                    ssn: nil,
                    birth_date: nil,
                    first_name: nil,
                    middle_name: nil,
                    last_name: nil,
                    edipi: nil
                  }
                end

                it_behaves_like 'dslogon successful callback'
              end

              context 'and dslogon account is premium' do
                let(:dslogon_assurance) { LOA::DSLOGON_ASSURANCE_THREE }
                let(:ial) { 2 }
                let(:expected_user_attributes) do
                  {
                    ssn: user_info.dslogon_idvalue,
                    birth_date: Formatters::DateFormatter.format_date(user_info.dslogon_birth_date),
                    first_name: user_info.dslogon_fname,
                    middle_name: user_info.dslogon_mname,
                    last_name: user_info.dslogon_lname,
                    edipi: user_info.dslogon_uuid
                  }
                end

                it_behaves_like 'dslogon successful callback'
              end
            end
          end

          context 'when type in state JWT is mhv' do
            let(:type) { 'mhv' }
            let(:user_info) do
              OpenStruct.new(
                sub: 'some-sub',
                level_of_assurance: level_of_assurance,
                credential_ial: credential_ial,
                mhv_uuid: '123456789',
                mhv_icn: mhv_icn,
                mhv_assurance: mhv_assurance
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
              build(:mvi_profile,
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
              let(:acr) { 'loa3' }
              let(:ial) { 2 }
              let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
              let(:client_code) { 'some-client-code' }
              let(:expected_url) do
                "#{Settings.sign_in.client_redirect_uris.mobile}?code=#{client_code}&state=#{client_state}&type=#{type}"
              end
              let(:expected_log) { '[SignInService] [V0::SignInController] callback' }
              let(:statsd_callback_success) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS }
              let(:expected_logger_context) do
                {
                  type: type,
                  client_id: client_id,
                  ial: ial
                }
              end

              before do
                allow(SecureRandom).to receive(:uuid).and_return(client_code)
              end

              shared_context 'mhv successful callback' do
                it 'returns found status' do
                  expect(subject).to have_http_status(:found)
                end

                it 'redirects to expected url' do
                  expect(subject).to redirect_to(expected_url)
                end

                it 'logs the successful callback' do
                  expect(Rails.logger).to receive(:info).with(expected_log, expected_logger_context)
                  expect { subject }.to trigger_statsd_increment(statsd_callback_success, tags: statsd_tags)
                end

                it 'creates a user with expected attributes' do
                  subject

                  user_uuid = UserVerification.last.backing_credential_identifier
                  user = User.find(user_uuid)

                  expect(user).to have_attributes(expected_user_attributes)
                end
              end

              context 'and mhv account is not premium' do
                let(:mhv_assurance) { 'some-mhv-assurance' }
                let(:ial) { 1 }
                let(:expected_user_attributes) do
                  {
                    mhv_correlation_id: nil,
                    icn: nil
                  }
                end

                it_behaves_like 'mhv successful callback'
              end

              context 'and mhv account is premium' do
                let(:mhv_assurance) { 'Premium' }
                let(:ial) { 2 }
                let(:expected_user_attributes) do
                  {
                    mhv_correlation_id: user_info.mhv_uuid,
                    icn: user_info.mhv_icn
                  }
                end

                it_behaves_like 'mhv successful callback'
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
        SignIn::StatePayloadJwtEncoder.new(code_challenge: code_challenge,
                                           code_challenge_method: code_challenge_method,
                                           acr: acr,
                                           client_id: client_id,
                                           type: type,
                                           client_state: client_state).perform
      end
      let(:code_challenge) { Base64.urlsafe_encode64('some-code-challenge') }
      let(:code_challenge_method) { SignIn::Constants::Auth::CODE_CHALLENGE_METHOD }
      let(:acr) { SignIn::Constants::Auth::ACR_VALUES.first }
      let(:client_id) { SignIn::Constants::ClientConfig::CLIENT_IDS.first }
      let(:type) { SignIn::Constants::Auth::REDIRECT_URLS.first }
      let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }

      context 'and error is access denied value' do
        let(:error_value) { SignIn::Constants::Auth::ACCESS_DENIED }
        let(:expected_error) { 'User Declined to Authorize Client' }

        context 'and type from state is logingov' do
          let(:type) { SAML::User::LOGINGOV_CSID }
          let(:error_code) { SignIn::Constants::ErrorCode::LOGINGOV_VERIFICATION_DENIED }

          it_behaves_like 'error response'
        end

        context 'and type from state is some other value' do
          let(:type) { SAML::User::IDME_CSID }
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

  describe 'POST token' do
    subject { get(:token, params: {}.merge(code).merge(code_verifier).merge(grant_type)) }

    let(:user_verification) { create(:user_verification) }
    let(:user_verification_id) { user_verification.id }
    let!(:user) { create(:user, uuid: user_uuid) }
    let(:user_uuid) { user_verification.credential_identifier }
    let(:code) { { code: code_value } }
    let(:code_verifier) { { code_verifier: code_verifier_value } }
    let(:grant_type) { { grant_type: grant_type_value } }
    let(:code_value) { 'some-code' }
    let(:code_verifier_value) { 'some-code-verifier' }
    let(:grant_type_value) { 'some-grant-type' }
    let(:type) { nil }
    let(:client_id_value) { nil }
    let(:loa) { nil }

    before { allow(Rails.logger).to receive(:info) }

    shared_examples 'error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:statsd_token_failure) { SignIn::Constants::Statsd::STATSD_SIS_TOKEN_FAILURE }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] token error' }
      let(:expected_error_context) { { errors: expected_error.to_s } }

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed token request' do
        expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
        subject
      end

      it 'updates StatsD with a token request failure' do
        expect { subject }.to trigger_statsd_increment(statsd_token_failure)
      end
    end

    context 'when code param is not given' do
      let(:code) { {} }
      let(:expected_error) { 'Code is not defined' }

      it_behaves_like 'error response'
    end

    context 'when code_verifier param is not given' do
      let(:code_verifier) { {} }
      let(:expected_error) { 'Code Verifier is not defined' }

      it_behaves_like 'error response'
    end

    context 'when grant_type param is not given' do
      let(:grant_type) { {} }
      let(:expected_error) { 'Grant Type is not defined' }

      it_behaves_like 'error response'
    end

    context 'when code, code_verifier, and grant_type params are defined' do
      context 'and code does not match an existing code container' do
        let(:code) { { code: 'some-arbitrary-code' } }
        let(:expected_error) { 'Code is not valid' }

        it_behaves_like 'error response'
      end

      context 'and code param does match an existing code container' do
        let(:code) { { code: code_value } }
        let(:code_value) { 'some-code-value' }
        let!(:code_container) do
          create(:code_container,
                 code: code_value,
                 code_challenge: code_challenge,
                 client_id: client_id,
                 user_verification_id: user_verification_id)
        end
        let(:client_id) { SignIn::Constants::ClientConfig::CLIENT_IDS.first }
        let(:code_challenge) { 'some-code-challenge' }

        context 'and code_verifier does not match expected code_challenge value' do
          let(:code_verifier_value) { 'some-arbitrary-code-verifier-value' }
          let(:expected_error) { 'Code Verifier is not valid' }

          it_behaves_like 'error response'
        end

        context 'and code_verifier does match expected code_challenge value' do
          let(:code_verifier_value) { 'some-code-verifier-value' }
          let(:code_challenge) do
            hashed_code_challenge = Digest::SHA256.base64digest(code_verifier_value)
            Base64.urlsafe_encode64(Base64.urlsafe_decode64(hashed_code_challenge.to_s), padding: false)
          end

          context 'and grant_type does not match supported grant type value' do
            let(:grant_type_value) { 'some-arbitrary-grant-type-value' }
            let(:expected_error) { 'Grant Type is not valid' }

            it_behaves_like 'error response'
          end

          context 'and grant_type does match supported grant type value' do
            let(:grant_type_value) { SignIn::Constants::Auth::GRANT_TYPE }

            context 'and code_container matched with code does match a user account' do
              let(:type) { user.identity.sign_in[:service_name] }
              let(:client_id) { SignIn::Constants::ClientConfig::COOKIE_AUTH.first }
              let(:client_id_value) { client_id }
              let(:loa) { user.identity.loa[:current] }
              let(:user_verification_id) { user_verification.id }
              let(:user_verification) { create(:user_verification) }
              let(:statsd_token_success) { SignIn::Constants::Statsd::STATSD_SIS_TOKEN_SUCCESS }
              let(:expected_log) { '[SignInService] [V0::SignInController] token' }

              before { allow(Rails.logger).to receive(:info) }

              it 'creates an OAuthSession' do
                expect { subject }.to change(SignIn::OAuthSession, :count).by(1)
              end

              it 'returns ok status' do
                expect(subject).to have_http_status(:ok)
              end

              context 'and authentication is for a session with client id that is api auth' do
                let!(:user) { create(:user, :api_auth, uuid: user_uuid) }
                let(:client_id) { SignIn::Constants::ClientConfig::API_AUTH.first }

                it 'returns expected body with access token' do
                  expect(JSON.parse(subject.body)['data']).to have_key('access_token')
                end

                it 'returns expected body with refresh token' do
                  expect(JSON.parse(subject.body)['data']).to have_key('refresh_token')
                end

                it 'logs the successful token request' do
                  access_token = JWT.decode(JSON.parse(subject.body)['data']['access_token'], nil, false).first
                  logger_context = {
                    user_uuid: user_uuid,
                    session_id: access_token['session_handle'],
                    token_uuid: access_token['jti']
                  }
                  expect(Rails.logger).to have_received(:info).with(expected_log, logger_context)
                end

                it 'updates StatsD with a token request success' do
                  expect { subject }.to trigger_statsd_increment(statsd_token_success)
                end
              end

              context 'and authentication is for a session with client id that is cookie auth' do
                let(:access_token_cookie_name) { SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME }
                let(:refresh_token_cookie_name) { SignIn::Constants::Auth::REFRESH_TOKEN_COOKIE_NAME }

                it 'returns empty hash for body' do
                  expect(JSON.parse(subject.body)).to eq({})
                end

                it 'sets access token cookie' do
                  expect(subject.cookies).to have_key(access_token_cookie_name)
                end

                it 'sets refresh token cookie' do
                  expect(subject.cookies).to have_key(refresh_token_cookie_name)
                end

                context 'and session has client id that is anti csrf enabled' do
                  let(:anti_csrf_token_cookie_name) { SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME }

                  it 'returns expected body with refresh token' do
                    expect(subject.cookies).to have_key(anti_csrf_token_cookie_name)
                  end
                end

                it 'logs the successful token request' do
                  access_token_cookie = subject.cookies[access_token_cookie_name]
                  access_token = JWT.decode(access_token_cookie, nil, false).first
                  logger_context = {
                    user_uuid: user_uuid,
                    session_id: access_token['session_handle'],
                    token_uuid: access_token['jti']
                  }
                  expect(Rails.logger).to have_received(:info).with(expected_log, logger_context)
                end

                it 'updates StatsD with a token request success' do
                  expect { subject }.to trigger_statsd_increment(statsd_token_success)
                end
              end
            end
          end
        end
      end
    end
  end

  describe 'POST refresh' do
    subject { post(:refresh, params: {}.merge(refresh_token_param).merge(anti_csrf_token_param)) }

    let!(:user) { create(:user, uuid: user_uuid) }
    let(:user_uuid) { user_verification.credential_identifier }
    let(:type) { nil }
    let(:client_id_value) { nil }
    let(:loa) { nil }
    let(:refresh_token_param) { { refresh_token: refresh_token } }
    let(:anti_csrf_token_param) { { anti_csrf_token: anti_csrf_token } }
    let(:refresh_token) { 'some-refresh-token' }
    let(:anti_csrf_token) { 'some-anti-csrf-token' }
    let(:user_verification) { create(:user_verification) }
    let(:user_account) { user_verification.user_account }
    let(:validated_credential) do
      create(:validated_credential, user_verification: user_verification, client_id: client_id)
    end
    let(:client_id) { SignIn::Constants::ClientConfig::CLIENT_IDS.first }

    before { allow(Rails.logger).to receive(:info) }

    shared_examples 'error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:statsd_refresh_error) { SignIn::Constants::Statsd::STATSD_SIS_REFRESH_FAILURE }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] refresh error' }
      let(:expected_error_context) { { errors: expected_error.to_s } }

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed refresh attempt' do
        expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
        subject
      end

      it 'updates StatsD with a refresh request failure' do
        expect { subject }.to trigger_statsd_increment(statsd_refresh_error)
      end
    end

    context 'when session has been created with a client id that is anti csrf enabled' do
      let(:client_id) { SignIn::Constants::ClientConfig::ANTI_CSRF_ENABLED.first }
      let(:session_container) { SignIn::SessionCreator.new(validated_credential: validated_credential).perform }
      let(:refresh_token) do
        SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
      end
      let(:expected_error) { 'Anti CSRF token is not valid' }
      let(:expected_error_status) { :unauthorized }

      context 'and anti_csrf_token param is not given' do
        let(:anti_csrf_token_param) { {} }
        let(:anti_csrf_token) { nil }

        it_behaves_like 'error response'
      end

      context 'and anti_csrf_token has been modified' do
        let(:expected_error) { 'Anti CSRF token is not valid' }
        let(:anti_csrf_token) { 'some-modified-anti-csrf-token' }

        it_behaves_like 'error response'
      end
    end

    context 'when refresh_token is an arbitrary string' do
      let(:refresh_token) { 'some-refresh-token' }
      let(:expected_error) { 'Refresh token cannot be decrypted' }
      let(:expected_error_status) { :unauthorized }

      it_behaves_like 'error response'
    end

    context 'when refresh_token is the proper encrypted refresh token format' do
      let(:session_container) { SignIn::SessionCreator.new(validated_credential: validated_credential).perform }
      let(:refresh_token) do
        SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
      end
      let(:anti_csrf_token) { session_container.anti_csrf_token }
      let(:expected_session_handle) { session_container.session.handle }
      let(:expected_log_message) { '[SignInService] [V0::SignInController] refresh' }
      let(:statsd_refresh_success) { SignIn::Constants::Statsd::STATSD_SIS_REFRESH_SUCCESS }
      let(:expected_log_attributes) do
        {
          token_type: 'Refresh',
          user_id: user_uuid,
          session_id: expected_session_handle
        }
      end

      context 'and encrypted component has been modified' do
        let(:refresh_token) do
          token = SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
          split_token = token.split('.')
          split_token[0] = 'some-modified-encrypted-component'
          split_token.join
        end
        let(:expected_error) { 'Refresh token cannot be decrypted' }
        let(:expected_error_status) { :unauthorized }

        it_behaves_like 'error response'
      end

      context 'and nonce component has been modified' do
        let(:refresh_token) do
          token = SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
          split_token = token.split('.')
          split_token[1] = 'some-modified-nonce-component'
          split_token.join('.')
        end
        let(:expected_error) { 'Refresh nonce is invalid' }
        let(:expected_error_status) { :unauthorized }

        it_behaves_like 'error response'
      end

      context 'and version has been modified' do
        let(:refresh_token) do
          token = SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
          split_token = token.split('.')
          split_token[2] = 'some-modified-version-component'
          split_token.join('.')
        end
        let(:expected_error) { 'Refresh token version is invalid' }
        let(:expected_error_status) { :unauthorized }

        it_behaves_like 'error response'
      end

      context 'and refresh token is expired' do
        let(:expected_error) { 'No valid Session found' }
        let(:expected_error_status) { :unauthorized }

        before do
          session = session_container.session
          session.refresh_expiration = 1.day.ago
          session.save!
        end

        it_behaves_like 'error response'
      end

      context 'and refresh token does not map to an existing session' do
        let(:expected_error) { 'No valid Session found' }
        let(:expected_error_status) { :unauthorized }

        before do
          session = session_container.session
          session.destroy!
        end

        it_behaves_like 'error response'
      end

      context 'and refresh token is not a parent or child according to the session' do
        let(:expected_error) { 'Token theft detected' }
        let(:expected_error_status) { :unauthorized }

        before do
          session = session_container.session
          session.hashed_refresh_token = 'some-unrelated-refresh-token'
          session.save!
        end

        it 'destroys the existing session' do
          expect { subject }.to change(SignIn::OAuthSession, :count).from(1).to(0)
        end

        it_behaves_like 'error response'
      end

      context 'and refresh token is unmodified and valid' do
        let(:type) { user.identity.sign_in[:service_name] }
        let(:client_id_value) { user.identity.sign_in[:client_id] }
        let(:loa) { user.identity.loa[:current] }

        before { allow(Rails.logger).to receive(:info) }

        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
        end

        context 'and refresh token is for a session with client id that is api auth' do
          let(:client_id) { SignIn::Constants::ClientConfig::API_AUTH.first }
          let!(:user) { create(:user, :api_auth, uuid: user_uuid) }

          it 'returns expected body with access token' do
            expect(JSON.parse(subject.body)['data']).to have_key('access_token')
          end

          it 'returns expected body with refresh token' do
            expect(JSON.parse(subject.body)['data']).to have_key('refresh_token')
          end

          it 'logs the successful refresh request' do
            access_token = JWT.decode(JSON.parse(subject.body)['data']['access_token'], nil, false).first
            logger_context = {
              user_uuid: user_uuid,
              session_id: access_token['session_handle'],
              token_uuid: access_token['jti']
            }
            expect(Rails.logger).to have_received(:info).with(expected_log_message, logger_context)
          end

          it 'updates StatsD with a refresh request success' do
            expect { subject }.to trigger_statsd_increment(statsd_refresh_success)
          end
        end

        context 'and refresh token is for a session with client id that is cookie auth' do
          let(:client_id) { SignIn::Constants::ClientConfig::COOKIE_AUTH.first }
          let(:access_token_cookie_name) { SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME }
          let(:refresh_token_cookie_name) { SignIn::Constants::Auth::REFRESH_TOKEN_COOKIE_NAME }

          it 'returns empty hash for body' do
            expect(JSON.parse(subject.body)).to eq({})
          end

          it 'sets access token cookie' do
            expect(subject.cookies).to have_key(access_token_cookie_name)
          end

          it 'sets refresh token cookie' do
            expect(subject.cookies).to have_key(refresh_token_cookie_name)
          end

          context 'and session has client id that is anti csrf enabled' do
            let(:anti_csrf_token_cookie_name) { SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME }

            it 'returns expected body with refresh token' do
              expect(subject.cookies).to have_key(anti_csrf_token_cookie_name)
            end
          end

          it 'logs the successful refresh request' do
            access_token_cookie = subject.cookies[access_token_cookie_name]
            access_token = JWT.decode(access_token_cookie, nil, false).first
            logger_context = {
              user_uuid: user_uuid,
              session_id: access_token['session_handle'],
              token_uuid: access_token['jti']
            }
            expect(Rails.logger).to have_received(:info).with(expected_log_message, logger_context)
          end

          it 'updates StatsD with a refresh request success' do
            expect { subject }.to trigger_statsd_increment(statsd_refresh_success)
          end
        end
      end
    end

    context 'when refresh_token param is not given' do
      let(:expected_error) { 'Refresh token is not defined' }
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:refresh_token_param) { {} }
      let(:refresh_token) { nil }
      let(:expected_error_status) { :bad_request }

      it_behaves_like 'error response'
    end
  end

  describe 'POST revoke' do
    subject { post(:revoke, params: {}.merge(refresh_token_param).merge(anti_csrf_token_param)) }

    let!(:user) { create(:user, uuid: user_uuid) }
    let(:user_uuid) { user_verification.credential_identifier }
    let(:type) { nil }
    let(:client_id_value) { nil }
    let(:loa) { nil }
    let(:refresh_token_param) { { refresh_token: refresh_token } }
    let(:refresh_token) { 'example-refresh-token' }
    let(:anti_csrf_token_param) { { anti_csrf_token: anti_csrf_token } }
    let(:anti_csrf_token) { 'example-anti-csrf-token' }
    let(:enable_anti_csrf) { false }
    let(:user_verification) { create(:user_verification) }
    let(:user_account) { user_verification.user_account }
    let(:validated_credential) do
      create(:validated_credential, user_verification: user_verification, client_id: client_id)
    end
    let(:client_id) { SignIn::Constants::ClientConfig::CLIENT_IDS.first }

    shared_examples 'error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:statsd_revoke_failure) { SignIn::Constants::Statsd::STATSD_SIS_REVOKE_FAILURE }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] revoke error' }
      let(:expected_error_context) { { errors: expected_error.to_s } }

      before { allow(Rails.logger).to receive(:info) }

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed revocation attempt' do
        expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
        subject
      end

      it 'updates StatsD with a revoke request failure' do
        expect { subject }.to trigger_statsd_increment(statsd_revoke_failure)
      end
    end

    context 'when session has been created with a client id that is anti csrf enabled' do
      let(:type) { user.identity.sign_in[:service_name] }
      let(:client_id_value) { user.identity.sign_in[:client_id] }
      let(:loa) { user.identity.loa[:current] }
      let(:client_id) { SignIn::Constants::ClientConfig::ANTI_CSRF_ENABLED.first }
      let(:session_container) { SignIn::SessionCreator.new(validated_credential: validated_credential).perform }
      let(:refresh_token) do
        SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
      end
      let(:expected_error) { 'Anti CSRF token is not valid' }
      let(:expected_error_status) { :unauthorized }

      context 'and anti_csrf_token param is not given' do
        let(:anti_csrf_token_param) { {} }
        let(:anti_csrf_token) { nil }

        it_behaves_like 'error response'
      end

      context 'and anti_csrf_token has been modified' do
        let(:expected_error) { 'Anti CSRF token is not valid' }
        let(:anti_csrf_token) { 'some-modified-anti-csrf-token' }

        it_behaves_like 'error response'
      end
    end

    context 'when refresh_token is a random string' do
      let(:expected_error) { 'Refresh token cannot be decrypted' }
      let(:expected_error_status) { :unauthorized }

      it_behaves_like 'error response'
    end

    context 'when refresh_token is encrypted correctly' do
      let(:type) { user.identity.sign_in[:service_name] }
      let(:client_id_value) { user.identity.sign_in[:client_id] }
      let(:loa) { user.identity.loa[:current] }
      let(:session_container) { SignIn::SessionCreator.new(validated_credential: validated_credential).perform }
      let(:refresh_token) do
        SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
      end
      let(:expected_log_message) { '[SignInService] [V0::SignInController] revoke' }
      let(:statsd_revoke_success) { SignIn::Constants::Statsd::STATSD_SIS_REVOKE_SUCCESS }
      let(:expected_log_attributes) do
        {
          session_id: expected_session_handle,
          token_uuid: session_container.refresh_token.uuid,
          user_uuid: user_uuid
        }
      end

      context 'when refresh token is expired' do
        let(:expected_error) { 'No valid Session found' }
        let(:expected_error_status) { :unauthorized }

        before do
          session = session_container.session
          session.refresh_expiration = 1.day.ago
          session.save!
        end

        it_behaves_like 'error response'
      end

      context 'when refresh token does not map to an existing session' do
        let(:expected_error) { 'No valid Session found' }
        let(:expected_error_status) { :unauthorized }

        before do
          session = session_container.session
          session.destroy!
        end

        it_behaves_like 'error response'
      end

      context 'when refresh token is unmodified and valid' do
        let(:expected_session_handle) { session_container.session.handle }

        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
        end

        it 'destroys user session' do
          subject
          expect { session_container.session.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end

        it 'logs the session revocation' do
          expect(Rails.logger).to receive(:info).with(expected_log_message, expected_log_attributes)
          subject
        end

        it 'updates StatsD with a revoke request success' do
          expect { subject }.to trigger_statsd_increment(statsd_revoke_success)
        end
      end
    end
  end

  describe 'GET introspect' do
    subject { get(:introspect) }

    context 'when successfully authenticated' do
      let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
      let(:authorization) { "Bearer #{access_token}" }
      let(:access_token_object) { create(:access_token) }
      let(:statsd_success) { SignIn::Constants::Statsd::STATSD_SIS_INTROSPECT_SUCCESS }
      let!(:user) { create(:user, :loa3, uuid: access_token_object.user_uuid) }
      let(:user_serializer) { SignIn::IntrospectSerializer.new(user) }
      let(:type) { user.identity.sign_in[:service_name] }
      let(:client_id_value) { user.identity.sign_in[:client_id] }
      let(:loa) { user.identity.loa[:current] }
      let(:expected_introspect_response) { JSON.parse(user_serializer.to_json) }
      let(:expected_log) { '[SignInService] [V0::SignInController] introspect' }
      let(:expected_log_params) do
        {
          user_uuid: user.uuid,
          type: type,
          client_id: client_id_value,
          loa: loa,
          session_id: access_token_object.session_handle,
          token_uuid: access_token_object.uuid
        }
      end
      let(:expected_status) { :ok }

      before do
        request.headers['Authorization'] = authorization
        allow(Rails.logger).to receive(:info)
      end

      it 'renders expected user data' do
        expect(JSON.parse(subject.body)['data']['attributes']).to eq(expected_introspect_response)
      end

      it 'returns ok status' do
        expect(subject).to have_http_status(:ok)
      end

      context 'and some arbitrary Sign In Error is raised' do
        let(:expected_error) { SignIn::Errors::StandardError }
        let(:rendered_error) { { errors: expected_error.to_s } }

        before do
          allow(SignIn::IntrospectSerializer).to receive(:new).and_raise(expected_error, message: expected_error)
        end

        it 'renders error' do
          expect(JSON.parse(subject.body)).to eq(rendered_error.as_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end
    end
  end

  describe 'GET logout' do
    subject { get(:logout) }

    let(:web_logout_redirect_uri) { Settings.sign_in.client_redirect_uris.web_logout }

    shared_context 'error response' do
      let(:statsd_failure) { SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_FAILURE }
      let(:expected_error_status) { :redirect }
      let(:expected_error_log) { '[SignInService] [V0::SignInController] logout error' }
      let(:expected_error_context) { { errors: expected_error_message } }

      before do
        allow(Rails.logger).to receive(:info)
      end

      it 'redirects to web_logout redirect url' do
        expect(subject).to redirect_to(web_logout_redirect_uri)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'triggers statsd increment for failed call' do
        expect { subject }.to trigger_statsd_increment(statsd_failure)
      end

      it 'logs the error message' do
        expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
        subject
      end
    end

    context 'when successfully authenticated' do
      let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
      let(:authorization) { "Bearer #{access_token}" }
      let(:oauth_session) { create(:oauth_session) }
      let(:access_token_object) do
        create(:access_token, session_handle: oauth_session.handle)
      end
      let!(:user) { create(:user, :loa3, uuid: access_token_object.user_uuid, logingov_uuid: logingov_uuid) }
      let(:statsd_success) { SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_SUCCESS }
      let(:logingov_uuid) { 'some-logingov-uuid' }
      let(:expected_log) { '[SignInService] [V0::SignInController] logout' }
      let(:type) { user.identity.sign_in[:service_name] }
      let(:client_id_value) { user.identity.sign_in[:client_id] }
      let(:loa) { user.identity.loa[:current] }
      let(:expected_log_params) do
        {
          user_uuid: access_token_object.user_uuid,
          session_id: access_token_object.session_handle,
          token_uuid: access_token_object.uuid
        }
      end
      let(:logingov_id_token) { 'some-logingov-id-token' }
      let(:expected_status) { :redirect }

      before do
        request.headers['Authorization'] = authorization
        allow(Rails.logger).to receive(:info)
      end

      it 'deletes the OAuthSession object matching the session_handle in the access token' do
        expect { subject }.to change {
          SignIn::OAuthSession.find_by(handle: access_token_object.session_handle)
        }.from(oauth_session).to(nil)
      end

      it 'logs the logout call' do
        expect(Rails.logger).to receive(:info).with(expected_log, expected_log_params)
        subject
      end

      it 'triggers statsd increment for successful call' do
        expect { subject }.to trigger_statsd_increment(statsd_success)
      end

      context 'and credential info was found with id token' do
        let!(:credential_info) do
          SignIn::CredentialInfo.new(csp_uuid: logingov_uuid,
                                     id_token: logingov_id_token,
                                     credential_type: credential_type).save!
        end
        let(:state) { 'some-state' }
        let(:credential_type) { 'logingov' }
        let(:logout_redirect_uri) { Settings.logingov.logout_redirect_uri }
        let(:expected_url_params) do
          {
            id_token_hint: logingov_id_token,
            post_logout_redirect_uri: logout_redirect_uri,
            state: state
          }
        end
        let(:expected_url_host) { Settings.logingov.oauth_url }
        let(:expected_url_path) { 'openid_connect/logout' }
        let(:expected_url) { "#{expected_url_host}/#{expected_url_path}?#{expected_url_params.to_query}" }

        before { allow(SecureRandom).to receive(:hex).and_return(state) }

        it 'redirects to login gov single sign out URL' do
          expect(subject).to redirect_to(expected_url)
        end
      end

      context 'and credential info was not found with id token' do
        it 'returns redirect status' do
          expect(subject).to have_http_status(expected_status)
        end

        it 'redirects to web_logout redirect url' do
          expect(subject).to redirect_to(web_logout_redirect_uri)
        end
      end

      context 'and some arbitrary Sign In Error is raised' do
        let(:expected_error) { SignIn::Errors::StandardError }
        let(:expected_error_message) { expected_error.to_s }

        before do
          allow(SignIn::SessionRevoker).to receive(:new).and_raise(expected_error, message: expected_error)
        end

        it_behaves_like 'error response'
      end
    end

    context 'when not successfully authenticated' do
      let(:expected_error) { SignIn::Errors::LogoutAuthorizationError }
      let(:expected_error_message) { 'Unable to Authorize User' }

      it_behaves_like 'error response'
    end
  end

  describe 'GET revoke_all_sessions' do
    subject { get(:revoke_all_sessions) }

    context 'when successfully authenticated' do
      let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
      let(:authorization) { "Bearer #{access_token}" }
      let!(:user_account) { Login::UserVerifier.new(user.identity).perform.user_account }
      let(:user) { create(:user, :loa3, :api_auth) }
      let(:user_uuid) { user.uuid }
      let(:type) { user.identity.sign_in[:service_name] }
      let(:client_id_value) { user.identity.sign_in[:client_id] }
      let(:loa) { user.identity.loa[:current] }
      let(:oauth_session) { create(:oauth_session, user_account: user_account) }
      let(:access_token_object) do
        create(:access_token, session_handle: oauth_session.handle, user_uuid: user_uuid)
      end
      let(:oauth_session_count) { SignIn::OAuthSession.where(user_account: user_account).count }
      let(:statsd_success) { SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_SUCCESS }
      let(:expected_log) { '[SignInService] [V0::SignInController] revoke all sessions' }
      let(:expected_log_params) do
        {
          user_uuid: user_uuid,
          session_id: access_token_object.session_handle,
          token_uuid: access_token_object.uuid
        }
      end
      let(:expected_status) { :ok }

      before do
        request.headers['Authorization'] = authorization
      end

      it 'deletes all OAuthSession objects associated with current user user_account' do
        expect { subject }.to change(SignIn::OAuthSession, :count).from(oauth_session_count).to(0)
      end

      it 'returns ok status' do
        expect(subject).to have_http_status(expected_status)
      end

      it 'logs the revoke all sessions call' do
        expect(Rails.logger).to receive(:info).with(expected_log, expected_log_params)
        subject
      end

      it 'triggers statsd increment for successful call' do
        expect { subject }.to trigger_statsd_increment(statsd_success)
      end

      context 'and some arbitrary Sign In Error is raised' do
        let(:expected_error) { SignIn::Errors::StandardError }
        let(:statsd_failure) { SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_FAILURE }
        let(:expected_error_json) { { 'errors' => expected_error.to_s } }
        let(:expected_error_status) { :unauthorized }
        let(:expected_error_log) { '[SignInService] [V0::SignInController] revoke all sessions error' }
        let(:expected_error_context) { { errors: expected_error.to_s } }

        before do
          allow(SignIn::RevokeSessionsForUser).to receive(:new).and_raise(expected_error, message: expected_error)
          allow(Rails.logger).to receive(:info)
        end

        it 'renders expected error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns expected status' do
          expect(subject).to have_http_status(expected_error_status)
        end

        it 'logs the failed revoke all sessions call' do
          expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
          subject
        end

        it 'triggers statsd increment for failed call' do
          expect { subject }.to trigger_statsd_increment(statsd_failure)
        end
      end
    end
  end
end
