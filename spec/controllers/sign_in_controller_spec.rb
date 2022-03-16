# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignInController, type: :controller do
  describe 'GET authorize' do
    subject { get(:authorize, params: {}.merge(type).merge(code_challenge).merge(code_challenge_method)) }

    let(:code_challenge) { { code_challenge: 'some-code-challenge' } }
    let(:code_challenge_method) { { code_challenge_method: 'some-code-challenge-method' } }
    let(:type) { { type: 'some-type' } }

    context 'when type param is not given' do
      let(:type) { {} }
      let(:expected_error) { ActionController::UrlGenerationError }

      it 'renders no route matches error' do
        expect { subject }.to raise_error(expected_error)
      end
    end

    context 'when type param is given but not in REDIRECT_URLS' do
      let(:type) { { type: 'some-undefined-type' } }
      let(:expected_error) { SignIn::Errors::AuthorizeInvalidType.to_s }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders invalid type error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns bad_request status' do
        expect(subject).to have_http_status(:bad_request)
      end
    end

    context 'when type param is logingov' do
      let(:type) { { type: logingov_type } }
      let(:logingov_type) { 'logingov' }

      context 'and code_challenge_method is not given' do
        let(:code_challenge_method) { {} }
        let(:expected_error) { SignIn::Errors::MalformedParamsError.to_s }
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
          let(:expected_error) { SignIn::Errors::MalformedParamsError.to_s }
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
          let(:expected_error) { SignIn::Errors::CodeChallengeMalformedError.to_s }
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

          it 'returns ok status' do
            expect(subject).to have_http_status(:ok)
          end

          it 'renders expected state in template' do
            expect(subject.body).to match(state)
          end

          it 'renders expected type in template' do
            expect(subject.body).to match(logingov_type)
          end
        end
      end

      context 'and code_challenge_method is not S256' do
        let(:code_challenge_method) { { code_challenge_method: 'some-code-challenge-method' } }
        let(:expected_error) { SignIn::Errors::CodeChallengeMethodMismatchError.to_s }
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
      let(:type) { { type: 'idme' } }

      it 'returns bad_request status' do
        expect(subject).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST token' do
    subject { get(:token, params: {}.merge(code).merge(code_verifier).merge(grant_type)) }

    let(:code) { { code: code_value } }
    let(:code_verifier) { { code_verifier: code_verifier_value } }
    let(:grant_type) { { grant_type: grant_type_value } }
    let(:code_value) { 'some-code' }
    let(:code_verifier_value) { 'some-code-verifier' }
    let(:grant_type_value) { 'some-grand-type' }

    context 'when code param is not given' do
      let(:code) { {} }
      let(:expected_error) { SignIn::Errors::MalformedParamsError.to_s }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders malformed params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end
    end

    context 'when code_verifier param is not given' do
      let(:code_verifier) { {} }
      let(:expected_error) { SignIn::Errors::MalformedParamsError.to_s }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders malformed params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end
    end

    context 'when grant_type param is not given' do
      let(:grant_type) { {} }
      let(:expected_error) { SignIn::Errors::MalformedParamsError.to_s }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders malformed params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end
    end

    context 'when code, code_verifier, and grant_type params are defined' do
      context 'and code does not match an existing code container' do
        let(:code) { { code: 'some-arbitrary-code' } }
        let(:expected_error) { SignIn::Errors::CodeInvalidError.to_s }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders code invalid error error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end

      context 'and code param does match an existing code container' do
        let(:code) { { code: code_value } }
        let(:code_value) { 'some-code-value' }
        let!(:code_container) do
          create(:code_container,
                 code: code_value,
                 code_challenge: code_challenge,
                 user_account_uuid: user_account_uuid)
        end
        let(:code_challenge) { 'some-code-challenge' }
        let(:user_account_uuid) { user_account.id }
        let(:user_account) { create(:user_account) }

        context 'and code_verifier does not match expected code_challenge value' do
          let(:code_verifier_value) { 'some-arbitrary-code-verifier-value' }
          let(:expected_error) { SignIn::Errors::CodeChallengeMismatchError.to_s }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it 'renders code challenge mismatch error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns unauthorized status' do
            expect(subject).to have_http_status(:unauthorized)
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
            let(:expected_error) { SignIn::Errors::GrantTypeValueError.to_s }
            let(:expected_error_json) { { 'errors' => expected_error } }

            it 'renders grant type value error' do
              expect(JSON.parse(subject.body)).to eq(expected_error_json)
            end

            it 'returns unauthorized status' do
              expect(subject).to have_http_status(:unauthorized)
            end
          end

          context 'and grant_type does match supported grant type value' do
            let(:grant_type_value) { SignIn::Constants::Auth::GRANT_TYPE }

            context 'and code_container matched with code does not match to a user account' do
              let(:user_account_uuid) { 'some-arbitrary-user-account-uuid' }
              let(:expected_error) { "Couldn't find UserAccount with 'id'=#{user_account_uuid}" }
              let(:expected_error_json) { { 'errors' => expected_error } }

              it 'renders expected error' do
                expect(JSON.parse(subject.body)).to eq(expected_error_json)
              end

              it 'returns unauthorized status' do
                expect(subject).to have_http_status(:unauthorized)
              end
            end

            context 'and code_container matched with code does match a user account' do
              let(:user_account_uuid) { user_account.id }
              let(:user_account) { create(:user_account) }

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
    let(:type) { { type: 'some-type' } }
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
      let(:expected_error) { SignIn::Errors::CallbackInvalidType.to_s }
      let(:expected_error_json) { { 'errors' => expected_error } }

      it 'renders invalid type error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns bad_request status' do
        expect(subject).to have_http_status(:bad_request)
      end
    end

    context 'when type param is logingov' do
      let(:type) { { type: logingov_type } }
      let(:logingov_type) { 'logingov' }
      let(:response) { OpenStruct.new(access_token: token) }
      let(:token) { 'some-token' }
      let(:user_info) do
        {
          verified_at: '1-1-2022',
          sub: 'some-sub',
          social_security_number: '123456789',
          birthdate: '1-1-2022',
          given_name: 'some-name',
          family_name: 'some-family-name',
          email: 'some-email'
        }
      end

      before do
        allow_any_instance_of(SignIn::Logingov::Service).to receive(:token).with(code_value).and_return(response)
        allow_any_instance_of(SignIn::Logingov::Service).to receive(:user_info).with(token).and_return(user_info)
      end

      context 'and code is not given' do
        let(:code) { {} }
        let(:expected_error) { SignIn::Errors::MalformedParamsError.to_s }
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
        let(:expected_error) { SignIn::Errors::CodeInvalidError.to_s }
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
          let(:expected_error) { SignIn::Errors::MalformedParamsError.to_s }
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
          let(:expected_error) { SignIn::Errors::StateMismatchError.to_s }
          let(:expected_error_json) { { 'errors' => expected_error } }

          it 'renders state mismatch error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns bad_request status' do
            expect(subject).to have_http_status(:bad_request)
          end
        end

        context 'and state is given and matches expected state' do
          let(:code_challenge_state_map) { create(:code_challenge_state_map) }
          let(:state) { { state: code_challenge_state_map.state } }
          let(:client_code) { 'some-client-code' }
          let(:expected_url) { "#{Settings.sign_in.redirect_uri}?code=#{client_code}" }

          before do
            allow(SecureRandom).to receive(:uuid).and_return(client_code)
          end

          it 'returns found status' do
            expect(subject).to have_http_status(:found)
          end

          it 'redirects to expected url' do
            expect(subject).to redirect_to(expected_url)
          end
        end
      end
    end

    context 'when type param is idme' do
      let(:type) { { type: 'idme' } }

      it 'returns bad_request status' do
        expect(subject).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST refresh' do
    subject { post(:refresh, params: {}.merge(refresh_token_param).merge(anti_csrf_token_param)) }

    let(:refresh_token_param) { { refresh_token: refresh_token } }
    let(:anti_csrf_token_param) { { anti_csrf_token: anti_csrf_token } }
    let(:refresh_token) { 'some-refresh-token' }
    let(:anti_csrf_token) { 'some-anti-csrf-token' }

    context 'when refresh_token and anti_csrf_token param is given' do
      context 'and refresh_token is an arbitrary string' do
        let(:refresh_token) { 'some-refresh-token' }
        let(:expected_error) { 'Decryption failed' }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders Decryption failed error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end

      context 'and refresh_token is the proper encrypted refresh token format' do
        let(:user_account) { create(:user_account) }
        let(:session_container) { SignIn::SessionCreator.new(user_account: user_account).perform }
        let(:refresh_token) do
          SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
        end
        let(:anti_csrf_token) { session_container.anti_csrf_token }

        context 'and encrypted component has been modified' do
          let(:expected_error) { 'Decryption failed' }
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
          let(:expected_error) { SignIn::Errors::RefreshNonceMismatchError.to_s }
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
          let(:expected_error) { SignIn::Errors::RefreshVersionMismatchError.to_s }
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

        context 'and anti_csrf_token has been modified' do
          let(:expected_error) { SignIn::Errors::AntiCSRFMismatchError.to_s }
          let(:expected_error_json) { { 'errors' => expected_error } }

          let(:anti_csrf_token) { 'some-modified-anti-csrf-token' }

          it 'renders an anti csrf mismatch error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns unauthorized status' do
            expect(subject).to have_http_status(:unauthorized)
          end
        end

        context 'and refresh token is expired' do
          let(:expected_error) { SignIn::Errors::SessionNotAuthorizedError.to_s }
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
          let(:expected_error) { SignIn::Errors::SessionNotAuthorizedError.to_s }
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
          let(:expected_error) { SignIn::Errors::TokenTheftDetectedError.to_s }
          let(:expected_error_json) { { 'errors' => expected_error } }

          before do
            session = session_container.session
            session.hashed_refresh_token = 'some-unrelated-refresh-token'
            session.save!
          end

          it 'renders a session not authorized error' do
            expect(JSON.parse(subject.body)).to eq(expected_error_json)
          end

          it 'returns unauthorized status' do
            expect(subject).to have_http_status(:unauthorized)
          end
        end

        context 'and both refresh token and anti csrf token are unmodified and valid' do
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

    context 'when refresh_token param is not given' do
      let(:expected_error) { SignIn::Errors::MalformedParamsError.to_s }
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:refresh_token_param) { {} }

      it 'renders Malformed Params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end
    end

    context 'when anti_csrf_token param is not given' do
      let(:expected_error) { SignIn::Errors::MalformedParamsError.to_s }
      let(:expected_error_json) { { 'errors' => expected_error } }
      let(:anti_csrf_token_param) { {} }

      it 'renders Malformed Params error' do
        expect(JSON.parse(subject.body)).to eq(expected_error_json)
      end

      it 'returns unauthorized status' do
        expect(subject).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET introspect' do
    subject { get(:introspect) }

    context 'when authorization header does not exist' do
      let(:authorization_header) { nil }
      let(:expected_error) { SignIn::Errors::AccessTokenMalformedJWTError.to_s }
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
        let(:expected_error) { SignIn::Errors::AccessTokenMalformedJWTError.to_s }
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
        let(:expected_error) { SignIn::Errors::AccessTokenExpiredError.to_s }
        let(:expected_error_json) { { 'errors' => expected_error } }

        it 'renders Malformed Params error' do
          expect(JSON.parse(subject.body)).to eq(expected_error_json)
        end

        it 'returns unauthorized status' do
          expect(subject).to have_http_status(:unauthorized)
        end
      end

      context 'and access_token is an active JWT' do
        let(:access_token_object) { create(:access_token) }
        let(:access_token) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }
        let(:expected_error) { SignIn::Errors::AccessTokenMalformedJWTError.to_s }
        let!(:user) { create(:user, uuid: access_token_object.user_uuid) }
        let(:expected_introspect_response) { { 'user_uuid' => user.uuid, 'icn' => user.icn } }

        it 'renders expected user data' do
          expect(JSON.parse(subject.body)).to eq(expected_introspect_response)
        end

        it 'returns ok status' do
          expect(subject).to have_http_status(:ok)
        end
      end
    end
  end
end
