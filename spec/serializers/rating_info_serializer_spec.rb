# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/rating_info_response'

describe RatingInfoSerializer, type: :serializer do
  subject { serialize(rating_info_response, serializer_class: described_class) }

  let(:rating_info_response) do
    response = double('response', body: { user_percent_of_disability: 100 })
    EVSS::DisabilityCompensationForm::RatingInfoResponse.new(200, response)
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :user_percent_of_disability' do
    expect(attributes['user_percent_of_disability']).to eq rating_info_response.user_percent_of_disability
  end

  it 'includes :source_system' do
    expect(attributes['source_system']).to eq 'EVSS'
  end
end
