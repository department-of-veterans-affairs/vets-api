# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CodeValidator do
  describe '#perform' do
    subject do
      SignIn::CodeValidator.new(code:,
                                code_verifier:,
                                grant_type:).perform
    end

    let(:code) { 'some-code' }
    let(:code_verifier) { 'some-code-verifier' }
    let(:grant_type) { 'some-grant-type' }

    context 'when code container that matches code does not exist' do
      let(:code) { 'some-arbitrary-code' }
      let(:expected_error) { SignIn::Errors::CodeInvalidError }
      let(:expected_error_message) { 'Code is not valid' }

      it 'raises a code invalid error' do
        expect { subject }.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'when code does match an existing code container' do
      let!(:code_container) do
        create(:code_container,
               code: code_container_code,
               code_challenge:,
               user_verification_id:)
      end
      let(:code_container_code) { code }
      let(:code_challenge) { 'some-code-challenge' }
      let(:user_verification_id) { 'some-user-verification-uuid' }

      context 'and code verifier does not match code challenge in code container' do
        let(:code_verifier) { 'some-arbitrary-code-verifier' }
        let(:expected_error) { SignIn::Errors::CodeChallengeMismatchError }
        let(:expected_error_message) { 'Code Verifier is not valid' }

        it 'raises a code challenge mismatch error' do
          expect { subject }.to raise_exception(expected_error, expected_error_message)
        end
      end

      context 'and code verifier does match the code challenge in the code container' do
        let(:code_verifier) { 'some-code-verifier' }
        let(:code_challenge) do
          unsafe_code_challenge = Digest::SHA256.base64digest(code_verifier)
          Base64.urlsafe_encode64(Base64.urlsafe_decode64(unsafe_code_challenge.to_s), padding: false)
        end

        context 'and grant type does not match the supported grant type' do
          let(:grant_type) { 'some-arbitrary-grant-type' }
          let(:expected_error) { SignIn::Errors::GrantTypeValueError }
          let(:expected_error_message) { 'Grant Type is not valid' }

          it 'raises a grant type value error' do
            expect { subject }.to raise_exception(expected_error, expected_error_message)
          end
        end

        context 'and grant type does match the supported grant type' do
          let(:grant_type) { SignIn::Constants::Auth::GRANT_TYPE }

          context 'and user verification uuid in code container does not match with a user verification' do
            let(:user_verification_id) { 'some-arbitrary-user-verification-uuid' }
            let(:expected_error) { ActiveRecord::RecordNotFound }
            let(:expected_error_message) { "Couldn't find UserVerification with 'id'=#{user_verification_id}" }

            it 'raises a user verification not found error' do
              expect { subject }.to raise_exception(expected_error, expected_error_message)
            end
          end

          context 'and user verification uuid in code condainter does match an existing user verification' do
            let(:user_verification) { create(:user_verification) }
            let(:user_verification_id) { user_verification.id }
            let(:expected_email) { code_container.credential_email }
            let(:expected_client_config) { SignIn::ClientConfig.find_by(client_id: code_container.client_id) }
            let(:expected_validated_credential) do
              SignIn::ValidatedCredential.new(user_verification:,
                                              credential_email: expected_email,
                                              client_id: expected_client_id)
            end

            it 'returns a validated credential object with expected attributes' do
              expect(subject).to have_attributes(credential_email: expected_email,
                                                 client_config: expected_client_config,
                                                 user_verification:)
            end

            it 'returns a validated credential object with expected credential email' do
              expect(subject.credential_email).to eq(expected_email)
            end

            it 'returns a validated credential object with expected client_config' do
              expect(subject.client_config).to eq(expected_client_config)
            end
          end
        end
      end

      it 'destroys the found code container regardless of errors raised' do
        expect { try(subject) }.to raise_error(StandardError)
          .and change { SignIn::CodeContainer.find(code_container_code) }.to(nil)
      end
    end
  end
end
