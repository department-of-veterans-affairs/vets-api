# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequest, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:claimant).class_name('UserAccount') }
    it { is_expected.to have_one(:form).dependent(:destroy) }
    it { is_expected.to have_one(:resolution).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:created_at) }
  end

  describe 'creation' do
    it 'creates a valid record' do
      user = UserAccount.create!(id: SecureRandom.uuid)
      request = build(:power_of_attorney_request, claimant: user)
      expect(request).to be_valid
    end
  end
end
