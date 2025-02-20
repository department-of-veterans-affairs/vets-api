# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::SessionSpawner do
  let(:session_spawner) do
    SignIn::SessionSpawner.new(current_session:, new_session_client_config:)
  end

  describe '#perform' do
    subject { session_spawner.perform }

    let(:current_session) do
      create(:oauth_session, handle: current_session_handle, user_verification:, refresh_creation:)
    end
    let(:refresh_creation) { 5.minutes.ago }
    let(:current_session_handle) { 'edd4c2fc-d776-4596-8dce-71a9848e15e0' }
    let(:user_uuid) { current_session.user_verification.backing_credential_identifier }
    let(:user_verification) { create(:user_verification, locked:) }
    let(:user_account) { user_verification.user_account }
    let(:locked) { false }
    let(:new_session_client_config) do
      create(:client_config, client_id:, refresh_token_duration:, access_token_attributes:, enforced_terms:)
    end
    let(:client_id) { 'some-client-id' }
    let(:refresh_token_duration) { SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES }
    let(:access_token_attributes) { %w[first_name last_name email all_emails] }
    let(:enforced_terms) { nil }
    let(:device_sso) { false }

    before { Timecop.freeze(Time.zone.now.floor) }

    after { Timecop.return }

    context 'expected credential_lock validation' do
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
        let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }

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
      let(:expected_created_time) { current_session.refresh_creation }
      let(:expected_token_uuid) { SecureRandom.uuid }
      let(:expected_parent_token_uuid) { SecureRandom.uuid }
      let(:expected_user_uuid) { user_uuid }
      let(:expected_last_regeneration_time) { Time.zone.now }
      let(:expected_expiration_time) { expected_last_regeneration_time + refresh_token_duration }
      let(:expected_user_attributes) { JSON.parse(current_session.user_attributes) }
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
      let(:expected_hashed_device_secret) { current_session.hashed_device_secret }
      let(:expected_credential_email) { current_session.credential_email }

      before do
        allow(SecureRandom).to receive_messages(hex: stubbed_random_number, uuid: expected_handle)
      end

      it 'returns a Session Container with expected OAuth Session and fields' do
        session = subject.session

        expect(session.user_account).to eq(user_account)
        expect(session.user_verification).to eq(user_verification)
        expect(session.client_id).to eq(client_id)
        expect(session.credential_email).to eq(expected_credential_email)
        expect(session.handle).to eq(expected_handle)
        expect(session.hashed_refresh_token).to eq(expected_double_hashed_parent_refresh_token)
        expect(session.refresh_creation).to eq(expected_created_time)
        expect(session.user_attributes_hash.values).to eq(expected_user_attributes.values)
        expect(session.hashed_device_secret).to eq(expected_hashed_device_secret)
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
      end

      it 'returns a Session Container with expected Access Token and fields' do
        access_token = subject.access_token
        expect(access_token.session_handle).to eq(expected_handle)
        expect(access_token.anti_csrf_token).to eq(expected_anti_csrf_token)
        expect(access_token.user_uuid).to eq(expected_user_uuid)
        expect(access_token.refresh_token_hash).to eq(expected_refresh_token_hash)
        expect(access_token.parent_refresh_token_hash).to eq(expected_parent_refresh_token_hash)
        expect(access_token.last_regeneration_time).to eq(expected_last_regeneration_time)
        expect(access_token.device_secret_hash).to be_nil
        expect(access_token.user_attributes).to eq(JSON.parse(current_session.user_attributes))
      end
    end
  end
end
