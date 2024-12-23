# frozen_string_literal: true

require_relative '../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration, type: :model do
  describe 'associations' do
    it { is_expected.to have_one(:power_of_attorney_request_resolution) }
  end

  describe 'validations' do
    it 'creates a valid record' do
      expiration = create(:power_of_attorney_request_expiration)
      expect(expiration).to be_valid
    end
  end
end
