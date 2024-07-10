# frozen_string_literal: true

require 'rails_helper'
require 'dgi/eligibility/eligibility_response'

describe EligibilitySerializer, type: :serializer do
  subject { serialize(eligibility_response, serializer_class: described_class) }

  let(:eligibility) do
    [
      { veteran_is_eligible: true, chapter: 'Chapter33' },
      { veteran_is_eligible: false, chapter: 'Chapter30' },
      { veteran_is_eligible: false, chapter: 'Chapter1606' }
    ]
  end
  let(:eligibility_response) do
    response = double('response', body: eligibility)
    MebApi::DGI::Eligibility::EligibilityResponse.new(201, response)
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :eligibility' do
    expect_data_eq(attributes['eligibility'], eligibility)
  end
end
