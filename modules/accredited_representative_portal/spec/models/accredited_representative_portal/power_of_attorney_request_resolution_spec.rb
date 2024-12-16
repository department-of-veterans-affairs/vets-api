# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution, type: :model do
  describe 'associations' do
    let(:power_of_attorney_request) { create(:power_of_attorney_request) }

    it { is_expected.to belong_to(:power_of_attorney_request) }

    it 'can resolve to PowerOfAttorneyRequestExpiration' do
      expiration = create(:power_of_attorney_request_expiration)
      resolution = described_class.create!(
        resolving: expiration,
        power_of_attorney_request: power_of_attorney_request,
        created_at: Time.zone.now,
        encrypted_kms_key: SecureRandom.hex(16)
      )

      expect(resolution.resolving).to eq(expiration)
      expect(resolution.resolving_type).to eq('AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration')
    end

    it 'can resolve to PowerOfAttorneyRequestDecision' do
      decision = create(:power_of_attorney_request_decision)
      resolution = described_class.create!(
        resolving: decision,
        power_of_attorney_request: power_of_attorney_request,
        created_at: Time.zone.now,
        encrypted_kms_key: SecureRandom.hex(16)
      )

      expect(resolution.resolving).to eq(decision)
      expect(resolution.resolving_type).to eq('AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision')
    end
  end

  describe 'validations' do
    subject { create(:power_of_attorney_request_resolution, :with_decision) }

    it { is_expected.to validate_uniqueness_of(:power_of_attorney_request_id).ignoring_case_sensitivity }
    it { is_expected.to validate_inclusion_of(:resolving_type).in_array(described_class::RESOLVING_TYPES) }

    it 'validates presence of resolving_id if resolving_type is present' do
      resolution = build(:power_of_attorney_request_resolution, resolving_type: described_class::RESOLVING_TYPES.first,
                                                                resolving_id: nil)
      expect(resolution).not_to be_valid
      expect(resolution.errors[:resolving_id]).to include("can't be blank")
    end
  end

  describe 'delegated_type resolving' do
    it 'is valid with expiration resolving' do
      resolution = create(:power_of_attorney_request_resolution, :with_expiration)
      expect(resolution).to be_valid
      expect(resolution.resolving).to be_a(AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration)
    end

    it 'is valid with decision resolving' do
      resolution = create(:power_of_attorney_request_resolution, :with_decision)
      expect(resolution).to be_valid
      expect(resolution.resolving).to be_a(AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision)
    end

    it 'is invalid with null resolving_type and resolving_id' do
      resolution = build(:power_of_attorney_request_resolution, resolving_type: nil, resolving_id: nil)
      expect(resolution).not_to be_valid
    end

    it 'is invalid with invalid resolving_type' do
      resolution = build(:power_of_attorney_request_resolution, resolving_type: 'invalid_type')
      expect(resolution).not_to be_valid
    end
  end
end
