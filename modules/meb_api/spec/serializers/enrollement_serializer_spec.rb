# frozen_string_literal: true

require 'rails_helper'
require 'dgi/enrollment/enrollment_response'

describe EnrollmentSerializer, type: :serializer do
  subject { serialize(eligibility_response, serializer_class: described_class) }

  let(:enrollment_verifications) do
    [{ 'verification_month' => 'January 2021',
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
       'created_date' => nil }]
  end
  let(:last_certified_through_date) { '2021-01-01' }
  let(:payment_on_hold) { true }
  let(:eligibility_response) do
    response = double('response', status: 201, body: {
                        'enrollment_verifications' => enrollment_verifications,
                        'last_certified_through_date' => last_certified_through_date,
                        'payment_on_hold' => payment_on_hold
                      })
    MebApi::DGI::Enrollment::Response.new(response)
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :enrollment_verifications' do
    expect_data_eq(attributes['enrollment_verifications'], enrollment_verifications)
  end

  it 'includes :last_certified_through_date' do
    expect(attributes['last_certified_through_date']).to eq last_certified_through_date
  end

  it 'includes :payment_on_hold' do
    expect(attributes['payment_on_hold']).to eq payment_on_hold
  end
end
