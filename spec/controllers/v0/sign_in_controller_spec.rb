# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  describe 'GET authorize' do
    subject do
      get(:authorize, params: authorize_params)
    end

    let(:authorize_params) do
      {}.merge(type).merge(code_challenge).merge(code_challenge_method).merge(client_state).merge(client_id)
    end
    let(:code_challenge) { { code_challenge: 'some-code-challenge' } }
    let(:code_challenge_method) { { code_challenge_method: 'some-code-challenge-method' } }
    let(:client_id) { { client_id: client_id_value } }
    let(:client_id_value) { 'some-client-id' }
    let(:client_state) { {} }
    let(:client_state_minimum_length) { SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH }
    let(:type) { { type: type_value } }
    let(:type_value) { 'some-type' }
    let(:error_context) do
      {
        type: type[:type],
        client_state: client_state[:state],
        code_challenge: code_challenge[:code_challenge],
        code_challenge_method: code_challenge_method[:code_challenge_method],
        client_id: client_id_value
      }
    end
    let(:statsd_tags) { ["context:#{type[:type]}"] }

    shared_examples 'error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:statsd_auth_failure) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_ATTEMPT_FAILURE }

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed authorize attempt' do
        expect(Rails.logger).to receive(:error).with("#{expected_error} : #{error_context}")
        subject
      end

      it 'updates StatsD with a auth request failure' do
        expect { subject }.to trigger_statsd_increment(statsd_auth_failure, tags: statsd_tags)
      end
    end

    context 'when client_id is not given' do
      let(:client_id) { {} }
      let(:client_id_value) { nil }
      let(:expected_error) { 'Client id is not valid' }

      it_behaves_like 'error response'
    end

    context 'when client_id is an arbitrary value' do
      let(:client_id_value) { 'some-client-id' }
      let(:expected_error) { 'Client id is not valid' }

      it_behaves_like 'error response'
    end

    context 'when client_id is in CLIENT_IDS' do
      let(:client_id_value) { SignIn::Constants::ClientConfig::CLIENT_IDS.first }

      context 'when type param is not given' do
        let(:type) { {} }
        let(:expected_error) { ActionController::UrlGenerationError }

        it 'renders no route matches error' do
          expect { subject }.to raise_error(expected_error)
        end
      end

      context 'when type param is given but not in REDIRECT_URLS' do
        let(:type) { { type: 'some-undefined-type' } }
        let(:expected_error) { 'Authorization type is not valid' }

        it_behaves_like 'error response'
      end

      context 'when type param is logingov' do
        let(:type_value) { 'logingov' }

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
            let(:state) { 'some-random-state' }
            let(:expected_redirect_uri) { Settings.logingov.redirect_uri }
            let(:statsd_auth_success) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_ATTEMPT_SUCCESS }
            let(:expected_log) { '[SignInService] [V0::SignInController] authorize' }
            let(:expected_logger_context) do
              {
                state: state,
                type: type[:type],
                client_id: client_id_value,
                client_state: client_state[:state],
                code_challenge: code_challenge[:code_challenge],
                code_challenge_method: code_challenge_method[:code_challenge_method]
              }
            end

            before do
              allow(SecureRandom).to receive(:hex).and_return(state)
            end

            shared_context 'successful response' do
              it 'returns ok status' do
                expect(subject).to have_http_status(:ok)
              end

              it 'renders expected state in template' do
                expect(subject.body).to match(state)
              end

              it 'renders expected type in template' do
                expect(subject.body).to match(type_value)
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
              let(:expected_error) { 'Code Challenge or State or Client id is not valid' }

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

      shared_context 'an idme authentication service interface' do
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
            let(:state) { 'some-random-state' }
            let(:statsd_auth_success) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_ATTEMPT_SUCCESS }
            let(:expected_log) { '[SignInService] [V0::SignInController] authorize' }
            let(:expected_logger_context) do
              {
                state: state,
                type: type[:type],
                client_state: client_state[:state],
                code_challenge: code_challenge[:code_challenge],
                code_challenge_method: code_challenge_method[:code_challenge_method],
                client_id: client_id_value
              }
            end

            before do
              allow(SecureRandom).to receive(:hex).and_return(state)
            end

            shared_context 'successful response' do
              it 'returns ok status' do
                expect(subject).to have_http_status(:ok)
              end

              it 'renders expected state in template' do
                expect(subject.body).to match(state)
              end

              it 'renders expected type in template' do
                expect(subject.body).to match(expected_type_value)
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
              let(:expected_error) { 'Code Challenge or State or Client id is not valid' }

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

      context 'when type param is idme' do
        let(:type_value) { 'idme' }
        let(:expected_type_value) { 'idme' }
        let(:expected_redirect_uri) { Settings.idme.redirect_uri }

        it_behaves_like 'an idme authentication service interface'
      end

      context 'when type param is dslogon' do
        let(:type_value) { 'dslogon' }
        let(:expected_type_value) { 'dslogon' }
        let(:expected_redirect_uri) { Settings.idme.dslogon_redirect_uri }

        it_behaves_like 'an idme authentication service interface'
      end

      context 'when type param is mhv' do
        let(:type_value) { 'mhv' }
        let(:expected_type_value) { 'myhealthevet' }
        let(:expected_redirect_uri) { Settings.idme.mhv_redirect_uri }

        it_behaves_like 'an idme authentication service interface'
      end
    end
  end

  describe 'GET callback' do
    subject { get(:callback, params: {}.merge(type).merge(code).merge(state)) }

    let(:code) { { code: code_value } }
    let(:state) { { state: 'some-state' } }
    let(:type) { { type: type_value } }
    let(:type_value) { 'some-type-value' }
    let(:code_value) { 'some-code' }
    let(:statsd_context) { ["context:#{type[:type]}"] }

    before { allow(Rails.logger).to receive(:info) }

    context 'when type param is not given' do
      let(:type) { {} }
      let(:expected_error) { ActionController::UrlGenerationError }

      it 'renders no route matches error' do
        expect { subject }.to raise_error(expected_error)
      end
    end

    shared_examples 'error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:error_context) { { type: type[:type], state: state[:state], code: code[:code] } }
      let(:statsd_tags) { ["context:#{type[:type]}"] }
      let(:statsd_callback_failure) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE }

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed callback' do
        expect(Rails.logger).to receive(:error).with("#{expected_error} : #{error_context}")
        subject
      end

      it 'updates StatsD with a callback request failure' do
        expect { subject }.to trigger_statsd_increment(statsd_callback_failure, tags: statsd_tags)
      end
    end

    context 'when type param is given but not in REDIRECT_URLS' do
      let(:type) { { type: 'some-undefined-type' } }
      let(:expected_error) { 'Callback type is not valid' }

      it_behaves_like 'error response'
    end

    context 'when type param is logingov' do
      let(:type_value) { 'logingov' }
      let(:response) { OpenStruct.new(access_token: token) }
      let(:token) { 'some-token' }
      let(:user_info) do
        OpenStruct.new(
          {
            verified_at: '1-1-2022',
            sub: 'some-sub',
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

      context 'and code is not given' do
        let(:code) { {} }
        let(:expected_error) { 'Code is not defined' }

        it_behaves_like 'error response'
      end

      context 'and code is given but does not match expected code for auth service' do
        let(:response) { nil }
        let(:expected_error) { 'Authentication Code is not valid' }

        it_behaves_like 'error response'
      end

      context 'and code is given that matches expected code for auth service' do
        context 'and state is not given' do
          let(:state) { {} }
          let(:expected_error) { 'State is not defined' }

          it_behaves_like 'error response'
        end

        context 'and state is given but does not match expected state' do
          let(:state) { { state: 'some-state' } }
          let(:expected_error) { 'Authentication Attempt Cannot be found' }

          it_behaves_like 'error response'
        end

        context 'and state is given and matches expected state' do
          let(:code_challenge_state_map) do
            create(:code_challenge_state_map, client_state: client_state, client_id: client_id)
          end
          let(:state) { { state: code_challenge_state_map.state } }
          let(:client_code) { 'some-client-code' }
          let(:client_id) { SignIn::Constants::ClientConfig::CLIENT_IDS.first }
          let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }
          let(:expected_url) do
            "#{Settings.sign_in.redirect_uri}?code=#{client_code}&state=#{client_state}&type=#{type_value}"
          end
          let(:expected_log) { '[SignInService] [V0::SignInController] callback' }
          let(:statsd_callback_success) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS }
          let(:expected_logger_context) do
            {
              state: state[:state],
              type: type[:type],
              code: code[:code],
              login_code: client_code,
              client_id: client_id,
              client_state: client_state
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
            subject
          end

          it 'updates StatsD with a callback request success' do
            expect { subject }.to trigger_statsd_increment(statsd_callback_success, tags: statsd_context)
          end

          it 'creates a user with expected attributes' do
            subject

            user_account = UserAccount.last.id
            user = User.find(user_account)
            expect(user).to have_attributes(expected_user_attributes)
          end
        end
      end
    end

    shared_context 'an idme authentication service' do
      let(:response) { OpenStruct.new(access_token: token) }
      let(:token) { 'some-token' }

      before do
        allow_any_instance_of(SignIn::Idme::Service).to receive(:token).with(code_value).and_return(response)
        allow_any_instance_of(SignIn::Idme::Service).to receive(:user_info).with(token).and_return(user_info)
      end

      context 'and code is not given' do
        let(:code) { {} }
        let(:expected_error) { 'Code is not defined' }

        it_behaves_like 'error response'
      end

      context 'and code is given but does not match expected code for auth service' do
        let(:response) { nil }
        let(:expected_error) { 'Authentication Code is not valid' }

        it_behaves_like 'error response'
      end

      context 'and code is given that matches expected code for auth service' do
        context 'and state is not given' do
          let(:state) { {} }
          let(:expected_error) { 'State is not defined' }

          it_behaves_like 'error response'
        end

        context 'and state is given but does not match expected state' do
          let(:state) { { state: 'some-state' } }
          let(:expected_error) { 'Authentication Attempt Cannot be found' }

          it_behaves_like 'error response'
        end

        context 'and state is given and matches expected state' do
          let(:state) { { state: code_challenge_state_map.state } }
          let(:client_code) { 'some-client-code' }
          let(:code_challenge_state_map) do
            create(:code_challenge_state_map, client_state: client_state, client_id: client_id)
          end
          let(:client_id) { SignIn::Constants::ClientConfig::CLIENT_IDS.first }
          let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }
          let(:expected_url) do
            "#{Settings.sign_in.redirect_uri}?code=#{client_code}&state=#{client_state}&type=#{type_value}"
          end
          let(:expected_log) { '[SignInService] [V0::SignInController] callback' }
          let(:statsd_callback_success) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS }
          let(:expected_logger_context) do
            {
              state: state[:state],
              type: type[:type],
              code: code[:code],
              login_code: client_code,
              client_id: client_id,
              client_state: client_state
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
            expect { subject }.to trigger_statsd_increment(statsd_callback_success, tags: statsd_context)
          end

          it 'creates a user with expected attributes' do
            subject

            user_account = UserAccount.last.id
            user = User.find(user_account)
            expect(user).to have_attributes(expected_user_attributes)
          end
        end
      end
    end

    context 'when type param is idme' do
      let(:type_value) { 'idme' }
      let(:user_info) do
        OpenStruct.new(
          sub: 'some-sub',
          level_of_assurance: 3,
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

      it_behaves_like 'an idme authentication service'
    end

    context 'when type param is dslogon' do
      let(:type_value) { 'dslogon' }
      let(:user_info) do
        OpenStruct.new(
          sub: 'some-sub',
          level_of_assurance: 3,
          dslogon_idvalue: '123456789',
          dslogon_birth_date: '1-1-2022',
          dslogon_fname: 'some-name',
          dslogon_mname: 'some-middle-name',
          dslogon_lname: 'some-family-name',
          dslogon_uuid: '987654321',
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

      it_behaves_like 'an idme authentication service'
    end

    context 'when type param is mhv' do
      let(:type_value) { 'mhv' }
      let(:user_info) do
        OpenStruct.new(
          sub: 'some-sub',
          level_of_assurance: 3,
          mhv_uuid: '123456789',
          mhv_icn: '987654321V123456'
        )
      end
      let(:expected_user_attributes) do
        {
          mhv_correlation_id: user_info.mhv_uuid,
          mhv_icn: user_info.mhv_icn
        }
      end

      it_behaves_like 'an idme authentication service'
    end
  end

  describe 'POST token' do
    subject { get(:token, params: {}.merge(code).merge(code_verifier).merge(grant_type)) }

    let(:user_verification) { create(:user_verification) }
    let(:user_verification_id) { user_verification.id }
    let(:code) { { code: code_value } }
    let(:code_verifier) { { code_verifier: code_verifier_value } }
    let(:grant_type) { { grant_type: grant_type_value } }
    let(:code_value) { 'some-code' }
    let(:code_verifier_value) { 'some-code-verifier' }
    let(:grant_type_value) { 'some-grand-type' }
    let(:error_context) do
      { code: code[:code], code_verifier: code_verifier[:code_verifier], grant_type: grant_type[:grant_type] }
    end

    shared_examples 'error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:expected_error_status) { :bad_request }
      let(:statsd_token_failure) { SignIn::Constants::Statsd::STATSD_SIS_TOKEN_FAILURE }

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed token request' do
        expect(Rails.logger).to receive(:error).with("#{expected_error} : #{error_context}")
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
                let(:client_id) { SignIn::Constants::ClientConfig::API_AUTH.first }

                it 'returns expected body with access token' do
                  expect(JSON.parse(subject.body)['data']).to have_key('access_token')
                end

                it 'returns expected body with refresh token' do
                  expect(JSON.parse(subject.body)['data']).to have_key('refresh_token')
                end
              end

              context 'and authentication is for a session with client id that is cookie auth' do
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
              end

              it 'logs the successful token request' do
                access_token = JWT.decode(JSON.parse(subject.body)['data']['access_token'], nil, false).first
                logger_context = { code: code[:code],
                                   token_type: 'Refresh',
                                   user_id: user_verification.user_account.id,
                                   session_id: access_token['session_handle'] }
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

  describe 'POST refresh' do
    subject { post(:refresh, params: {}.merge(refresh_token_param).merge(anti_csrf_token_param)) }

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
    let(:error_context) { { refresh_token: refresh_token, anti_csrf_token: anti_csrf_token } }

    shared_examples 'error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:statsd_refresh_error) { SignIn::Constants::Statsd::STATSD_SIS_REFRESH_FAILURE }

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed refresh attempt' do
        expect(Rails.logger).to receive(:error).once.with("#{expected_error} : #{error_context}")
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
          user_id: user_account.id,
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
        before { allow(Rails.logger).to receive(:info) }

        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
        end

        context 'and refresh token is for a session with client id that is api auth' do
          let(:client_id) { SignIn::Constants::ClientConfig::API_AUTH.first }

          it 'returns expected body with access token' do
            expect(JSON.parse(subject.body)['data']).to have_key('access_token')
          end

          it 'returns expected body with refresh token' do
            expect(JSON.parse(subject.body)['data']).to have_key('refresh_token')
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
        end

        it 'logs the session refresh' do
          expect(Rails.logger).to receive(:info).with(expected_log_message, expected_log_attributes)
          subject
        end

        it 'updates StatsD with a refresh request success' do
          expect { subject }.to trigger_statsd_increment(statsd_refresh_success)
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
    let(:error_context) { { refresh_token: refresh_token, anti_csrf_token: anti_csrf_token } }

    shared_examples 'error response' do
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:statsd_revoke_failure) { SignIn::Constants::Statsd::STATSD_SIS_REVOKE_FAILURE }

      it 'renders expected error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns expected status' do
        expect(subject).to have_http_status(expected_error_status)
      end

      it 'logs the failed revocation attempt' do
        expect(Rails.logger).to receive(:error).once.with("#{expected_error} : #{error_context}")
        subject
      end

      it 'updates StatsD with a revoke request failure' do
        expect { subject }.to trigger_statsd_increment(statsd_revoke_failure)
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

    context 'when refresh_token is a random string' do
      let(:expected_error) { 'Refresh token cannot be decrypted' }
      let(:expected_error_status) { :unauthorized }

      it_behaves_like 'error response'
    end

    context 'when refresh_token is encrypted correctly' do
      let(:session_container) { SignIn::SessionCreator.new(validated_credential: validated_credential).perform }
      let(:refresh_token) do
        SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
      end
      let(:expected_log_message) { '[SignInService] [V0::SignInController] revoke' }
      let(:statsd_revoke_success) { SignIn::Constants::Statsd::STATSD_SIS_REVOKE_SUCCESS }
      let(:expected_log_attributes) do
        {
          session_id: expected_session_handle,
          token_type: 'Refresh',
          user_id: user_account.id
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
      let(:expected_introspect_response) { JSON.parse(user_serializer.to_json) }
      let(:expected_log) { '[SignInService] [V0::SignInController] introspect' }
      let(:expected_log_params) do
        {
          token_type: 'Access',
          user_id: user.uuid,
          session_id: access_token_object.session_handle,
          access_token_id: access_token_object.uuid
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

      it 'logs the introspect call' do
        expect(Rails.logger).to receive(:info).with(expected_log, expected_log_params)
        subject
      end

      it 'triggers statsd increment for successful call' do
        expect { subject }.to trigger_statsd_increment(statsd_success)
      end

      context 'and some arbitrary Sign In Error is raised' do
        let(:expected_error) { SignIn::Errors::StandardError }
        let(:statsd_failure) { SignIn::Constants::Statsd::STATSD_SIS_INTROSPECT_FAILURE }
        let(:error_context) { { user_uuid: user.uuid } }
        let(:expected_error_log) { "#{expected_error} : #{error_context}" }

        before do
          allow(SignIn::IntrospectSerializer).to receive(:new).and_raise(expected_error)
        end

        it 'logs the failed introspect call' do
          expect(Rails.logger).to receive(:error).with(expected_error_log)
          subject
        end

        it 'triggers statsd increment for failed call' do
          expect { subject }.to trigger_statsd_increment(statsd_failure)
        end
      end
    end
  end

  describe 'GET revoke_all_sessions' do
    subject { get(:revoke_all_sessions) }

    context 'when successfully authenticated' do
      let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
      let(:authorization) { "Bearer #{access_token}" }
      let!(:user_account) { Login::UserVerifier.new(user).perform.user_account }
      let(:user) { create(:user, :loa3) }
      let(:oauth_session) { create(:oauth_session, user_account: user_account) }
      let(:access_token_object) do
        create(:access_token, session_handle: oauth_session.handle, user_uuid: user_account.id)
      end
      let(:oauth_session_count) { SignIn::OAuthSession.where(user_account: user_account).count }
      let(:statsd_success) { SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_SUCCESS }
      let(:expected_log) { '[SignInService] [V0::SignInController] revoke all sessions' }
      let(:expected_log_params) do
        {
          token_type: 'Access',
          user_id: user_account.id,
          session_id: access_token_object.session_handle,
          access_token_id: access_token_object.uuid
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
        let(:error_context) { { user_uuid: user_account.id } }
        let(:expected_error_log) { "#{expected_error} : #{error_context}" }
        let(:expected_error_json) { { 'errors' => expected_error.to_s } }
        let(:expected_error_status) { :unauthorized }

        before do
          allow(SignIn::RevokeSessionsForUser).to receive(:new).and_raise(expected_error)
        end

        it 'renders expected error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns expected status' do
          expect(subject).to have_http_status(expected_error_status)
        end

        it 'logs the failed revoke all sessions call' do
          expect(Rails.logger).to receive(:error).with(expected_error_log)
          subject
        end

        it 'triggers statsd increment for failed call' do
          expect { subject }.to trigger_statsd_increment(statsd_failure)
        end
      end
    end
  end
end
