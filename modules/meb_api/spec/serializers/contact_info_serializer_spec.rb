# frozen_string_literal: true

require 'rails_helper'
require 'dgi/contact_info/response'

describe ContactInfoSerializer do
  let(:contact_info_response) do
    response = double('response', body: {
                        'emails' => [{ 'address': 'test@test.com', 'dupe': 'false' }],
                        'phones' => [{ 'number': '8013090123', 'dupe': 'false' }]
                      })
    MebApi::DGI::ContactInfo::Response.new(201, response)
  end

  let(:expected_response) do
    {
      data: {
        id: '',
        type: 'meb_api_dgi_contact_info_responses',
        attributes: {
          phone: [{ number: '8013090123', dupe: 'false' }],
          email: [{ address: 'test@test.com', dupe: 'false' }]
        }
      }
    }
  end

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(contact_info_response, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to be_blank
  end

  it 'includes :phone' do
    expect(rendered_attributes[:phone]).to eq expected_response[:data][:attributes][:phone]
  end

  it 'includes :email' do
    expect(rendered_attributes[:email]).to eq expected_response[:data][:attributes][:email]
  end
end
