# frozen_string_literal: true

# spec/serializers/power_of_attorney_request_serializer_spec.rb
require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestSerializer do
  subject { described_class.new(request).serializable_hash[:data][:attributes] }

  let(:request) { create(:power_of_attorney_request, created_at: '2024-12-17T00:30:55Z') }

  context 'when resolution is nil' do
    it 'returns the request without resolution' do
      expect(subject).to eq({
                              id: request.id,
                              claimant_id: request.claimant_id,
                              created_at: '2024-12-17T00:30:55.000Z',
                              resolution: nil
                            })
    end
  end

  context 'when resolution is an expiration' do
    let(:resolution) do
      create(:power_of_attorney_request_resolution, :with_expiration, reason: 'Test reason for resolution')
    end

    before { request.update(resolution: resolution) }

    it 'includes resolution details with type expiration and reason' do
      expect(subject[:resolution]).to eq({
                                           id: resolution.id,
                                           type: 'power_of_attorney_request_expiration',
                                           created_at: resolution.created_at.iso8601(3),
                                           reason: 'Test reason for resolution'
                                         })
    end
  end

  context 'when resolution is a decision with creator_id' do
    let(:resolution) do
      create(:power_of_attorney_request_resolution, :with_decision)
    end

    before { request.update(resolution: resolution) }

    it 'includes resolution details with type decision and creator_id' do
      expect(subject[:resolution]).to eq({
                                           id: resolution.id,
                                           type: 'power_of_attorney_request_decision',
                                           created_at: resolution.created_at.iso8601(3),
                                           reason: 'Test reason for resolution',
                                           creator_id: resolution.resolving.creator_id
                                         })
    end
  end

  context 'when resolution is a declination with reason' do
    let(:resolution) do
      create(:power_of_attorney_request_resolution, :with_declination,
             reason: "Didn't authorize treatment record disclosure")
    end

    before { request.update(resolution: resolution) }

    it 'includes resolution details with type decision, reason, and creator_id' do
      expect(subject[:resolution]).to eq({
                                           id: resolution.id,
                                           type: 'power_of_attorney_request_decision',
                                           created_at: resolution.created_at.iso8601(3),
                                           reason: "Didn't authorize treatment record disclosure",
                                           creator_id: resolution.resolving.creator_id
                                         })
    end
  end
end
