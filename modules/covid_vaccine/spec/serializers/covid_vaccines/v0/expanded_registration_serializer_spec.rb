# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::ExpandedRegistrationSerializer do

  let(:submission) { build_stubbed(:covid_vax_expanded_registration) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(submission, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id].blank?).to be_truthy
  end

  it 'includes :created_at' do
    expect(rendered_attributes[:created_at]).to eq submission.created_at
  end

end
