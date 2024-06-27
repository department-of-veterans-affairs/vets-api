# frozen_string_literal: true

require 'rails_helper'
require 'dgi/forms/response/claimant_info_response'

describe ToeClaimantInfoSerializer, type: :serializer do
  subject { serialize(claimant_response, serializer_class: described_class) }

  let(:claimant) do
    {
      claimant_id: 0,
      suffix: nil,
      date_of_birth: '1992-04-01',
      first_name: 'Black',
      last_name: 'Johnson',
      middle_name: 'Jet',
      notification_method: 'NONE',
      contact_info: nil,
      preferred_contact: nil
    }
  end

  let(:toe_sponsors) do
    {
      transfer_of_entitlements: [
        {
          fist_name: 'SEAN',
          second_name: 'JOHNSON',
          sponsor_relationship: 'Child',
          sponsor_va_id: 1_000_000_077,
          date_of_birth: '1971-05-24'
        }
      ]
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

  let(:claimant_response) do
    body = { 'claimant' => claimant, 'service_data' => service_data, 'toe_sponsors' => toe_sponsors }
    response = double('response', body:)
    MebApi::DGI::Forms::ClaimantResponse.new(200, response)
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

  it 'includes :toe_sponsors' do
    expect_data_eq(attributes['toe_sponsors'], toe_sponsors)
  end
end
