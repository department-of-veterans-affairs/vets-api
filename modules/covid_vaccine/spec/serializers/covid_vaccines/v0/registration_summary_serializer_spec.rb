# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::RegistrationSummarySerializer, type: :serializer do
  subject { serialize(registration, serializer_class: described_class) }

  let(:registration) { build_stubbed(:covid_vax_registration) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :created_at' do
    expect_time_eq(attributes['created_at'], registration.created_at)
  end

  it 'includes :vaccine_interest' do
    expect(attributes['vaccine_interest']).to eq registration.raw_form_data['vaccine_interest']
  end

  it 'includes :zip_code' do
    expect(attributes['zip_code']).to eq registration.raw_form_data['zip_code']
  end
end
