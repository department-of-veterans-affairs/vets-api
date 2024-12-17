# frozen_string_literal: true

require_relative '../../rails_helper'

mod = AccreditedRepresentativePortal
RSpec.describe mod::PowerOfAttorneyRequestResolution, type: :model do
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

  describe 'delegated_type resolving' do
    it 'is valid with expiration resolving' do
      resolution = create(:power_of_attorney_request_resolution, :with_expiration)
      expect(resolution).to be_valid
      expect(resolution.resolving).to be_a(mod::PowerOfAttorneyRequestExpiration)
    end

    it 'is valid with decision resolving' do
      resolution = create(:power_of_attorney_request_resolution, :with_decision)
      expect(resolution).to be_valid
      expect(resolution.resolving).to be_a(mod::PowerOfAttorneyRequestDecision)
    end

    it 'is invalid with null resolving_type and resolving_id' do
      resolution = build(:power_of_attorney_request_resolution, resolving_type: nil, resolving_id: nil)
      expect(resolution).not_to be_valid
    end

    it 'does not allow invalid resolving_type values' do
      resolution = build(:power_of_attorney_request_resolution, :with_invalid_type)
      resolution.resolving_type = 'AccreditedRepresentativePortal::InvalidType'

      expect(resolution).not_to be_valid
      expect(resolution.errors[:resolving_type]).to include('is not included in the list')
    end
  end

  describe 'heterogeneous list behavior' do
    it 'conveniently returns heterogeneous lists' do
      travel_to Time.zone.parse('2024-11-25T09:46:24Z') do
        creator = create(:user_account)

        ids = []

        # Persisted resolving records
        decision_acceptance = mod::PowerOfAttorneyRequestDecision.create!(
          type: 'acceptance',
          creator: creator
        )
        decision_declination = mod::PowerOfAttorneyRequestDecision.create!(
          type: 'declination',
          creator: creator
        )
        expiration = mod::PowerOfAttorneyRequestExpiration.create!

        # Associate resolving records
        ids << described_class.create!(
          power_of_attorney_request: create(:power_of_attorney_request),
          resolving: decision_acceptance,
          encrypted_kms_key: SecureRandom.hex(16),
          created_at: Time.current
        ).id

        ids << described_class.create!(
          power_of_attorney_request: create(:power_of_attorney_request),
          resolving: decision_declination,
          encrypted_kms_key: SecureRandom.hex(16),
          created_at: Time.current
        ).id

        ids << described_class.create!(
          power_of_attorney_request: create(:power_of_attorney_request),
          resolving: expiration,
          encrypted_kms_key: SecureRandom.hex(16),
          created_at: Time.current
        ).id

        resolutions = described_class.includes(:resolving).find(ids)

        # Serialize for comparison
        actual =
          resolutions.map do |resolution|
            serialized =
              case resolution.resolving
              when mod::PowerOfAttorneyRequestDecision
                {
                  type: 'decision',
                  decision_type: resolution.resolving.type
                }
              when mod::PowerOfAttorneyRequestExpiration
                {
                  type: 'expiration'
                }
              end

            serialized.merge!(
              created_at: resolution.created_at.iso8601
            )
          end

        expect(actual).to eq(
          [
            {
              type: 'decision',
              decision_type: 'acceptance',
              created_at: '2024-11-25T09:46:24Z'
            },
            {
              type: 'decision',
              decision_type: 'declination',
              created_at: '2024-11-25T09:46:24Z'
            },
            {
              type: 'expiration',
              created_at: '2024-11-25T09:46:24Z'
            }
          ]
        )
      end
    end
  end
end
