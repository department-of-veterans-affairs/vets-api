# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  before do
    Timecop.freeze(Time.zone.now.floor)
    allow(Rails.logger).to receive(:info)
  end

  after { Timecop.return }

  describe 'GET authorize' do
    subject do
      get(:authorize, params: {}.merge(type).merge(code_challenge).merge(code_challenge_method).merge(client_state))
    end

    let(:code_challenge) { { code_challenge: 'some-code-challenge' } }
    let(:code_challenge_method) { { code_challenge_method: 'some-code-challenge-method' } }
    let(:client_state) { {} }
    let(:client_state_minimum_length) { SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH }
    let(:type) { { type: type_value } }
    let(:type_value) { 'some-type' }

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
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders invalid type error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns bad_request status' do
        expect(subject).to have_http_status(:bad_request)
      end
    end

    context 'when type param is logingov' do
      let(:type_value) { 'logingov' }

      context 'and code_challenge_method is not given' do
        let(:code_challenge_method) { {} }
        let(:expected_error) { 'Code Challenge Method is not defined' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders malformed params error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns bad_request status' do
          expect(subject).to have_http_status(:bad_request)
        end
      end

      context 'and code_challenge_method is S256' do
        let(:code_challenge_method) { { code_challenge_method: 'S256' } }

        context 'and code_challenge is not given' do
          let(:code_challenge) { {} }
          let(:expected_error) { 'Code Challenge is not defined' }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it 'renders malformed params error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns bad_request status' do
            expect(subject).to have_http_status(:bad_request)
          end
        end

        context 'and code_challenge is not properly URL encoded' do
          let(:code_challenge) { { code_challenge: '///some+unsafe code+challenge//' } }
          let(:expected_error) { 'Code Challenge is not valid' }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it 'renders code challenge malformed error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns bad_request status' do
            expect(subject).to have_http_status(:bad_request)
          end
        end

        context 'and code_challenge is properly URL encoded' do
          let(:code_challenge) { { code_challenge: Base64.urlsafe_encode64('some-safe-code-challenge') } }
          let(:state) { 'some-random-state' }
          let(:expected_redirect_uri) { Settings.logingov.redirect_uri }

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
            let(:expected_error) { 'Code Challenge or State is not valid' }
            let(:expected_error_json) { { 'errors' => expected_error } }

            it 'renders code challenge or state not valid error' do
              expect(JSON.parse(subject.body)).to eq(expected_error_json)
            end

            it 'returns bad_request status' do
              expect(subject).to have_http_status(:bad_request)
            end
          end

          it 'logs the authentication attempt' do
            expect(Rails.logger).to receive(:info).once.with(
              'Sign in Service Authorization Attempt',
              { state: state, type: type[:type], client_state: nil,
                code_challenge: code_challenge[:code_challenge], timestamp: Time.zone.now.to_s,
                code_challenge_method: code_challenge_method[:code_challenge_method] }
            )
            subject
          end
        end
      end

      context 'and code_challenge_method is not S256' do
        let(:code_challenge_method) { { code_challenge_method: 'some-code-challenge-method' } }
        let(:expected_error) { 'Code Challenge Method is not valid' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders code challenge method not valid error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns bad_request status' do
          expect(subject).to have_http_status(:bad_request)
        end
      end
    end

    shared_context 'an idme authentication service interface' do
      context 'and code_challenge_method is not given' do
        let(:code_challenge_method) { {} }
        let(:expected_error) { 'Code Challenge Method is not defined' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders malformed params error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns bad_request status' do
          expect(subject).to have_http_status(:bad_request)
        end
      end

      context 'and code_challenge_method is S256' do
        let(:code_challenge_method) { { code_challenge_method: 'S256' } }

        context 'and code_challenge is not given' do
          let(:code_challenge) { {} }
          let(:expected_error) { 'Code Challenge is not defined' }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it 'renders malformed params error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns bad_request status' do
            expect(subject).to have_http_status(:bad_request)
          end
        end

        context 'and code_challenge is not properly URL encoded' do
          let(:code_challenge) { { code_challenge: '///some+unsafe code+challenge//' } }
          let(:expected_error) { 'Code Challenge is not valid' }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it 'renders code challenge malformed error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns bad_request status' do
            expect(subject).to have_http_status(:bad_request)
          end
        end

        context 'and code_challenge is properly URL encoded' do
          let(:code_challenge) { { code_challenge: Base64.urlsafe_encode64('some-safe-code-challenge') } }
          let(:state) { 'some-random-state' }

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
              expect(Rails.logger).to receive(:info).once.with(
                'Sign in Service Authorization Attempt',
                { state: state, type: type[:type], client_state: client_state[:state],
                  code_challenge: code_challenge[:code_challenge], timestamp: Time.zone.now.to_s,
                  code_challenge_method: code_challenge_method[:code_challenge_method] }
              )
              subject
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
            let(:expected_error) { 'Code Challenge or State is not valid' }
            let(:expected_error_json) { { 'errors' => expected_error } }

            it 'renders code challenge not valid error' do
              expect(JSON.parse(subject.body)).to eq(expected_error_json)
            end

            it 'returns bad_request status' do
              expect(subject).to have_http_status(:bad_request)
            end
          end
        end
      end

      context 'and code_challenge_method is not S256' do
        let(:code_challenge_method) { { code_challenge_method: 'some-code-challenge-method' } }
        let(:expected_error) { 'Code Challenge Method is not valid' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders code challenge method mismatch error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns bad_request status' do
          expect(subject).to have_http_status(:bad_request)
        end
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

    context 'when code param is not given' do
      let(:code) { {} }
      let(:expected_error) { 'Code is not defined' }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders malformed params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns bad request status' do
        expect(subject).to have_http_status(:bad_request)
      end
    end

    context 'when code_verifier param is not given' do
      let(:code_verifier) { {} }
      let(:expected_error) { 'Code Verifier is not defined' }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders malformed params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns bad request status' do
        expect(subject).to have_http_status(:bad_request)
      end
    end

    context 'when grant_type param is not given' do
      let(:grant_type) { {} }
      let(:expected_error) { 'Grant Type is not defined' }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders malformed params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns bad request status' do
        expect(subject).to have_http_status(:bad_request)
      end
    end

    context 'when code, code_verifier, and grant_type params are defined' do
      context 'and code does not match an existing code container' do
        let(:code) { { code: 'some-arbitrary-code' } }
        let(:expected_error) { 'Code is not valid' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders code invalid error error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns bad request status' do
          expect(subject).to have_http_status(:bad_request)
        end
      end

      context 'and code param does match an existing code container' do
        let(:code) { { code: code_value } }
        let(:code_value) { 'some-code-value' }
        let!(:code_container) do
          create(:code_container,
                 code: code_value,
                 code_challenge: code_challenge,
                 user_verification_id: user_verification_id)
        end
        let(:code_challenge) { 'some-code-challenge' }

        context 'and code_verifier does not match expected code_challenge value' do
          let(:code_verifier_value) { 'some-arbitrary-code-verifier-value' }
          let(:expected_error) { 'Code Verifier is not valid' }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it 'renders code challenge mismatch error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns bad request status' do
            expect(subject).to have_http_status(:bad_request)
          end
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
            let(:expected_error_json) { { 'errors' => expected_error } }

            it 'renders grant type value error' do
              expect(JSON.parse(subject.body)).to eq(expected_error_json)
            end

            it 'returns bad request status' do
              expect(subject).to have_http_status(:bad_request)
            end
          end

          context 'and grant_type does match supported grant type value' do
            let(:grant_type_value) { SignIn::Constants::Auth::GRANT_TYPE }

            context 'and code_container matched with code does match a user account' do
              let(:user_verification_id) { user_verification.id }
              let(:user_verification) { create(:user_verification) }

              it 'creates an OAuthSession' do
                expect { subject }.to change(SignIn::OAuthSession, :count).by(1)
              end

              it 'returns ok status' do
                expect(subject).to have_http_status(:ok)
              end

              it 'returns expected body with access token' do
                expect(JSON.parse(subject.body)['data']).to have_key('access_token')
              end

              it 'returns expected body with refresh token' do
                expect(JSON.parse(subject.body)['data']).to have_key('refresh_token')
              end

              it 'returns expected body with anti csrf token token' do
                expect(JSON.parse(subject.body)['data']).to have_key('anti_csrf_token')
              end
            end
          end
        end
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

    context 'when type param is not given' do
      let(:type) { {} }
      let(:expected_error) { ActionController::UrlGenerationError }

      it 'renders no route matches error' do
        expect { subject }.to raise_error(expected_error)
      end
    end

    context 'when type param is given but not in REDIRECT_URLS' do
      let(:type) { { type: 'some-undefined-type' } }
      let(:expected_error) { 'Callback type is not valid' }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders invalid type error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns bad_request status' do
        expect(subject).to have_http_status(:bad_request)
      end
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
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders malformed params error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns bad_request status' do
          expect(subject).to have_http_status(:bad_request)
        end
      end

      context 'and code is given but does not match expected code for auth service' do
        let(:response) { nil }
        let(:expected_error) { 'Authentication Code is not valid' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders code invalid error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns bad_request status' do
          expect(subject).to have_http_status(:bad_request)
        end
      end

      context 'and code is given that matches expected code for auth service' do
        context 'and state is not given' do
          let(:state) { {} }
          let(:expected_error) { 'State is not defined' }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it 'renders malformed params error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns bad_request status' do
            expect(subject).to have_http_status(:bad_request)
          end
        end

        context 'and state is given but does not match expected state' do
          let(:state) { { state: 'some-state' } }
          let(:expected_error) { 'Authentication Attempt Cannot be found' }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it 'renders state mismatch error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns bad_request status' do
            expect(subject).to have_http_status(:bad_request)
          end
        end

        context 'and state is given and matches expected state' do
          let(:code_challenge_state_map) { create(:code_challenge_state_map, client_state: client_state) }
          let(:state) { { state: code_challenge_state_map.state } }
          let(:client_code) { 'some-client-code' }
          let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }
          let(:expected_url) { "#{Settings.sign_in.redirect_uri}?code=#{client_code}&state=#{client_state}" }
          let(:expected_log) { 'Sign in Service Authorization Callback' }
          let(:current_time) { Time.zone.now.to_s }
          let(:expected_log_attributes) do
            {
              state: state[:state],
              type: type[:type],
              code: code[:code],
              login_code: client_code,
              client_state: client_state,
              timestamp: current_time
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

          it 'logs the authentication attempt' do
            expect(Rails.logger).to receive(:info).with(expected_log, expected_log_attributes)
            subject
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
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders malformed params error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns bad_request status' do
          expect(subject).to have_http_status(:bad_request)
        end
      end

      context 'and code is given but does not match expected code for auth service' do
        let(:response) { nil }
        let(:expected_error) { 'Authentication Code is not valid' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders code invalid error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns bad_request status' do
          expect(subject).to have_http_status(:bad_request)
        end
      end

      context 'and code is given that matches expected code for auth service' do
        context 'and state is not given' do
          let(:state) { {} }
          let(:expected_error) { 'State is not defined' }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it 'renders malformed params error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns bad_request status' do
            expect(subject).to have_http_status(:bad_request)
          end
        end

        context 'and state is given but does not match expected state' do
          let(:state) { { state: 'some-state' } }
          let(:expected_error) { 'Authentication Attempt Cannot be found' }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it 'renders state mismatch error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns bad_request status' do
            expect(subject).to have_http_status(:bad_request)
          end
        end

        context 'and state is given and matches expected state' do
          let(:code_challenge_state_map) { create(:code_challenge_state_map, client_state: client_state) }
          let(:state) { { state: code_challenge_state_map.state } }
          let(:client_code) { 'some-client-code' }
          let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }
          let(:expected_url) { "#{Settings.sign_in.redirect_uri}?code=#{client_code}&state=#{client_state}" }
          let(:expected_log) { 'Sign in Service Authorization Callback' }
          let(:current_time) { Time.zone.now.to_s }
          let(:expected_log_attributes) do
            {
              state: state[:state],
              type: type[:type],
              code: code[:code],
              login_code: client_code,
              client_state: client_state,
              timestamp: current_time
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

          it 'logs the authentication attempt' do
            expect(Rails.logger).to receive(:info).with(expected_log, expected_log_attributes)
            subject
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

  describe 'POST revoke' do
    subject { post(:revoke, params: {}.merge(refresh_token_param).merge(anti_csrf_token_param)) }

    let(:refresh_token_param) { { refresh_token: refresh_token } }
    let(:refresh_token) { 'example-refresh-token' }
    let(:anti_csrf_token_param) { { anti_csrf_token: anti_csrf_token } }
    let(:anti_csrf_token) { 'example-anti-csrf-token' }
    let(:enable_anti_csrf) { false }
    let(:user_verification) { create(:user_verification) }
    let(:user_account) { user_verification.user_account }
    let(:validated_credential) { create(:validated_credential, user_verification: user_verification) }

    before do
      allow(Settings.sign_in).to receive(:enable_anti_csrf).and_return(enable_anti_csrf)
      allow(Rails.logger).to receive(:info)
    end

    context 'when Settings sign_in enable_anti_csrf is enabled' do
      let(:enable_anti_csrf) { true }

      context 'and anti_csrf_token param is not given' do
        let(:expected_error) { 'Anti CSRF token is not defined' }
        let(:expected_error_json) { { 'errors' => expected_error } }
        let(:anti_csrf_token_param) { {} }

        it 'renders Malformed Params error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns bad request status' do
          expect(subject).to have_http_status(:bad_request)
        end
      end

      context 'and anti_csrf_token has been modified' do
        let(:session_container) { SignIn::SessionCreator.new(validated_credential: validated_credential).perform }
        let(:refresh_token) do
          SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
        end
        let(:expected_error) { 'Anti CSRF token is not valid' }
        let(:expected_error_json) { { 'errors' => expected_error } }
        let(:anti_csrf_token) { 'some-modified-anti-csrf-token' }

        it 'renders an anti csrf mismatch error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end
    end

    context 'when refresh_token is a random string' do
      let(:expected_error) { 'Refresh token cannot be decrypted' }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders Decryption failed error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end
    end

    context 'when refresh_token is encrypted correctly' do
      let(:session_container) { SignIn::SessionCreator.new(validated_credential: validated_credential).perform }
      let(:refresh_token) do
        SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
      end
      let(:timestamp) { Time.zone.now.to_s }
      let(:expected_log_message) { 'Sign in Service Session Revoke' }
      let(:expected_log_attributes) do
        {
          session_id: expected_session_handle,
          timestamp: timestamp,
          token_type: 'Refresh',
          user_id: user_account.id
        }
      end

      context 'when refresh token is expired' do
        let(:expected_error) { 'No valid Session found' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        before do
          session = session_container.session
          session.refresh_expiration = 1.day.ago
          session.save!
        end

        it 'renders a no valid session error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end

      context 'when refresh token does not map to an existing session' do
        let(:expected_error) { 'No valid Session found' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        before do
          session = session_container.session
          session.destroy!
        end

        it 'renders a no valid session error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
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
      end
    end
  end

  describe 'POST refresh' do
    subject { post(:refresh, params: {}.merge(refresh_token_param).merge(anti_csrf_token_param)) }

    let(:refresh_token_param) { { refresh_token: refresh_token } }
    let(:anti_csrf_token_param) { { anti_csrf_token: anti_csrf_token } }
    let(:refresh_token) { 'some-refresh-token' }
    let(:anti_csrf_token) { 'some-anti-csrf-token' }
    let(:enable_anti_csrf) { true }
    let(:user_verification) { create(:user_verification) }
    let(:user_account) { user_verification.user_account }
    let(:validated_credential) { create(:validated_credential, user_verification: user_verification) }

    before do
      allow(Settings.sign_in).to receive(:enable_anti_csrf).and_return(enable_anti_csrf)
      allow(Rails.logger).to receive(:info)
    end

    context 'when Settings sign_in enable_anti_csrf is enabled' do
      let(:enable_anti_csrf) { true }

      context 'and anti_csrf_token param is not given' do
        let(:expected_error) { 'Anti CSRF token is not defined' }
        let(:expected_error_json) { { 'errors' => expected_error } }
        let(:anti_csrf_token_param) { {} }

        it 'renders Malformed Params error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns bad request status' do
          expect(subject).to have_http_status(:bad_request)
        end
      end

      context 'and anti_csrf_token has been modified' do
        let(:session_container) { SignIn::SessionCreator.new(validated_credential: validated_credential).perform }
        let(:refresh_token) do
          SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
        end
        let(:expected_error) { 'Anti CSRF token is not valid' }
        let(:expected_error_json) { { 'errors' => expected_error } }
        let(:anti_csrf_token) { 'some-modified-anti-csrf-token' }

        it 'renders an anti csrf mismatch error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end
    end

    context 'when refresh_token is an arbitrary string' do
      let(:refresh_token) { 'some-refresh-token' }
      let(:expected_error) { 'Refresh token cannot be decrypted' }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders Decryption failed error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end
    end

    context 'when refresh_token is the proper encrypted refresh token format' do
      let(:session_container) { SignIn::SessionCreator.new(validated_credential: validated_credential).perform }
      let(:refresh_token) do
        SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
      end
      let(:anti_csrf_token) { session_container.anti_csrf_token }
      let(:timestamp) { Time.zone.now.to_s }
      let(:expected_session_handle) { session_container.session.handle }
      let(:expected_log_message) { 'Sign in Service Tokens Refresh' }
      let(:expected_log_attributes) do
        {
          session_id: expected_session_handle,
          timestamp: timestamp,
          token_type: 'Refresh',
          user_id: user_account.id
        }
      end

      context 'and encrypted component has been modified' do
        let(:expected_error) { 'Refresh token cannot be decrypted' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        let(:refresh_token) do
          token = SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
          split_token = token.split('.')
          split_token[0] = 'some-modified-encrypted-component'
          split_token.join
        end

        it 'renders Decryption failed error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end

      context 'and nonce component has been modified' do
        let(:expected_error) { 'Refresh nonce is invalid' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        let(:refresh_token) do
          token = SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
          split_token = token.split('.')
          split_token[1] = 'some-modified-nonce-component'
          split_token.join('.')
        end

        it 'renders a nonce mismatch error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end

      context 'and version has been modified' do
        let(:expected_error) { 'Refresh token version is invalid' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        let(:refresh_token) do
          token = SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
          split_token = token.split('.')
          split_token[2] = 'some-modified-version-component'
          split_token.join('.')
        end

        it 'renders a version mismatch error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end

      context 'and refresh token is expired' do
        let(:expected_error) { 'No valid Session found' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        before do
          session = session_container.session
          session.refresh_expiration = 1.day.ago
          session.save!
        end

        it 'renders a session not authorized error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end

      context 'and refresh token does not map to an existing session' do
        let(:expected_error) { 'No valid Session found' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        before do
          session = session_container.session
          session.destroy!
        end

        it 'renders a session not authorized error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end

      context 'and refresh token is not a parent or child according to the session' do
        let(:expected_error) { 'Token theft detected' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        before do
          session = session_container.session
          session.hashed_refresh_token = 'some-unrelated-refresh-token'
          session.save!
        end

        it 'destroys the existing session' do
          expect { subject }.to change(SignIn::OAuthSession, :count).from(1).to(0)
        end

        it 'renders a session not authorized error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end

      context 'and refresh token is unmodified and valid' do
        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
        end

        it 'returns expected body with access token' do
          expect(JSON.parse(subject.body)['data']).to have_key('access_token')
        end

        it 'returns expected body with refresh token' do
          expect(JSON.parse(subject.body)['data']).to have_key('refresh_token')
        end

        it 'returns expected body with anti csrf token token' do
          expect(JSON.parse(subject.body)['data']).to have_key('anti_csrf_token')
        end

        it 'logs the token refresh' do
          expect(Rails.logger).to receive(:info).with(expected_log_message, expected_log_attributes)
          subject
        end
      end
    end

    context 'when refresh_token param is not given' do
      let(:expected_error) { 'Refresh token is not defined' }
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:refresh_token_param) { {} }

      it 'renders Malformed Params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns bad request status' do
        expect(subject).to have_http_status(:bad_request)
      end
    end
  end

  describe 'GET introspect' do
    subject { get(:introspect) }

    context 'when authorization header does not exist' do
      let(:authorization_header) { nil }
      let(:expected_error) { 'Access token JWT is malformed' }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders Malformed Params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end
    end

    context 'when authorization header exists' do
      let(:authorization) { "Bearer #{access_token}" }
      let(:access_token) { 'some-access-token' }

      before do
        request.headers['Authorization'] = authorization
      end

      context 'and access_token is some arbitrary value' do
        let(:access_token) { 'some-arbitrary-access-token' }
        let(:expected_error) { 'Access token JWT is malformed' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders Malformed Params error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end

      context 'and access_token is an expired JWT' do
        let(:access_token_object) { create(:access_token, expiration_time: expiration_time) }
        let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
        let(:expiration_time) { Time.zone.now - 1.day }
        let(:expected_error) { 'Access token has expired' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders Access Token Expired error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns forbidden status' do
          expect(subject).to have_http_status(:forbidden)
        end
      end

      context 'and access_token is an active JWT' do
        let(:access_token_object) { create(:access_token) }
        let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
        let(:expected_error) { SignIn::Errors::AccessTokenMalformedJWTError.to_s }
        let!(:user) { create(:user, :loa3, uuid: access_token_object.user_uuid) }
        let(:user_serializer) { SignIn::IntrospectSerializer.new(user) }
        let(:expected_introspect_response) { JSON.parse(user_serializer.to_json) }

        it 'renders expected user data' do
          expect(JSON.parse(subject.body)['data']['attributes']).to eq(expected_introspect_response)
        end

        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
        end

        it 'logs the instrospection' do
          subject
          expect(Rails.logger).to have_received(:info).once.with(
            'Sign in Service Introspect',
            { token_type: 'Access', user_id: user.uuid, session_id: access_token_object.session_handle,
              access_token_id: access_token_object.uuid, timestamp: Time.zone.now.to_s }
          )
        end
      end
    end
  end
end
