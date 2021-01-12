# frozen_string_literal: true

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

    it 'validates presence of user' do
      expect_attr_invalid(preferred_facility, :user, "can't be blank")
    end

    it 'validates facility_code in user list' do
      facility = build(:preferred_facility, facility_code: '111')
      expect_attr_invalid(facility, :facility_code, "must be included in user's va treatment facilities list")
    end

    it 'shows an error if facility_code is not unique per account' do
      preferred_facility = build(
        :preferred_facility,
        facility_code: create(:preferred_facility).facility_code
      )

      expect_attr_invalid(preferred_facility, :facility_code, 'has already been taken')
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
