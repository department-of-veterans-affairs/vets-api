# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::SessionCreator do
  let(:session_creator) do
    SignIn::SessionCreator.new(validated_credential:)
  end

  describe '#perform' do
    subject { session_creator.perform }

    context 'when input object is a ValidatedCredential' do
      let(:validated_credential) { create(:validated_credential, client_config:, device_sso:) }
      let(:user_uuid) { validated_credential.user_verification.backing_credential_identifier }
      let(:client_id) { client_config.client_id }
      let(:client_config) { create(:client_config, refresh_token_duration:, access_token_attributes:, enforced_terms:) }
      let(:refresh_token_duration) { SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES }
      let(:access_token_attributes) { %w[first_name last_name email] }
      let(:enforced_terms) { nil }
      let(:device_sso) { false }

      context 'expected credential_lock validation' do
        let(:validated_credential) { create(:validated_credential, client_config:, user_verification:) }
        let(:user_verification) { create(:user_verification, locked:) }
        let(:locked) { false }
        let(:expected_error) { SignIn::Errors::CredentialLockedError }
        let(:expected_error_message) { 'Credential is locked' }

        context 'when the UserVerification is not locked' do
          it 'does not return an error' do
            expect { subject }.not_to raise_error
          end
        end

        context 'when the UserVerification is locked' do
          let(:locked) { true }

          it 'returns a credential locked error' do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end
      end

      context 'when client config is set to enforce terms' do
        let(:enforced_terms) { SignIn::Constants::Auth::VA_TERMS }

        context 'and user has accepted current terms of use' do
          let!(:terms_of_use_agreement) do
            create(:terms_of_use_agreement, user_account: validated_credential.user_verification.user_account)
          end

          it 'does not return an error' do
            expect { subject }.not_to raise_error
          end
        end

        context 'and user has not accepted current terms of use' do
          let(:expected_error) { SignIn::Errors::TermsOfUseNotAcceptedError }
          let(:expected_error_message) { 'Terms of Use has not been accepted' }

          it 'returns a terms of use not accepted error' do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end
      end

      context 'expected anti_csrf_token' do
        let(:expected_anti_csrf_token) { 'some-anti-csrf-token' }

        before do
          allow(SecureRandom).to receive(:hex).and_return(expected_anti_csrf_token)
        end

        it 'returns a Session Container with expected anti_csrf_token' do
          expect(subject.anti_csrf_token).to be(expected_anti_csrf_token)
        end
      end

      context 'expected session' do
        let(:expected_handle) { SecureRandom.uuid }
        let(:expected_created_time) { Time.zone.now.round(3) }
        let(:expected_token_uuid) { SecureRandom.uuid }
        let(:expected_parent_token_uuid) { SecureRandom.uuid }
        let(:expected_user_uuid) { user_uuid }
        let(:expected_expiration_time) { Time.zone.now + refresh_token_duration }
        let(:expected_user_attributes) { validated_credential.user_attributes }
        let(:expected_double_hashed_parent_refresh_token) do
          Digest::SHA256.hexdigest(parent_refresh_token_hash)
        end
        let(:stubbed_random_number) { 'some-stubbed-random-number' }
        let(:parent_refresh_token_hash) { Digest::SHA256.hexdigest(parent_refresh_token.to_json) }
        let(:refresh_token) do
          create(:refresh_token,
                 uuid: expected_token_uuid,
                 user_uuid: expected_user_uuid,
                 parent_refresh_token_hash:,
                 session_handle: expected_handle,
                 nonce: stubbed_random_number,
                 anti_csrf_token: stubbed_random_number)
        end
        let(:parent_refresh_token) do
          create(:refresh_token,
                 uuid: expected_parent_token_uuid,
                 user_uuid: expected_user_uuid,
                 parent_refresh_token_hash: nil,
                 session_handle: expected_handle,
                 nonce: stubbed_random_number,
                 anti_csrf_token: stubbed_random_number)
        end

        before do
          allow(SecureRandom).to receive_messages(hex: stubbed_random_number, uuid: expected_handle)
          allow(Time.zone).to receive(:now).and_return(expected_created_time)
        end

        context 'when validated credential is set up to enable device_sso' do
          let(:device_sso) { true }
          let(:expected_device_secret) { 'some-expected-device-secret' }

          before { allow(Digest::SHA256).to receive(:hexdigest).and_return(expected_device_secret) }

          it 'returns expected device_secret field on access token' do
            expect(subject.session.hashed_device_secret).to eq(expected_device_secret)
          end
        end

        context 'when validated credential is not set up to enable device_sso' do
          let(:device_sso) { false }

          it 'returns nil for device_secret field on access token' do
            expect(subject.session.hashed_device_secret).to be_nil
          end
        end

        it 'returns a Session Container with expected OAuth Session and fields' do
          session = subject.session
          expect(session.handle).to eq(expected_handle)
          expect(session.hashed_refresh_token).to eq(expected_double_hashed_parent_refresh_token)
          expect(session.refresh_creation).to eq(expected_created_time)
          expect(session.client_id).to eq(client_id)
          expect(session.user_attributes_hash.values).to eq(expected_user_attributes.values)
        end

        context 'and client is configured for a short token expiration' do
          let(:refresh_token_duration) { SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES }

          it 'creates a session with the expected expiration time' do
            expect(subject.session.refresh_expiration).to eq(expected_expiration_time)
          end
        end

        context 'and client is configured for a long token expiration' do
          let(:refresh_token_duration) { SignIn::Constants::RefreshToken::VALIDITY_LENGTH_LONG_DAYS }

          it 'creates a session with the expected expiration time' do
            expect(subject.session.refresh_expiration).to eq(expected_expiration_time)
          end
        end
      end

      context 'expected refresh_token' do
        let(:expected_handle) { SecureRandom.uuid }
        let(:expected_user_uuid) { user_uuid }
        let(:expected_token_uuid) { SecureRandom.uuid }
        let(:expected_parent_token_uuid) { SecureRandom.uuid }
        let(:expected_anti_csrf_token) { stubbed_random_number }
        let(:stubbed_random_number) { 'some-stubbed-random-number' }
        let(:expected_parent_refresh_token_hash) { Digest::SHA256.hexdigest(parent_refresh_token.to_json) }
        let(:refresh_token) do
          create(:refresh_token,
                 uuid: expected_token_uuid,
                 user_uuid: expected_user_uuid,
                 parent_refresh_token_hash:,
                 session_handle: expected_handle,
                 nonce: stubbed_random_number,
                 anti_csrf_token: stubbed_random_number)
        end
        let(:parent_refresh_token) do
          create(:refresh_token,
                 uuid: expected_parent_token_uuid,
                 user_uuid: expected_user_uuid,
                 parent_refresh_token_hash: nil,
                 session_handle: expected_handle,
                 nonce: stubbed_random_number,
                 anti_csrf_token: stubbed_random_number)
        end

        before do
          allow(SecureRandom).to receive_messages(hex: stubbed_random_number, uuid: expected_handle)
        end

        it 'returns a Session Container with expected Refresh Token and fields' do
          refresh_token = subject.refresh_token
          expect(refresh_token.session_handle).to eq(expected_handle)
          expect(refresh_token.anti_csrf_token).to eq(expected_anti_csrf_token)
          expect(refresh_token.user_uuid).to eq(expected_user_uuid)
          expect(refresh_token.parent_refresh_token_hash).to eq(expected_parent_refresh_token_hash)
        end
      end

      context 'expected access_token' do
        let(:expected_handle) { SecureRandom.uuid }
        let(:expected_user_uuid) { user_uuid }
        let(:expected_token_uuid) { SecureRandom.uuid }
        let(:expected_parent_token_uuid) { SecureRandom.uuid }
        let(:expected_anti_csrf_token) { stubbed_random_number }
        let(:stubbed_random_number) { 'some-stubbed-random-number' }
        let(:expected_refresh_token_hash) { Digest::SHA256.hexdigest(refresh_token.to_json) }
        let(:refresh_token) do
          create(:refresh_token,
                 uuid: expected_token_uuid,
                 user_uuid: expected_user_uuid,
                 parent_refresh_token_hash: expected_parent_refresh_token_hash,
                 session_handle: expected_handle,
                 nonce: stubbed_random_number,
                 anti_csrf_token: expected_anti_csrf_token)
        end
        let(:parent_refresh_token) do
          create(:refresh_token,
                 uuid: expected_parent_token_uuid,
                 user_uuid: expected_user_uuid,
                 parent_refresh_token_hash: nil,
                 session_handle: expected_handle,
                 nonce: stubbed_random_number,
                 anti_csrf_token: expected_anti_csrf_token)
        end
        let(:expected_parent_refresh_token_hash) { Digest::SHA256.hexdigest(parent_refresh_token.to_json) }
        let(:expected_last_regeneration_time) { Time.zone.now }

        before do
          allow(SecureRandom).to receive_messages(hex: stubbed_random_number, uuid: expected_handle)
          allow(Time.zone).to receive(:now).and_return(expected_last_regeneration_time)
        end

        context 'when validated credential is set up to enable device_sso' do
          let(:device_sso) { true }
          let(:expected_device_secret) { 'some-expected-device-secret' }

          before { allow(Digest::SHA256).to receive(:hexdigest).and_return(expected_device_secret) }

          it 'returns expected device_secret field on access token' do
            expect(subject.access_token.device_secret_hash).to eq(expected_device_secret)
          end
        end

        context 'when validated credential is not set up to enable device_sso' do
          let(:device_sso) { false }

          it 'returns nil for device_secret field on access token' do
            expect(subject.access_token.device_secret_hash).to be_nil
          end
        end

        it 'returns a Session Container with expected Access Token and fields' do
          access_token = subject.access_token
          expect(access_token.session_handle).to eq(expected_handle)
          expect(access_token.anti_csrf_token).to eq(expected_anti_csrf_token)
          expect(access_token.user_uuid).to eq(expected_user_uuid)
          expect(access_token.refresh_token_hash).to eq(expected_refresh_token_hash)
          expect(access_token.parent_refresh_token_hash).to eq(expected_parent_refresh_token_hash)
          expect(access_token.last_regeneration_time).to eq(expected_last_regeneration_time)
        end

        context 'expected user attributes on access token' do
          context 'when attributes are present in the ClientConfig access_token_attributes' do
            it 'includes those attributes in the access token' do
              user_attributes = subject.access_token.user_attributes
              expect(user_attributes['first_name']).to eq(validated_credential.user_attributes[:first_name])
              expect(user_attributes['last_name']).to eq(validated_credential.user_attributes[:last_name])
              expect(user_attributes['email']).to eq(validated_credential.user_attributes[:email])
            end
          end

          context 'when one or more attributes are not present in the ClientConfig access_token_attributes' do
            let(:access_token_attributes) { %w[email] }

            it 'does not include those attributes in the access token' do
              user_attributes = subject.access_token.user_attributes

              expect(user_attributes['first_name']).to be_nil
              expect(user_attributes['last_name']).to be_nil
              expect(user_attributes['email']).to eq(validated_credential.user_attributes[:email])
            end
          end

          context 'when no attributes are present in the ClientConfig access_token_attributes' do
            let(:access_token_attributes) { [] }

            it 'sets an empty hash object in the access token' do
              expect(subject.access_token.user_attributes).to eq({})
            end
          end
        end
      end

      context 'when validated credential is set up to enable device_sso' do
        let(:device_sso) { true }
      end

      context 'when validated credential is not set up to enable device_sso' do
        let(:device_sso) { false }
      end

      context 'when the validated_credential has a web_sso_session' do
        let(:web_sso_session) { create(:oauth_session) }
        let(:validated_credential) do
          create(:validated_credential, client_config:, device_sso:, web_sso_session_id: web_sso_session.id)
        end

        it 'creates a new session with refresh_creation as the web_sso_creation' do
          expect(subject.session.refresh_creation).to eq(web_sso_session.refresh_creation)
        end

        it 'sets the web_sso_client to true in the session container' do
          expect(subject.web_sso_client).to be(true)
        end
      end
    end
  end
end
