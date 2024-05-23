# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::TokenExchanger, type: :model do
  subject(:token_exchanger) do
    described_class.new(subject_token:, subject_token_type:, actor_token:, actor_token_type:, client_id:)
  end

  let!(:current_session) { create(:oauth_session, hashed_device_secret: current_session_device_secret) }
  let(:current_session_device_secret) { hashed_device_secret }
  let(:current_access_token_device_secret) { hashed_device_secret }
  let(:web_client_id) { 'some-web-client-id' }
  let!(:current_client_config) do
    create(:client_config, authentication: :api,
                           shared_sessions: true,
                           access_token_attributes: %i[first_name last_name email])
  end
  let(:current_access_token) do
    create(:access_token, session_handle: current_session.handle,
                          device_secret_hash: current_access_token_device_secret,
                          client_id: current_client_config.client_id)
  end
  let(:web_client_config) do
    create(:client_config, client_id: web_client_id, access_token_attributes: %i[first_name last_name email])
  end

  let(:subject_token) { SignIn::AccessTokenJwtEncoder.new(access_token: current_access_token).perform }
  let(:subject_token_type) { SignIn::Constants::AccessToken::OAUTH_TOKEN_TYPE }
  let(:actor_token) { device_secret }
  let(:actor_token_type) { SignIn::Constants::Auth::DEVICE_SECRET_TOKEN_TYPE }
  let(:client_id) { web_client_config.client_id }
  let(:device_secret) { 'some-device-secret' }
  let(:hashed_device_secret) { Digest::SHA256.hexdigest(device_secret) }

  shared_examples 'a valid token exchanger' do
    it 'is valid' do
      expect(token_exchanger.perform).to be_valid
    end
  end

  shared_examples 'an invalid token exchanger' do
    it 'is invalid' do
      expect { token_exchanger.perform }.to raise_error(
        SignIn::Errors::TokenExchangerError
      ).with_message(/#{attribute.to_s.humanize} #{expected_error_message}/)
    end
  end

  before do
    allow(Settings.sign_in).to receive(:vaweb_client_id).and_return(web_client_id)
  end

  describe 'validations' do
    context 'when subject_token' do
      let(:attribute) { :subject_token }

      context 'is blank' do
        let(:subject_token) { nil }
        let(:expected_error_message) { "can't be blank" }

        it_behaves_like 'an invalid token exchanger'
      end

      context 'is invalid' do
        let(:subject_token) { 'some-subject-token' }
        let(:expected_error_message) { 'is not valid' }
      end

      context 'is valid' do
        it_behaves_like 'a valid token exchanger'
      end
    end

    context 'when subject_token_type' do
      let(:attribute) { :subject_token_type }

      context 'is blank' do
        let(:subject_token_type) { nil }
        let(:expected_error_message) { "can't be blank" }

        it_behaves_like 'an invalid token exchanger'
      end

      context 'is invalid' do
        let(:subject_token_type) { 'invalid-subject-token-type' }
        let(:expected_error_message) { 'is not valid' }

        it_behaves_like 'an invalid token exchanger'
      end

      context 'is valid' do
        it_behaves_like 'a valid token exchanger'
      end
    end

    context 'when actor_token' do
      let(:attribute) { :actor_token }

      context 'is blank' do
        let(:actor_token) { nil }
        let(:expected_error_message) { "can't be blank" }

        it_behaves_like 'an invalid token exchanger'
      end

      context 'does not match oauth_session hashed device secret' do
        let(:current_session_device_secret) { 'some-other-hash' }
        let(:expected_error_message) { 'does not match current_session' }

        it_behaves_like 'an invalid token exchanger'
      end

      context 'does not match subject_token hashed device secret' do
        let(:current_access_token_device_secret) { 'some-other-hash' }
        let(:expected_error_message) { 'does not match subject_token' }

        it_behaves_like 'an invalid token exchanger'
      end

      context 'is valid' do
        it_behaves_like 'a valid token exchanger'
      end
    end

    context 'when actor_token_type' do
      let(:attribute) { :actor_token_type }

      context 'is blank' do
        let(:actor_token_type) { nil }
        let(:expected_error_message) { "can't be blank" }

        it_behaves_like 'an invalid token exchanger'
      end

      context 'is invalid' do
        let(:actor_token_type) { 'invalid-actor-token-type' }
        let(:expected_error_message) { 'is not valid' }

        it_behaves_like 'an invalid token exchanger'
      end

      context 'is valid' do
        it_behaves_like 'a valid token exchanger'
      end
    end

    context 'when client_id' do
      let(:attribute) { :client_id }

      context 'is blank' do
        let(:client_id) { nil }
        let(:expected_error_message) { "can't be blank" }

        it_behaves_like 'an invalid token exchanger'
      end

      context 'when client_id is not the web client id' do
        let(:client_id) { 'some-other-client-id' }
        let(:expected_error_message) { 'is not valid' }

        it_behaves_like 'an invalid token exchanger'
      end

      context 'is valid' do
        it_behaves_like 'a valid token exchanger'
      end
    end

    context 'when device_sso' do
      let(:attribute) { :device_sso }

      context 'is not enabled' do
        let(:current_client_config) { create(:client_config, authentication: :api, shared_sessions: false) }
        let(:expected_error_message) { 'is not enabled' }

        it_behaves_like 'an invalid token exchanger'
      end

      context 'is enabled' do
        it_behaves_like 'a valid token exchanger'
      end
    end
  end

  describe '#perform' do
    context 'when token exchanger is invalid' do
      let(:subject_token) { nil }

      it 'raises an error' do
        expect do
          token_exchanger.perform
        end.to raise_error(SignIn::Errors::TokenExchangerError)
      end
    end

    context 'when token exchanger is valid' do
      let(:session_container) { token_exchanger.perform }
      let(:new_session) { session_container.session }
      let(:new_access_token) { session_container.access_token }
      let(:new_refresh_token) { session_container.refresh_token }
      let(:new_anti_csrf_token) { session_container.anti_csrf_token }
      let(:new_client_config) { session_container.client_config }

      let(:expected_session_handle) { Faker::Internet.uuid }
      let(:expected_client_id) { web_client_config.client_id }
      let(:expected_user_attributes) { current_session.user_attributes }
      let(:expected_refresh_creation) { current_session.refresh_creation }
      let(:expected_parent_refresh_token_hash) { new_refresh_token.parent_refresh_token_hash }
      let(:expected_anti_csrf_token) { new_anti_csrf_token }
      let(:expected_user_uuid) { new_session.user_verification.backing_credential_identifier }

      before do
        allow(SecureRandom).to receive(:uuid).and_return(expected_session_handle)
      end

      context 'a session container is created' do
        it 'is valid' do
          expect(session_container).to be_valid
        end

        context 'and the session' do
          let(:expected_user_account_id) { current_session.user_account_id }
          let(:expected_user_verification_id) { current_session.user_verification_id }
          let(:expected_credential_email) { current_session.credential_email }
          let(:expected_hashed_device_secret) { current_session.hashed_device_secret }
          let(:expected_hashed_refresh_token) { Digest::SHA256.hexdigest(new_refresh_token.parent_refresh_token_hash) }

          let(:expected_refresh_expiration) do
            expected_refresh_creation + new_client_config.refresh_token_duration
          end

          it 'has the expected attributes' do
            expect(new_session).to have_attributes(
              client_id: expected_client_id,
              user_account_id: expected_user_account_id,
              user_verification_id: expected_user_verification_id,
              credential_email: expected_credential_email,
              user_attributes: expected_user_attributes,
              hashed_device_secret: expected_hashed_device_secret,
              refresh_creation: expected_refresh_creation,
              handle: expected_session_handle,
              hashed_refresh_token: expected_hashed_refresh_token,
              refresh_expiration: expected_refresh_expiration
            )
          end
        end

        context 'and the access_token' do
          let(:expected_audience) { SignIn::AccessTokenAudienceGenerator.new(client_config: new_client_config).perform }
          let(:expected_device_secret_hash) { nil }
          let(:expected_refresh_token_has) { Digest::SHA256.hexdigest(new_refresh_token.to_json) }

          it 'has the attributes' do
            expect(new_access_token).to have_attributes(
              session_handle: expected_session_handle,
              refresh_token_hash: expected_refresh_token_has,
              parent_refresh_token_hash: expected_parent_refresh_token_hash,
              anti_csrf_token: expected_anti_csrf_token,
              audience: expected_audience,
              client_id: expected_client_id,
              last_regeneration_time: expected_refresh_creation,
              user_attributes: JSON.parse(expected_user_attributes),
              user_uuid: expected_user_uuid,
              device_secret_hash: expected_device_secret_hash
            )
          end
        end

        context 'and the refresh_token' do
          it 'has the expected attributes' do
            expect(new_refresh_token).to have_attributes(
              session_handle: expected_session_handle,
              parent_refresh_token_hash: expected_parent_refresh_token_hash,
              anti_csrf_token: expected_anti_csrf_token,
              user_uuid: expected_user_uuid
            )
          end
        end

        context 'and the anti_csrf_token' do
          let(:expected_anti_csrf_token) { SecureRandom.hex }

          before do
            allow(SecureRandom).to receive(:hex).and_return(expected_anti_csrf_token)
          end

          it 'is expected' do
            expect(new_anti_csrf_token).to eq(expected_anti_csrf_token)
          end
        end

        context 'and the client_config' do
          let(:expected_client_id) { web_client_config.client_id }

          it 'is expected' do
            expect(new_client_config.client_id).to eq(expected_client_id)
          end
        end
      end
    end
  end
end
