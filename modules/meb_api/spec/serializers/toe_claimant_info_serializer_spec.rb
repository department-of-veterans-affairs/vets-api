# frozen_string_literal: true

require 'rails_helper'
require 'dgi/forms/response/claimant_info_response'

describe ToeClaimantInfoSerializer do
  let(:claimant) do
    {
      claimant_id: 0,
      suffix: nil,
      date_of_birth: "1992-04-01",
      first_name: "Black",
      last_name: "Johnson",
      middle_name: "Jet",
      notification_method: "NONE",
      contact_info: nil,
      preferred_contact: nil
    }
  end

  let(:toe_sponsors) do
    {
      transfer_of_entitlements: [
        {
          fist_name: "SEAN",
          second_name: "JOHNSON",
          sponsor_relationship: "Child",
          sponsor_va_id: 1000000077,
          date_of_birth: "1971-05-24"
        }
      ]
    }
  end

  let(:claimant_response) do
    body = { 'claimant' => claimant, 'service_data' => nil, 'toe_sponsors' => toe_sponsors }
    response = double('response', body: body)
    MebApi::DGI::Forms::ClaimantResponse.new(200, response)
  end

  let(:expected_response) do
    {
      data: {
        id: '',
        type: 'meb_api_dgi_forms_claimant_responses',
        attributes: {
          'claimant': {
            "claimant_id": 0,
            "suffix": nil,
            "date_of_birth": "1992-04-01",
            "first_name": "Black",
            "last_name": "Johnson",
            "middle_name": "Jet",
            "notification_method": "NONE",
            "contact_info": nil,
            "preferred_contact": nil
          },
          'service_data': [],
          'toe_sponsors':{
            "transfer_of_entitlements":[
              {
                "fist_name": "SEAN",
                "second_name": "JOHNSON",
                "sponsor_relationship": "Child",
                "sponsor_va_id": 1000000077,
                "date_of_birth": "1971-05-24"
              }
            ]
          }
        }
      }
    }
  end

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(claimant_response,
                                                     { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to be_blank
  end

  it 'includes :claimant' do
    binding.pry
    expect(rendered_attributes[:claimant]).to eq expected_response[:data][:attributes][:claimant]
  end

  it 'includes :service_data' do
    expect(rendered_attributes[:service_data]).to eq expected_response[:data][:attributes][:service_data]
  end

  it 'includes :toe_sponsors' do
    expect(rendered_attributes[:toe_sponsors]).to eq expected_response[:data][:attributes][:toe_sponsors]
  end
end
