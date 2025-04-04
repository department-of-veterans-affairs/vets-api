# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSSClaim, type: :model do
  let(:user) { create(:user, :accountable) }
  let(:user_account) { create(:user_account) }
  let(:user_verification) { create(:user_verification, user_account:) }

  describe 'associations' do
    it { is_expected.to belong_to(:user_account).optional }
  end

  describe '.for_user' do
    context 'when user has a user_account' do
      it 'returns claims associated with the user account' do
        user_account = create(:user_account)
        create(:user_verification, idme_uuid: user.idme_uuid, user_account:)
        claim = create(:evss_claim, user_uuid: user.uuid, user_account:)
        other_claim = create(:evss_claim, :with_user_account)

        expect(EVSSClaim.for_user(user)).to include(claim)
        expect(EVSSClaim.for_user(user)).not_to include(other_claim)
      end
    end

    context 'when user has no user_account' do
      it 'returns no claims' do
        create(:evss_claim, :with_user_account)
        allow(user).to receive(:user_account).and_return(nil)

        expect(EVSSClaim.for_user(user)).to be_empty
      end
    end
  end

  describe '.claim_for_user_account' do
    it 'returns claims for the given user account' do
      claim = create(:evss_claim, :with_user_account, user_account:)
      other_claim = create(:evss_claim, :with_user_account)

      expect(EVSSClaim.claim_for_user_account(user_account)).to include(claim)
      expect(EVSSClaim.claim_for_user_account(user_account)).not_to include(other_claim)
    end

    it 'returns no claims when user_account is nil' do
      create(:evss_claim, :with_user_account)
      expect(EVSSClaim.claim_for_user_account(nil)).to be_empty
    end
  end

  describe 'user_account association' do
    it 'allows creating claims with or without user_account' do
      claim_without_account = EVSSClaim.create(
        user_uuid: user.uuid,
        evss_id: 123,
        data: { 'status' => 'PENDING' }
      )
      expect(claim_without_account).to be_valid

      claim_with_account = EVSSClaim.create(
        user_uuid: user.uuid,
        evss_id: 124,
        user_account: user.user_account,
        data: { 'status' => 'PENDING' }
      )
      expect(claim_with_account).to be_valid
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user_uuid) }
    it { is_expected.to validate_presence_of(:data) }

    it 'requires user_uuid' do
      claim = EVSSClaim.new(data: { 'status' => 'PENDING' })
      expect(claim).not_to be_valid
      expect(claim.errors[:user_uuid]).to include("can't be blank")
    end

    it 'requires data' do
      claim = EVSSClaim.new(user_uuid: user.uuid)
      expect(claim).not_to be_valid
      expect(claim.errors[:data]).to include("can't be blank")
    end
  end
end
