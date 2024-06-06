# frozen_string_literal: true

require 'rails_helper'
require 'dgi/forms/response/sponsor_response'

describe SponsorsSerializer do
  let(:sponsors) do
    [
      {
        'first_name' => 'Rodrigo',
        'last_name' => 'Diaz',
        'sponsor_relationship' => 'Spouse',
        'date_of_birth' => '06/12/1975'
      }
    ]
  end

  let(:sponsors_response) do
    response = double('response', status: 201, body: sponsors)
    MebApi::DGI::Forms::Response::SponsorResponse.new(response)
  end

  let(:expected_response) do
    {
      data: {
        id: '',
        type: 'meb_api_dgi_exclusion_period_responses',
        attributes: {
          sponsors: [
            {
              'first_name' => 'Rodrigo',
              'last_name' => 'Diaz',
              'sponsor_relationship' => 'Spouse',
              'date_of_birth' => '06/12/1975'
            }
          ]
        }
      }
    }
  end

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(sponsors_response, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to be_blank
  end

  it 'includes :sponsors' do
    expect(rendered_attributes[:sponsors]).to eq expected_response[:data][:attributes][:sponsors]
  end
end
