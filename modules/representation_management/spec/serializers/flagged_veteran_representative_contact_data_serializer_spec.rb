# frozen_string_literal: true

require 'rails_helper'

describe RepresentationManagement::FlaggedVeteranRepresentativeContactDataSerializer do
  let(:contact_data) { build_stubbed(:flagged_veteran_representative_contact_data) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(contact_data, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :ip_address' do
    expect(rendered_attributes[:ip_address]).to eq contact_data.ip_address
  end

  it 'includes :representative_id' do
    expect(rendered_attributes[:representative_id]).to eq contact_data.representative_id
  end

  it 'includes :flag_type' do
    expect(rendered_attributes[:flag_type]).to eq contact_data.flag_type
  end

  it 'includes :flagged_value' do
    expect(rendered_attributes[:flagged_value]).to eq contact_data.flagged_value
  end
end
