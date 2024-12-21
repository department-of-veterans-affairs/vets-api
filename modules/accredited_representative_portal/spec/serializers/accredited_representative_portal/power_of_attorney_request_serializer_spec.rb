# frozen_string_literal: true

require_relative '../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestSerializer, type: :serializer do
  describe 'serialization' do
    subject { described_class.new(poa_request).serializable_hash[:data][:attributes] }

    let(:claimant) { create(:user_account) }
    let(:poa_request) { create(:power_of_attorney_request, claimant: claimant, resolution: resolution) }

    context 'when resolution exists' do
      let(:resolution) do
        create(:power_of_attorney_request_resolution,
               resolving: create(:power_of_attorney_request_decision, type: 'declination'))
      end

      it 'serializes POA request with resolution' do
        expect(subject).to eq(
          id: poa_request.id,
          claimant_id: poa_request.claimant_id,
          created_at: poa_request.created_at.iso8601,
          resolution: {
            id: resolution.id,
            created_at: resolution.created_at.iso8601,
            reason: resolution.reason,
            type: 'decision',
            decision_type: 'declination',
            creator_id: resolution.resolving.creator_id
          }
        )
      end
    end

    context 'when resolution is absent' do
      let(:resolution) { nil }

      it 'serializes POA request without resolution' do
        expect(subject).to eq(
          id: poa_request.id,
          claimant_id: poa_request.claimant_id,
          created_at: poa_request.created_at.iso8601,
          resolution: nil
        )
      end
    end
  end
end
