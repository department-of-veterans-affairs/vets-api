# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::ClaimListSerializer, type: :serializer do
  subject { serialize(claim, serializer_class: described_class) }

  let(:claim) { build(:claims_api_evss_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:claim_data) { claim.list_data }

  it 'includes :id' do
    expect(data['id']).to eq claim.evss_id.to_s
  end

  it 'includes :type' do
    expect(data['type']).to eq 'evss_claims'
  end

  it 'includes :status' do
    phase = claim.list_data['status']&.downcase
    expected_status = claim.status_from_phase(described_class::PHASE_MAPPING[phase])
    expect(attributes['status']).to eq expected_status
  end

  it 'includes base keys' do
    base_keys = %w[
      date_filed
      min_est_date
      max_est_date
      open
      documents_needed
      development_letter_sent
      decision_letter_sent
      requested_decision
      claim_type
    ]
    expect(attributes.keys).to include(*base_keys)
  end
end
