# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAcceptableVerifiedCredential, type: :model do
  subject do
    create(:user_acceptable_verified_credential,
           user_account:,
           acceptable_verified_credential_at:,
           idme_verified_credential_at:)
  end

  let(:user_account) { create(:user_account) }
  let(:acceptable_verified_credential_at) { nil }
  let(:idme_verified_credential_at) { nil }

  describe 'validations' do
    context 'when user_account is nil' do
      let(:user_account) { nil }
      let(:expected_error_message) { 'Validation failed: User account must exist' }
      let(:expected_error) { ActiveRecord::RecordInvalid }

      it 'raises validation error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end
  end
end
