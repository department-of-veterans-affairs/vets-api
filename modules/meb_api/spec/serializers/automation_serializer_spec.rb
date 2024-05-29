# frozen_string_literal: true

require 'rails_helper'
require 'dgi/automation/claimant_response'

describe AutomationSerializer do

  let(:claimant) do
    {
      'claimant_id': 600_010_259,
      'suffix': '',
      'date_of_birth': '1990-08-01',
      'first_name': 'Hector',
      'last_name': 'Allen',
      'middle_name': 'James',
      'notification_method': 'NONE',
      'contact_info': {
        'address_line1': '1291 Boston Post Rd',
        'address_line2': '',
        'city': 'Madison',
        'zipcode': '06443',
        'email_address': 'testing@test.com',
        'address_type': 'DOMESTIC',
        'mobile_phone_number': '1231231234',
        'home_phone_number': '1231231234',
        'country_code': 'US',
        'state_code': 'CT'
      },
      'preferred_contact': nil
    }
  end

  let(:service_data) do
    [
      {
        'branch_of_service': 'Air Force',
        'begin_date': '2010-06-01',
        'end_date': '2020-06-01',
        'character_of_service': 'Honorable',
        'reason_for_separation': 'Expiration Term Of Service',
        'exclusion_periods': [],
        'training_periods': []
      }
    ]
  end

  let(:automation_claimant_response) do
    response = double('response', body: { 'claimant' => claimant, 'service_data' => service_data })
    MebApi::DGI::Automation::ClaimantResponse.new(201, response)
  end

  let(:expected_response) do
    {
      'data': {
        'id': '',
        'type': 'meb_api_dgi_automation_claimant_responses',
        'attributes': {
          'claimant': {
            'claimant_id': 600_010_259,
            'suffix': '',
            'date_of_birth': '1990-08-01',
            'first_name': 'Hector',
            'last_name': 'Allen',
            'middle_name': 'James',
            'notification_method': 'NONE',
            'contact_info': {
              'address_line1': '1291 Boston Post Rd',
              'address_line2': '',
              'city': 'Madison',
              'zipcode': '06443',
              'email_address': 'testing@test.com',
              'address_type': 'DOMESTIC',
              'mobile_phone_number': '1231231234',
              'home_phone_number': '1231231234',
              'country_code': 'US',
              'state_code': 'CT'
            },
            'preferred_contact': nil
          },
          'service_data': [
            {
              'branch_of_service': 'Air Force',
              'begin_date': '2010-06-01',
              'end_date': '2020-06-01',
              'character_of_service': 'Honorable',
              'reason_for_separation': 'Expiration Term Of Service',
              'exclusion_periods': [],
              'training_periods': []
            }
          ]
        }
      }
    }
  end

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(automation_claimant_response, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to be_blank
  end

  it 'includes :claimant' do
    expect(rendered_attributes[:claimant]).to eq expected_response[:data][:attributes][:claimant]
  end

  it 'includes :service_data' do
    expect(rendered_attributes[:service_data]).to eq expected_response[:data][:attributes][:service_data]
  end
end
