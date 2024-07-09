# frozen_string_literal: true

require 'rails_helper'
require 'dgi/enrollment/submit_enrollment_response'

describe SubmitEnrollmentSerializer, type: :serializer do
  subject { serialize(submit_enrollment_response, serializer_class: described_class) }

  let(:enrollment_certifys) do
    [
      { 'claimant_id' => 600_000_000, 'certified_period_begin_date' => '2020-02-01',
        'certified_period_end_date' => '2020-02-31', 'certified_through_date' => '2022-01-31',
        'certification_method' => 'MEB' },
      { 'claimant_id' => 600_000_000, 'certified_period_begin_date' => '2020-01-01',
        'certified_period_end_date' => '2020-01-31', 'certified_through_date' => '2022-01-31',
        'certification_method' => 'MEB' }
    ]
  end

  let(:submit_enrollment_response) do
    response = double('response', status: 201, body: { 'enrollment_certify_responses' => enrollment_certifys })
    MebApi::DGI::SubmitEnrollment::Response.new(response)
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :enrollment_certify_responses' do
    expect_data_eq(attributes['enrollment_certify_responses'], enrollment_certifys)
  end
end
