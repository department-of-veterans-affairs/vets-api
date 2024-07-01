# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::ExpandedRegistrationSerializer, type: :serializer do
  subject { serialize(submission, serializer_class: described_class) }

  let(:submission) { build_stubbed(:covid_vax_expanded_registration) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :created_at' do
    expect_time_eq(attributes['created_at'], submission.created_at)
  end
end
