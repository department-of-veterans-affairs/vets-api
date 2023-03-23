# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MHVOptInFlag do
  subject { described_class.new(params) }

  let(:params) { { user_account_id: account_uuid, feature: } }
  let(:user_verification) { create(:user_verification) }
  let(:user_account) { user_verification.user_account }
  let(:account_uuid) { user_account.id }
  let(:feature) { 'secure_messaging' }

  it 'populates passed-in attributes' do
    expect(subject.user_account_id).to eq(account_uuid)
    expect(subject.feature).to eq(feature)
  end

  it 'has a foreign key to an associated user account' do
    associated_account = UserAccount.find(subject.user_account_id)
    expect(associated_account).not_to be_nil
    expect(associated_account.id).to eq(account_uuid)
  end

  describe 'validation' do
    context 'feature included in FEATURES constant' do
      it 'accepts features included in the FEATURES constant' do
        expect(subject).to be_valid
      end
    end

    context 'feature not included in FEATURES constant' do
      let(:feature) { 'invalid_feature_flag' }

      it 'rejects features no included in the FEATURES constant' do
        expect(subject).not_to be_valid
      end
    end
  end
end
