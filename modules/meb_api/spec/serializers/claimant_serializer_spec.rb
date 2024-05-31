# frozen_string_literal: true

require 'rails_helper'
require 'dgi/claimant/claimant_response'

describe ClaimantSerializer do
  let(:claimant) { 600_010_259 }

  let(:claimant_response) do
    response = double('response', body: { 'claimant_id' => claimant })
    MebApi::DGI::Claimant::ClaimantResponse.new(201, response)
  end

  let(:expected_response) do
    {
      data: {
        id: '',
        type: 'meb_api_dgi_claimant_claimant_responses',
        attributes: {
          claimant_id: '600010259'
        }
      }
    }
  end

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(claimant_response, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to be_blank
  end

  it 'includes :claimant_id' do
    expect(rendered_attributes[:claimant_id]).to eq expected_response[:data][:attributes][:claimant_id]
  end
end
