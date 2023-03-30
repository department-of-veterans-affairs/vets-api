# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::RefreshTokenEncryptor do
  describe '#perform' do
    subject { SignIn::RefreshTokenEncryptor.new(refresh_token:).perform }

    let(:refresh_token) { create(:refresh_token, version:, nonce:) }
    let(:serialized_refresh_token) { refresh_token.to_json }
    let(:version) { SignIn::Constants::RefreshToken::CURRENT_VERSION }
    let(:nonce) { 'some-nonce' }

    context 'when input object does not have a version attribute' do
      let(:refresh_token) { OpenStruct.new({ data: 'some-data', nonce: }) }
      let(:expected_error) { SignIn::Errors::RefreshTokenMalformedError }

      it 'raises a RefreshTokenMalformedError' do
        expect { subject }.to raise_exception(expected_error)
      end
    end

    context 'when input object does not have a nonce attribute' do
      let(:refresh_token) { OpenStruct.new({ data: 'some-data', version: }) }
      let(:expected_error) { SignIn::Errors::RefreshTokenMalformedError }
      let(:expected_error_message) { 'Refresh token is malformed' }

      it 'raises a RefreshTokenMalformedError' do
        expect { subject }.to raise_exception(expected_error)
      end
    end

    context 'when input object is a RefreshToken' do
      let(:expected_encrypted_component) { 'some-encrypted-component' }
      let(:expected_nonce_component) { nonce }
      let(:expected_version_component) { version }

      before do
        allow_any_instance_of(KmsEncrypted::Box).to receive(:encrypt)
          .with(serialized_refresh_token)
          .and_return(expected_encrypted_component)
      end

      it 'returns a string with an encrypted component' do
        encrypted_component = subject.split('.')[SignIn::Constants::RefreshToken::ENCRYPTED_POSITION]
        expect(encrypted_component).to eq(expected_encrypted_component)
      end

      it 'returns a string with a nonce component' do
        nonce_component = subject.split('.')[SignIn::Constants::RefreshToken::NONCE_POSITION]
        expect(nonce_component).to eq(expected_nonce_component)
      end

      it 'returns a string with a version component' do
        version_component = subject.split('.')[SignIn::Constants::RefreshToken::VERSION_POSITION]
        expect(version_component).to eq(expected_version_component)
      end
    end
  end
end
