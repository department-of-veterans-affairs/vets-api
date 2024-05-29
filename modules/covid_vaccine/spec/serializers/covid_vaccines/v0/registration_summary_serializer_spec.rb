# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::RegistrationSummarySerializer do

  let(:registration) { build_stubbed(:covid_vax_registration) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(registration, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id].blank?).to be_truthy
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

end
