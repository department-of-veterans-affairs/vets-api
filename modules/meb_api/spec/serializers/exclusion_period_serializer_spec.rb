# frozen_string_literal: true

require 'rails_helper'
require 'dgi/exclusion_period/response'

describe ExclusionPeriodSerializer, type: :serializer do
  subject { serialize(exclusion_period_response, serializer_class: described_class) }

  let(:exclusion_periods) { %w[ROTC NoPayDate] }
  let(:exclusion_period_response) do
    response = double('response', status: 201, body: { 'exclusion_periods' => exclusion_periods })
    MebApi::DGI::ExclusionPeriod::Response.new(response)
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :enrollment_verifications' do
    expect_data_eq(attributes['exclusion_periods'], exclusion_periods)
  end
end
