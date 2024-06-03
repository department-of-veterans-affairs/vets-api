# frozen_string_literal: true

require 'rails_helper'
require 'dgi/status/status_response'

describe ClaimStatusSerializer do
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

  let(:expected_response) do
    {
      data: {
        id: '',
        type: 'meb_api_dgi_status_status_responses',
        attributes: {
          claimant_id: 600_000_001,
          claim_service_id: 99_000_000_113_358_369,
          claim_status: 'ELIGIBLE',
          received_date: '2022-06-13'
        }
      }
    }
  end

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(claim_status_response, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to be_blank
  end

  it 'includes :claimant_id' do
    expect(rendered_attributes[:claimant_id]).to eq expected_response[:data][:attributes][:claimant_id]
  end

  it 'includes :claim_service_id' do
    expect(rendered_attributes[:claim_service_id]).to eq expected_response[:data][:attributes][:claim_service_id]
  end

  it 'includes :claim_status' do
    expect(rendered_attributes[:claim_status]).to eq expected_response[:data][:attributes][:claim_status]
  end

  it 'includes :received_date' do
    expect(rendered_attributes[:received_date]).to eq expected_response[:data][:attributes][:received_date]
  end
end
