# frozen_string_literal: true

require 'rails_helper'

describe RepresentationManagement::FlaggedVeteranRepresentativeContactDataSerializer, type: :serializer do
  subject { serialize(contact_data, serializer_class: described_class) }

  let(:contact_data) { build_stubbed(:flagged_veteran_representative_contact_data) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :ip_address' do
    expect(attributes['ip_address']).to eq contact_data.ip_address
  end

  it 'includes :representative_id' do
    expect(attributes['representative_id']).to eq contact_data.representative_id
  end

  it 'includes :flag_type' do
    expect(attributes['flag_type']).to eq contact_data.flag_type
  end

  it 'includes :flagged_value' do
    expect(attributes['flagged_value']).to eq contact_data.flagged_value
  end
end
