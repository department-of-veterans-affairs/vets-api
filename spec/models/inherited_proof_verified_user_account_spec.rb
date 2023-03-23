# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InheritedProofVerifiedUserAccount, type: :model do
  let(:inherited_proof_verified_user_account) do
    create(:inherited_proof_verified_user_account,
           user_account:)
  end
  let(:user_account) { create(:user_account) }

  describe 'validations' do
    describe '#user_account' do
      subject { inherited_proof_verified_user_account.user_account }

      context 'when user_account is nil' do
        let(:user_account) { nil }
        let(:expected_error_message) { "Validation failed: User account must exist, User account can't be blank" }

        it 'raises validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end

      context 'when user_account is not unique' do
        let!(:previous_inherited_proof_verified_user_account) do
          create(:inherited_proof_verified_user_account,
                 user_account:)
        end
        let(:expected_error_message) { 'Validation failed: User account has already been taken' }

        it 'raises validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end
    end
  end
end
