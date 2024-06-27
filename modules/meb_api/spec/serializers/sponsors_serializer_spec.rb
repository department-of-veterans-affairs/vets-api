# frozen_string_literal: true

require 'rails_helper'
require 'dgi/forms/response/sponsor_response'

describe SponsorsSerializer, type: :serializer do
  subject { serialize(sponsors_response, serializer_class: described_class) }

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
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :enrollment_verifications' do
    expect_data_eq(attributes['sponsors'], sponsors)
  end
end
