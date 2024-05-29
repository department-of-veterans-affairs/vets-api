# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::RegistrationSubmissionSerializer do
  let(:registration) { build_stubbed(:covid_vax_registration) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(registration, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to eq registration.sid
  end

  it 'includes :created_at' do
    expect(rendered_attributes[:created_at]).to eq registration.created_at
  end

  it 'includes :vaccine_interest' do
    expect(rendered_attributes[:vaccine_interest]).to eq registration.raw_form_data['vaccine_interest']
  end

  it 'includes :zip_code' do
    expect(rendered_attributes[:zip_code]).to eq registration.raw_form_data['zip_code']
  end

  it 'includes :zip_code_details' do
    expect(rendered_attributes[:zip_code_details]).to eq registration.raw_form_data['zip_code_details']
  end

  it 'includes :phone' do
    expect(rendered_attributes[:phone]).to eq registration.raw_form_data['phone']
  end

  it 'includes :email' do
    expect(rendered_attributes[:email]).to eq registration.raw_form_data['email']
  end

  it 'includes :first_name' do
    expect(rendered_attributes[:first_name]).to eq registration.raw_form_data['first_name']
  end

  it 'includes :last_name' do
    expect(rendered_attributes[:last_name]).to eq registration.raw_form_data['last_name']
  end

  it 'includes :birth_date' do
    expect(rendered_attributes[:birth_date]).to eq registration.raw_form_data['birth_date']
  end
end
