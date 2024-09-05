# frozen_string_literal: true

require 'rails_helper'
require 'dgi/automation/claimant_response'

describe AutomationSerializer, type: :serializer do
  subject { serialize(automation_claimant_response, serializer_class: described_class) }

  let(:claimant) do
    {
      claimant_id: 600_010_259,
      suffix: '',
      date_of_birth: '1990-08-01',
      first_name: 'Hector',
      last_name: 'Allen',
      middle_name: 'James',
      notification_method: 'NONE',
      contact_info: {
        address_line1: '1291 Boston Post Rd',
        address_line2: '',
        city: 'Madison',
        zipcode: '06443',
        email_address: 'testing@test.com',
        address_type: 'DOMESTIC',
        mobile_phone_number: '1231231234',
        home_phone_number: '1231231234',
        country_code: 'US',
        state_code: 'CT'
      },
      preferred_contact: nil
    }
  end

  let(:service_data) do
    [
      {
        branch_of_service: 'Air Force',
        begin_date: '2010-06-01',
        end_date: '2020-06-01',
        character_of_service: 'Honorable',
        reason_for_separation: 'Expiration Term Of Service',
        exclusion_periods: [],
        training_periods: []
      }
    ]
  end

  let(:automation_claimant_response) do
    response = double('response', body: { 'claimant' => claimant, 'service_data' => service_data })
    MebApi::DGI::Automation::ClaimantResponse.new(201, response)
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :claimant' do
    expect_data_eq(attributes['claimant'], claimant)
  end

  it 'includes :service_data' do
    expect_data_eq(attributes['service_data'], service_data)
  end
end
