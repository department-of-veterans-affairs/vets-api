# frozen_string_literal: true

require 'rails_helper'
require 'dgi/enrollment/submit_enrollment_response'

describe SubmitEnrollmentSerializer do
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

  let(:expected_response) do
    {
      data: {
        id: '',
        type: 'meb_api_dgi_exclusion_period_responses',
        attributes: {
          enrollment_certify_responses: [
            { 'claimant_id' => 600_000_000, 'certified_period_begin_date' => '2020-02-01',
              'certified_period_end_date' => '2020-02-31', 'certified_through_date' => '2022-01-31',
              'certification_method' => 'MEB' },
            { 'claimant_id' => 600_000_000, 'certified_period_begin_date' => '2020-01-01',
              'certified_period_end_date' => '2020-01-31', 'certified_through_date' => '2022-01-31',
              'certification_method' => 'MEB' }
          ]
        }
      }
    }
  end

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(submit_enrollment_response,
                                                     { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to be_blank
  end

  it 'includes :enrollment_certify_responses' do
    enrollment_certify_responses = expected_response[:data][:attributes][:enrollment_certify_responses]
    expect(rendered_attributes[:enrollment_certify_responses]).to eq enrollment_certify_responses
  end
end
