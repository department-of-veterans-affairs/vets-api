# frozen_string_literal: true

require 'rails_helper'
require 'dgi/eligibility/eligibility_response'

describe EligibilitySerializer do
  let(:eligibility_response) do
    response = double('response', body: [
                        { veteran_is_eligible: true, chapter: 'Chapter33' },
                        { veteran_is_eligible: false, chapter: 'Chapter30' },
                        { veteran_is_eligible: false, chapter: 'Chapter1606' }
                      ])
    MebApi::DGI::Eligibility::EligibilityResponse.new(201, response)
  end

  let(:expected_response) do
    {
      data: {
        id: '',
        type: 'meb_api_dgi_eligibility_eligibility_responses',
        attributes: {
          eligibility: [
            { veteran_is_eligible: true, chapter: 'Chapter33' },
            { veteran_is_eligible: false, chapter: 'Chapter30' },
            { veteran_is_eligible: false, chapter: 'Chapter1606' }
          ]
        }
      }
    }
  end

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(eligibility_response, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to be_blank
  end

  it 'includes :eligibility' do
    expect(rendered_attributes[:eligibility]).to eq expected_response[:data][:attributes][:eligibility]
  end
end
