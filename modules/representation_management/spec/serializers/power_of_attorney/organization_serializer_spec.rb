# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared_base_power_of_attorney'

describe RepresentationManagement::PowerOfAttorney::OrganizationSerializer do
  let(:object) { build_stubbed(:organization) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(object, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it_behaves_like 'power_of_attorney'

  it 'includes :type' do
    expect(rendered_attributes[:type]).to eq 'organization'
  end

  it 'includes :name' do
    expect(rendered_attributes[:name]).to eq object.name
  end

  it 'includes :phone' do
    expect(rendered_attributes[:phone]).to eq object.phone
  end

end
