# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserCredentialEmail, type: :model do
  subject do
    create(:user_credential_email,
           user_verification:,
           credential_email:)
  end

  let(:user_verification) { create(:user_verification) }
  let(:credential_email) { 'some-credential-email' }

  describe 'validations' do
    context 'when user_verification is nil' do
      let(:user_verification) { nil }
      let(:expected_error_message) { 'Validation failed: User verification must exist' }
      let(:expected_error) { ActiveRecord::RecordInvalid }

      it 'raises validation error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when credential_email is nil' do
      let(:credential_email) { nil }
      let(:expected_error_message) { "Validation failed: Credential email ciphertext can't be blank" }
      let(:expected_error) { ActiveRecord::RecordInvalid }

      it 'raises validation error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end
  end
end
