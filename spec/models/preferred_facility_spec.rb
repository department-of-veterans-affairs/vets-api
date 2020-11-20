require 'rails_helper'

RSpec.describe PreferredFacility, type: :model do
  describe 'validations' do
    let(:preferred_facility) { described_class.new }

    it 'validates presence of account' do
      expect_attr_invalid(preferred_facility, :account, "can't be blank")
    end

    it 'validates presence of facility_code' do
      expect_attr_invalid(preferred_facility, :facility_code, "can't be blank")
    end

    it 'validates presence of facility_code' do
      expect_attr_invalid(preferred_facility, :user, "can't be blank")
    end

    it 'validates facility_code in user list' do
      build(:preferred_facility)
    end
  end

  describe '#set_account' do
    let(:preferred_facility) { build(:preferred_facility) }

    it 'sets the account from user if account is blank' do
      expect(preferred_facility.account).to be_nil
      preferred_facility.valid?

      expect(preferred_facility.account).to eq(preferred_facility.user.account)
    end
  end
end
