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
  end
end
