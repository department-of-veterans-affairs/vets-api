# frozen_string_literal: true

require 'rails_helper'
require 'dgi/status/status_response'

describe ClaimStatusSerializer, type: :serializer do
  subject { serialize(claim_status_response, serializer_class: described_class) }

  let(:claimant) { 600_000_001 }
  let(:claim_service_id) { 99_000_000_113_358_369 }
  let(:claim_status) { 'ELIGIBLE' }
  let(:received_date) { '2022-06-13' }

  let(:claim_status_response) do
    response = double('response', body: {
                        'claimant_id' => claimant,
                        'claim_service_id' => claim_service_id,
                        'claim_status' => claim_status,
                        'received_date' => received_date
                      })
    MebApi::DGI::Status::StatusResponse.new(201, response)
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :claimant_id' do
    expect(attributes['claimant_id']).to eq claimant
  end

  it 'includes :claim_service_id' do
    expect(attributes['claim_service_id']).to eq claim_service_id
  end

  it 'includes :claim_status' do
    expect(attributes['claim_status']).to eq 'ELIGIBLE'
  end

  it 'includes :received_date' do
    expect(attributes['received_date']).to eq received_date
  end
end
