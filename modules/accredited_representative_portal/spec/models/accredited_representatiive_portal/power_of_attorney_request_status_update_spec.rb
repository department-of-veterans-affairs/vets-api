# frozen_string_literal: true

require_relative '../../rails_helper'

mod = AccreditedRepresentativePortal
RSpec.describe mod::PowerOfAttorneyRequestStatusUpdate, type: :model do
  it 'conveniently returns heterogeneous lists' do
    travel_to '2024-11-25T09:46:24Z'

    ids = []

    ids <<
      described_class.create!(
        status_updating: mod::PowerOfAttorneyRequestDecision.new(
          type: 'acceptance'
        )
      ).id

    ids <<
      described_class.create!(
        status_updating: mod::PowerOfAttorneyRequestDecision.new(
          type: 'declination',
          declination_reason: 'Some declination reason.'
        )
      ).id

    ids <<
      described_class.create!(
        status_updating: mod::PowerOfAttorneyRequestReplacement.new
      ).id

    ids <<
      described_class.create!(
        status_updating: mod::PowerOfAttorneyRequestExpiration.new
      ).id

    ids <<
      described_class.create!(
        status_updating: mod::PowerOfAttorneyRequestWithdrawal.new(
          reason: 'Some withdrawal reason.'
        )
      ).id

    status_updates = described_class.includes(:status_updating).find(ids)

    actual =
      status_updates.map do |status_update|
        serialized =
          case status_update.status_updating
          when mod::PowerOfAttorneyRequestDecision
            {
              type: 'decision',
              decision_type: status_update.status_updating.type,
              declination_reason: status_update.status_updating.declination_reason
            }
          when mod::PowerOfAttorneyRequestWithdrawal
            {
              type: 'withdrawal',
              reason: status_update.status_updating.reason
            }
          when mod::PowerOfAttorneyRequestExpiration
            {
              type: 'expiration'
            }
          when mod::PowerOfAttorneyRequestReplacement
            {
              type: 'replacement'
            }
          end

        serialized.merge!(
          created_at: status_update.created_at.iso8601
        )
      end

    expect(actual).to eq(
      [
        {
          type: 'decision',
          decision_type: 'acceptance',
          declination_reason: nil,
          created_at: '2024-11-25T09:46:24Z'
        },
        {
          type: 'decision',
          decision_type: 'declination',
          declination_reason: 'Some declination reason.',
          created_at: '2024-11-25T09:46:24Z'
        },
        {
          type: 'replacement',
          created_at: '2024-11-25T09:46:24Z'
        },
        {
          type: 'expiration',
          created_at: '2024-11-25T09:46:24Z'
        },
        {
          type: 'withdrawal',
          reason: 'Some withdrawal reason.',
          created_at: '2024-11-25T09:46:24Z'
        }
      ]
    )
  end
end
