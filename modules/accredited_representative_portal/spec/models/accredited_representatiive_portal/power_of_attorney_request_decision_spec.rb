# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:creator).class_name('UserAccount') }
    it { is_expected.to have_one(:power_of_attorney_request_resolution).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:type) }
    it { is_expected.to validate_length_of(:type).is_at_most(255) }
  end

  describe 'creation' do
    it 'creates a valid record' do
      user = UserAccount.create!(id: SecureRandom.uuid)
      decision = build(:power_of_attorney_request_decision, creator: user)
      expect(decision).to be_valid
    end
  end
end
