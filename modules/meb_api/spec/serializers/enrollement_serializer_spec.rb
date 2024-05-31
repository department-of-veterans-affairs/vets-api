# frozen_string_literal: true

require 'rails_helper'
require 'dgi/enrollment/enrollment_response'

describe EnrollmentSerializer do
  let(:eligibility_response) do
    response = double('response', status: 201, body:
                        { 'enrollment_verifications' => [{ 'verification_month' => 'January 2021',
                                                           'certified_begin_date' => '2021-01-01',
                                                           'certified_end_date' => '2021-01-31',
                                                           'certified_through_date' => nil,
                                                           'certification_method' => nil,
                                                           'enrollments' => [{
                                                             'facility_name' => 'UNIVERSITY OF HAWAII AT HILO',
                                                             'begin_date' => '2020-01-01',
                                                             'end_date' => '2021-01-01',
                                                             'total_credit_hours' => 17.0
                                                           }],
                                                           'verification_response' => 'NR',
                                                           'created_date' => nil }] })
    MebApi::DGI::Enrollment::Response.new(response)
  end

  let(:expected_response) do
    {
      data: {
        id: '',
        type: 'meb_api_dgi_enrollment_responses',
        attributes: {
          enrollment_verifications: [{
            verification_month: 'January 2021', certified_begin_date: '2021-01-01',
            certified_end_date: '2021-01-31', certified_through_date: nil, certification_method: nil,
            enrollments: [
              {
                facility_name: 'UNIVERSITY OF HAWAII AT HILO',
                begin_date: '2020-01-01',
                end_date: '2021-01-01',
                total_credit_hours: 17.0
              }
            ],
            verification_response: 'NR', created_date: nil
          }],
          last_certified_through_date: nil,
          payment_on_hold: nil
        }
      }
    }.deep_stringify_keys
  end

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(eligibility_response, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to be_blank
  end

  it 'includes :enrollment_verifications' do
    expect_enrollment_verifications = expected_response['data']['attributes']['enrollment_verifications']
    expect(rendered_attributes[:enrollment_verifications]).to eq expect_enrollment_verifications
  end

  it 'includes :last_certified_through_date' do
    expected_last_certified_through_date = expected_response['data']['attributes']['last_certified_through_date']
    expect(rendered_attributes[:last_certified_through_date]).to eq expected_last_certified_through_date
  end

  it 'includes :payment_on_hold' do
    expect(rendered_attributes[:payment_on_hold]).to eq expected_response['data']['attributes']['payment_on_hold']
  end
end
