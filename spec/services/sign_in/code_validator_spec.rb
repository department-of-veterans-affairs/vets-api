# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::CodeValidator do
  describe '#perform' do
    subject do
      SignIn::CodeValidator.new(code: code,
                                code_verifier: code_verifier,
                                grant_type: grant_type).perform
    end

    let(:code) { 'some-code' }
    let(:code_verifier) { 'some-code-verifier' }
    let(:grant_type) { 'some-grant-type' }

    context 'when code container that matches code does not exist' do
      let(:code) { 'some-arbitrary-code' }
      let(:expected_error) { SignIn::Errors::CodeInvalidError }

      it 'raises a code invalid error' do
        expect { subject }.to raise_exception(expected_error)
      end
    end

    context 'when code does match an existing code container' do
      let!(:code_container) do
        create(:code_container,
               code: code_container_code,
               code_challenge: code_challenge,
               user_account_uuid: user_account_uuid)
      end
      let(:code_container_code) { code }
      let(:code_challenge) { 'some-code-challenge' }
      let(:user_account_uuid) { 'some-user-account-uuid' }

      context 'and code verifier does not match code challenge in code container' do
        let(:code_verifier) { 'some-arbitrary-code-verifier' }
        let(:expected_error) { SignIn::Errors::CodeChallengeMismatchError }

        it 'raises a code challenge mismatch error' do
          expect { subject }.to raise_exception(expected_error)
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

          it 'raises a grant type value error' do
            expect { subject }.to raise_exception(expected_error)
          end
        end

        context 'and grant type does match the supported grant type' do
          let(:grant_type) { SignIn::Constants::Auth::GRANT_TYPE }

          context 'and user account uuid in code container does not match with a user account' do
            let(:user_account_uuid) { 'some-arbitrary-user-account-uuid' }
            let(:expected_error) { ActiveRecord::RecordNotFound }
            let(:expected_error_message) { "Couldn't find UserAccount with 'id'=#{user_account_uuid}" }

            it 'raises a user account not found error' do
              expect { subject }.to raise_exception(expected_error, expected_error_message)
            end
          end

          context 'and user account uuid in code condainter does match an existing user account' do
            let(:user_account) { create(:user_account) }
            let(:user_account_uuid) { user_account.id }

            it 'returns the expected user account' do
              expect(subject).to eq(user_account)
            end
          end
        end
      end

      it 'destroys the found code container regardless of errors raised' do
        expect { try(subject) }.to raise_error.and change { SignIn::CodeContainer.find(code_container_code) }.to(nil)
      end
    end
  end
end
