# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::AutoEstablishedClaimSerializer, type: :serializer do
  include SerializerSpecHelper

  subject { serialize(claim, serializer_class: described_class) }

  let(:claim) { build_stubbed(:auto_established_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:claim_data) { claim.data }

  it 'includes :type' do
    expect(data['type']).to eq 'claims_api_claim'
  end

  it 'includes :id' do
    expect(data['id']).to eq claim.id.to_s
  end

  it 'includes :token' do
    expect(attributes['token']).to eq claim.token
  end

  it 'includes :status' do
    expect(attributes['status']).to eq claim.status
  end

  it 'includes :evss_id' do
    expect(attributes['evss_id']).to eq claim.evss_id
  end

  it 'includes :flashes' do
    expect(attributes['flashes']).to eq claim.flashes
  end

  it 'includes :phase' do
    phase = claim.data.dig('claim_phase_dates', 'latest_phase_type')&.downcase
    expect(attributes['phase']).to eq described_class::PHASE_MAPPING[phase]
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
      phase
      phase_change_date
      ever_phase_back
      current_phase_back
    ]
    expect(attributes.keys).to include(*base_keys)
  end
end
