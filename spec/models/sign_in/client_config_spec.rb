# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ClientConfig, type: :model do
  let(:client_config) do
    create(:client_config,
           client_id:,
           authentication:,
           anti_csrf:,
           redirect_uri:,
           logout_redirect_uri:,
           access_token_duration:,
           access_token_audience:,
           refresh_token_duration:,
           certificates:,
           access_token_attributes:,
           enforced_terms:,
           terms_of_use_url:)
  end
  let(:client_id) { 'some-client-id' }
  let(:authentication) { SignIn::Constants::Auth::API }
  let(:certificates) { [] }
  let(:anti_csrf) { false }
  let(:redirect_uri) { 'some-redirect-uri' }
  let(:logout_redirect_uri) { 'some-logout-redirect-uri' }
  let(:access_token_duration) { SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES }
  let(:access_token_audience) { 'some-access-token-audience' }
  let(:refresh_token_duration) { SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES }
  let(:access_token_attributes) { [] }
  let(:enforced_terms) { SignIn::Constants::Auth::VA_TERMS }
  let(:terms_of_use_url) { 'some-terms-of-use-url' }

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

    describe '#logout_redirect_uri' do
      context 'when logout_redirect_uri is nil' do
        let(:logout_redirect_uri) { nil }

        context 'and authentication is set to cookie auth' do
          let(:authentication) { SignIn::Constants::Auth::COOKIE }
          let(:expected_error_message) { "Validation failed: Logout redirect uri can't be blank" }
          let(:expected_error) { ActiveRecord::RecordInvalid }

          it 'raises validation error' do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end

        context 'and authentication is set to api auth' do
          let(:authentication) { SignIn::Constants::Auth::API }

          it 'does not raise validation error' do
            expect { subject }.not_to raise_error
          end
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

    describe '#access_token_attributes' do
      context 'when access_token_attributes is empty' do
        it 'does not raise a validation error' do
          expect { subject }.not_to raise_error
        end
      end

      context 'when access_token_attributes contain attributes not included in USER_ATTRIBUTES constant' do
        let(:access_token_attributes) { %w[first_name last_name bad_attribute] }
        let(:expected_error_message) { 'Validation failed: Access token attributes is not included in the list' }
        let(:expected_error) { ActiveRecord::RecordInvalid }

        it 'raises a validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when all access_token_attributes are included in USER_ATTRIBUTES constant' do
        let(:access_token_attributes) { SignIn::Constants::AccessToken::USER_ATTRIBUTES }

        it 'does not raise a validation error' do
          expect { subject }.not_to raise_error
        end
      end
    end

    describe '#enforced_terms' do
      context 'when enforced_terms is arbitrary' do
        let(:enforced_terms) { 'some-enforced-terms' }
        let(:expected_error_message) { 'Validation failed: Enforced terms is not included in the list' }
        let(:expected_error) { ActiveRecord::RecordInvalid }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#terms_of_use_url' do
      context 'when enforced_terms is nil' do
        let(:enforced_terms) { nil }

        context 'and terms_of_use_url is nil' do
          let(:terms_of_use_url) { nil }
          let(:expected_error_message) { "Validation failed: Terms of use url can't be blank" }
          let(:expected_error) { ActiveRecord::RecordInvalid }

          it 'does not raise validation error' do
            expect { subject }.not_to raise_error
          end
        end
      end

      context 'when enforced_terms is not nil' do
        let(:enforced_terms) { SignIn::Constants::Auth::VA_TERMS }

        context 'and terms_of_use_url is nil' do
          let(:terms_of_use_url) { nil }
          let(:expected_error_message) { "Validation failed: Terms of use url can't be blank" }
          let(:expected_error) { ActiveRecord::RecordInvalid }

          it 'raises validation error' do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end

        context 'and terms_of_use_url is not nil' do
          let(:terms_of_use_url) { 'some-terms-of-use-url' }

          it 'does not raise validation error' do
            expect { subject }.not_to raise_error
          end
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

  describe '#client_assertion_public_keys' do
    subject { client_config.client_assertion_public_keys }

    let(:certificate) do
      OpenSSL::X509::Certificate.new(File.read('spec/fixtures/sign_in/sample_client.crt'))
    end
    let(:certificates) { [certificate.to_s] }
    let(:client_assertion_public_keys) { [certificate.public_key] }

    it 'expands all certificates in the client config to an array of public keys' do
      expect(subject.first.to_s).to eq(client_assertion_public_keys.first.to_s)
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

    context 'when authentication method is set to mock' do
      let(:authentication) { SignIn::Constants::Auth::MOCK }

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

    context 'when authentication method is set to mock' do
      let(:authentication) { SignIn::Constants::Auth::MOCK }

      it 'returns false' do
        expect(subject).to be(false)
      end
    end
  end

  describe '#va_terms_enforced?' do
    subject { client_config.va_terms_enforced? }

    context 'when enforced terms is set to VA TERMS' do
      let(:enforced_terms) { SignIn::Constants::Auth::VA_TERMS }

      it 'returns true' do
        expect(subject).to be(true)
      end
    end

    context 'when enforced terms is nil' do
      let(:enforced_terms) { nil }

      it 'returns false' do
        expect(subject).to be(false)
      end
    end
  end

  describe '#mock_auth?' do
    subject { client_config.mock_auth? }

    context 'when authentication method is set to mock' do
      let(:authentication) { SignIn::Constants::Auth::MOCK }

      before { allow(Settings).to receive(:vsp_environment).and_return(vsp_environment) }

      context 'and vsp_environment is set to test' do
        let(:vsp_environment) { 'test' }

        it 'returns true' do
          expect(subject).to be(true)
        end
      end

      context 'and vsp_environment is set to localhost' do
        let(:vsp_environment) { 'localhost' }

        it 'returns true' do
          expect(subject).to be(true)
        end
      end

      context 'and vsp_environment is set to development' do
        let(:vsp_environment) { 'development' }

        it 'returns true' do
          expect(subject).to be(true)
        end
      end

      context 'and vsp_environment is set to production' do
        let(:vsp_environment) { 'production' }

        it 'returns false' do
          expect(subject).to be(false)
        end
      end
    end

    context 'when authentication method is set to api' do
      let(:authentication) { SignIn::Constants::Auth::API }

      it 'returns false' do
        expect(subject).to be(false)
      end
    end

    context 'when authentication method is set to cookie' do
      let(:authentication) { SignIn::Constants::Auth::COOKIE }

      it 'returns false' do
        expect(subject).to be(false)
      end
    end
  end
end
