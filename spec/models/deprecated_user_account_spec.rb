# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DeprecatedUserAccount, type: :model do
  let(:deprecated_user_account) do
    create(:deprecated_user_account, user_verification:, user_account:)
  end
  let(:user_verification) { create(:user_verification) }
  let(:user_account) { create(:user_account) }

  describe 'validations' do
    describe '#user_account' do
      subject { deprecated_user_account.user_account }

      context 'when user_account is nil' do
        let(:user_account) { nil }
        let(:expected_error_message) { 'Validation failed: User account must exist' }

        it 'raises a validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end

      context 'when user_account is not nil' do
        let(:user_account) { create(:user_account) }

        it 'returns given user_account' do
          expect(subject).to eq(user_account)
        end
      end
    end

    describe '#user_verification' do
      subject { deprecated_user_account.user_verification }

      context 'when user_verification is nil' do
        let(:user_verification) { nil }
        let(:expected_error_message) do
          'Validation failed: User verification must exist'
        end

        it 'raises a validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end

      context 'when user_verification is not nil' do
        let(:user_verification) { create(:user_verification) }

        it 'returns given user_verification' do
          expect(subject).to eq(user_verification)
        end
      end
    end
  end
end
