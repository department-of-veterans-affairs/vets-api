# frozen_string_literal: true

require_relative '../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestResolutionSerializer, type: :serializer do
  describe 'serialization' do
    subject { described_class.new(resolution).serializable_hash[:data][:attributes] }

    let(:user) { create(:user_account) }
    let(:resolution) do
      create(:power_of_attorney_request_resolution, resolving: resolving, reason: 'Did not authorize')
    end

    context 'when resolving is a Decision' do
      let(:resolving) { create(:power_of_attorney_request_decision, type: 'declination', creator: user) }

      it 'serializes resolution with decision-specific fields' do
        expect(subject).to eq(
          id: resolution.id,
          created_at: resolution.created_at.iso8601,
          reason: 'Did not authorize',
          type: 'decision',
          decision_type: 'declination',
          creator_id: user.id
        )
      end
    end

    context 'when resolving is an Expiration' do
      let(:resolving) { create(:power_of_attorney_request_expiration) }

      it 'serializes resolution with expiration-specific fields' do
        expect(subject).to eq(
          id: resolution.id,
          created_at: resolution.created_at.iso8601,
          reason: 'Did not authorize',
          type: 'expiration'
        )
      end
    end
  end
end
