# frozen_string_literal: true

require 'rails_helper'

describe LetterBeneficiarySerializer, type: :serializer do
  subject { serialize(beneficiary_response, serializer_class: described_class) }

  let(:benefit_information) do
    {
      'monthly_award_amount' => 123.0,
      'service_connected_percentage' => 2,
      'award_effective_date' => Time.parse('Thu, 06 Jun 2013 04:00:00 +0000'),
      'has_chapter35_eligibility' => true,
      'has_non_service_connected_pension' => false,
      'has_service_connected_disabilities' => true,
      'has_adapted_housing' => false,
      'has_individual_unemployability_granted' => false,
      'has_special_monthly_compensation' => false
    }
  end

  let(:military_service) do
    {
      'branch' => 'Army',
      'character_of_service' => 'HONORABLE',
      'entered_date' => Time.parse('Fri, 01 Jan 1965 05:00:00 +0000'),
      'released_date' => Time.parse('Sun, 01 Oct 1972 04:00:00 +0000')
    }
  end

  let(:beneficiary_response) do
    body = { 'benefit_information' => benefit_information, 'military_service' => [military_service] }
    response = double('response', body:)
    EVSS::Letters::BeneficiaryResponse.new(200, response)
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :benefit_information' do
    expect(attributes['benefit_information'].keys.map(&:to_s)).to eq benefit_information.keys.map(&:to_s)
  end

  it 'includes :military_service' do
    expect(attributes['military_service'].size).to eq 1
  end

  it 'includes :military_service with attributes' do
    expected_attributes = military_service.keys.map(&:to_s)
    expect(attributes['military_service'].first.keys).to eq expected_attributes
  end
end
