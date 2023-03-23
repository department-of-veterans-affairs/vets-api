# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::RefreshTokenDecryptor do
  describe '#perform' do
    subject { SignIn::RefreshTokenDecryptor.new(encrypted_refresh_token: token_to_decrypt).perform }

    let(:refresh_token) { create(:refresh_token, version:, nonce:) }
    let(:version) { SignIn::Constants::RefreshToken::CURRENT_VERSION }
    let(:nonce) { 'some-nonce' }
    let(:encrypted_refresh_token) { SignIn::RefreshTokenEncryptor.new(refresh_token:).perform }
    let(:token_to_decrypt) { encrypted_refresh_token }

    context 'when version part of encrypted refresh_token string has been changed' do
      let(:edited_version) { 'some-edited-version' }
      let(:token_to_decrypt) do
        encrypted_token_array = encrypted_refresh_token.split('.')
        encrypted_token_array[SignIn::Constants::RefreshToken::VERSION_POSITION] = edited_version
        encrypted_token_array.join('.')
      end
      let(:expected_error) { SignIn::Errors::RefreshVersionMismatchError }
      let(:expected_error_message) { 'Refresh token version is invalid' }

      it 'returns a version mismatch error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when nonce part of encrypted refresh_token string has been changed' do
      let(:edited_nonce) { 'some-edited-nonce' }
      let(:token_to_decrypt) do
        encrypted_token_array = encrypted_refresh_token.split('.')
        encrypted_token_array[SignIn::Constants::RefreshToken::NONCE_POSITION] = edited_nonce
        encrypted_token_array.join('.')
      end
      let(:expected_error) { SignIn::Errors::RefreshNonceMismatchError }
      let(:expected_error_message) { 'Refresh nonce is invalid' }

      it 'returns a nonce mismatch error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when encrypted part of encrypted refresh_token string has been changed' do
      let(:edited_encrypted_part) { 'some-edited-encrypted-part' }
      let(:token_to_decrypt) do
        encrypted_token_array = encrypted_refresh_token.split('.')
        encrypted_token_array[SignIn::Constants::RefreshToken::ENCRYPTED_POSITION] = edited_encrypted_part
        encrypted_token_array.join('.')
      end
      let(:expected_error) { SignIn::Errors::RefreshTokenDecryptionError }
      let(:expected_error_message) { 'Refresh token cannot be decrypted' }
      let(:expected_log) { "[RefreshTokenDecryptor] Token cannot be decrypted, refresh_token: #{token_to_decrypt}" }

      it 'returns an invalid message error' do
        expect(Rails.logger).to receive(:info).with(expected_log)
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when encrypted refresh_token string has not been edited' do
      let(:expected_session_handle) { refresh_token.session_handle }
      let(:expected_user_uuid) { refresh_token.user_uuid }
      let(:expected_parent_refresh_token_hash) { refresh_token.parent_refresh_token_hash }
      let(:expected_anti_csrf_token) { refresh_token.anti_csrf_token }
      let(:expected_nonce) { refresh_token.nonce }
      let(:expected_uuid) { refresh_token.uuid }
      let(:expected_version) { refresh_token.version }

      it 'returns a decrypted refresh token with expected session handle' do
        expect(subject.session_handle).to eq(expected_session_handle)
      end

      it 'returns a decrypted refresh token with expected user uuid' do
        expect(subject.user_uuid).to eq(expected_user_uuid)
      end

      it 'returns a decrypted refresh token with expected parent_refresh_token_hash' do
        expect(subject.parent_refresh_token_hash).to eq(expected_parent_refresh_token_hash)
      end

      it 'returns a decrypted refresh token with expected anti csrf token' do
        expect(subject.anti_csrf_token).to eq(expected_anti_csrf_token)
      end

      it 'returns a decrypted refresh token with expected nonce' do
        expect(subject.nonce).to eq(expected_nonce)
      end

      it 'returns a decrypted refresh token with expected uuid' do
        expect(subject.uuid).to eq(expected_uuid)
      end

      it 'returns a decrypted refresh token with expected version' do
        expect(subject.version).to eq(expected_version)
      end
    end
  end
end
