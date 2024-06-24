# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::RegistrationSubmissionSerializer, type: :serializer do
  subject { serialize(registration, serializer_class: described_class) }

  let(:registration) { build_stubbed(:covid_vax_registration) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq registration.sid
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

  it 'includes :zip_code_details' do
    expect(attributes['zip_code_details']).to eq registration.raw_form_data['zip_code_details']
  end

  it 'includes :phone' do
    expect(attributes['phone']).to eq registration.raw_form_data['phone']
  end

  it 'includes :email' do
    expect(attributes['email']).to eq registration.raw_form_data['email']
  end

  it 'includes :first_name' do
    expect(attributes['first_name']).to eq registration.raw_form_data['first_name']
  end

  it 'includes :last_name' do
    expect(attributes['last_name']).to eq registration.raw_form_data['last_name']
  end

  it 'includes :birth_date' do
    expect(attributes['birth_date']).to eq registration.raw_form_data['birth_date']
  end
end
