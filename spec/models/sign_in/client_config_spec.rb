# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ClientConfig, type: :model do
  let(:client_config) do
    create(:client_config,
           client_id: client_id,
           authentication: authentication,
           anti_csrf: anti_csrf,
           redirect_uri: redirect_uri,
           access_token_duration: access_token_duration,
           access_token_audience: access_token_audience,
           refresh_token_duration: refresh_token_duration)
  end
  let(:client_id) { 'some-client-id' }
  let(:authentication) { SignIn::Constants::Auth::API }
  let(:anti_csrf) { false }
  let(:redirect_uri) { 'some-redirect-uri' }
  let(:access_token_duration) { SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES }
  let(:access_token_audience) { 'some-access-token-audience' }
  let(:refresh_token_duration) { SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES }

  describe 'validations' do
    subject { client_config }

    describe '#client_id' do
      context 'when client_id is nil' do
        let(:client_id) { nil }
        let(:expected_error_message) { "Validation failed: Client can't be blank" }
        let(:expected_error) { ActiveRecord::RecordInvalid }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when client_id is not unique' do
        let!(:old_client_config) { create(:client_config) }
        let(:client_id) { old_client_config.client_id }
        let(:expected_error_message) { 'Validation failed: Client has already been taken' }
        let(:expected_error) { ActiveRecord::RecordInvalid }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#authentication' do
      context 'when authentication is nil' do
        let(:authentication) { nil }
        let(:expected_error_message) do
          "Validation failed: Authentication can't be blank, Authentication is not included in the list"
        end
        let(:expected_error) { ActiveRecord::RecordInvalid }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when authentication is arbitrary' do
        let(:authentication) { 'some-authentication' }
        let(:expected_error_message) { 'Validation failed: Authentication is not included in the list' }
        let(:expected_error) { ActiveRecord::RecordInvalid }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#refresh_token_duration' do
      context 'when refresh_token_duration is nil' do
        let(:refresh_token_duration) { nil }
        let(:expected_error_message) do
          "Validation failed: Refresh token duration can't be blank, Refresh token duration is not included in the list"
        end
        let(:expected_error) { ActiveRecord::RecordInvalid }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when refresh_token_duration is an arbitrary interval' do
        let(:refresh_token_duration) { 300.days }
        let(:expected_error_message) { 'Validation failed: Refresh token duration is not included in the list' }
        let(:expected_error) { ActiveRecord::RecordInvalid }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#access_token_duration' do
      context 'when access_token_duration is nil' do
        let(:access_token_duration) { nil }
        let(:expected_error_message) do
          "Validation failed: Access token duration can't be blank, Access token duration is not included in the list"
        end
        let(:expected_error) { ActiveRecord::RecordInvalid }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when access_token_duration is an arbitrary interval' do
        let(:access_token_duration) { 300.days }
        let(:expected_error_message) { 'Validation failed: Access token duration is not included in the list' }
        let(:expected_error) { ActiveRecord::RecordInvalid }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#redirect_uri' do
      context 'when redirect_uri is nil' do
        let(:redirect_uri) { nil }
        let(:expected_error_message) { "Validation failed: Redirect uri can't be blank" }
        let(:expected_error) { ActiveRecord::RecordInvalid }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#anti_csrf' do
      context 'when anti_csrf is nil' do
        let(:anti_csrf) { nil }
        let(:expected_error_message) { 'Validation failed: Anti csrf is not included in the list' }
        let(:expected_error) { ActiveRecord::RecordInvalid }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end
  end

  describe '.valid_client_id?' do
    subject { SignIn::ClientConfig.valid_client_id?(client_id: check_client_id) }

    context 'when client_id matches a ClientConfig entry' do
      let(:check_client_id) { client_config.client_id }

      it 'returns true' do
        expect(subject).to be(true)
      end
    end

    context 'when client_id does not match a ClientConfig entry' do
      let(:check_client_id) { 'some-client-id' }

      it 'returns false' do
        expect(subject).to be(false)
      end
    end
  end

  describe '#cookie_auth?' do
    subject { client_config.cookie_auth? }

    context 'when authentication method is set to cookie' do
      let(:authentication) { SignIn::Constants::Auth::COOKIE }

      it 'returns true' do
        expect(subject).to be(true)
      end
    end

    context 'when authentication method is set to api' do
      let(:authentication) { SignIn::Constants::Auth::API }

      it 'returns false' do
        expect(subject).to be(false)
      end
    end
  end

  describe '#api_auth?' do
    subject { client_config.api_auth? }

    context 'when authentication method is set to cookie' do
      let(:authentication) { SignIn::Constants::Auth::COOKIE }

      it 'returns false' do
        expect(subject).to be(false)
      end
    end

    context 'when authentication method is set to api' do
      let(:authentication) { SignIn::Constants::Auth::API }

      it 'returns true' do
        expect(subject).to be(true)
      end
    end
  end
end
