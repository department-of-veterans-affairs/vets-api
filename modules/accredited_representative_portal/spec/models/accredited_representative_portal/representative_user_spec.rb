# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::RepresentativeUser, type: :model do
  describe 'validations' do
    context 'valid'
    context 'when all required attributes are present' do
      let(:representative_user) { build(:representative_user) }

      it 'is valid' do
        expect(representative_user).to be_valid
      end
    end
  end

  context 'invalid' do
    let(:expected_error_message) { "can't be blank" }

    context 'when uuid is missing' do
      let(:representative_user) { build(:representative_user, uuid: nil) }

      it 'is invalid' do
        expect(representative_user).not_to be_valid
        expect(representative_user.errors[:uuid]).to include(expected_error_message)
      end
    end

    context 'when email is missing' do
      let(:representative_user) { build(:representative_user, email: nil) }

      it 'is invalid' do
        expect(representative_user).not_to be_valid
        expect(representative_user.errors[:email]).to include(expected_error_message)
      end
    end

    context 'when first name is missing' do
      let(:representative_user) { build(:representative_user, first_name: nil) }

      it 'is invalid' do
        expect(representative_user).not_to be_valid
        expect(representative_user.errors[:first_name]).to include(expected_error_message)
      end
    end

    context 'when last name is missing' do
      let(:representative_user) { build(:representative_user, last_name: nil) }

      it 'is invalid' do
        expect(representative_user).not_to be_valid
        expect(representative_user.errors[:last_name]).to include(expected_error_message)
      end
    end

    context 'when icn is missing' do
      let(:representative_user) { build(:representative_user, icn: nil) }

      it 'is invalid' do
        expect(representative_user).not_to be_valid
        expect(representative_user.errors[:icn]).to include(expected_error_message)
      end
    end

    context 'when user_account_uuid is missing' do
      let(:representative_user) { build(:representative_user, user_account_uuid: nil) }

      it 'is invalid' do
        expect(representative_user).not_to be_valid
        expect(representative_user.errors[:user_account_uuid]).to include(expected_error_message)
      end
    end
  end

  describe 'alias attributes' do
    let(:icn_value) { SecureRandom.hex(10) }
    let(:representative_user) { build(:representative_user, icn: icn_value) }

    it 'aliases icn to mhv_icn' do
      expect(representative_user.mhv_icn).to eq(icn_value)
    end
  end

  describe 'Redis interactions' do
    let!(:representative_user) { create(:representative_user) }

    before { representative_user.save! }

    it 'saves and retrieves the model from Redis' do
      retrieved = AccreditedRepresentativePortal::RepresentativeUser.find(representative_user.uuid)
      expect(retrieved).to be_a(AccreditedRepresentativePortal::RepresentativeUser)
      expect(retrieved.uuid).to eq(representative_user.uuid)
    end
  end

  describe '#flipper_id' do
    let(:representative_user) { build(:representative_user) }

    it 'returns a unique identifier of email' do
      expect(representative_user.flipper_id).to eq(representative_user.email)
    end
  end

  describe '#user_account' do
    let(:user_account) { AccreditedRepresentativePortal::RepresentativeUserAccount.find(create(:user_account).id) }
    let(:representative_user) { build(:representative_user, user_account_uuid: user_account.id) }

    it 'returns expected user_account' do
      expect(representative_user.user_account).to eq(user_account)
    end
  end
end
