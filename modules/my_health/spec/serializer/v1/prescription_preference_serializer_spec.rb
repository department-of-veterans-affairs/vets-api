# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::PrescriptionPreferenceSerializer do
  let(:prescription_preference) { build_stubbed(:prescription_preference) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(prescription_preference, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :email_address' do
    expect(rendered_attributes[:email_address]).to eq prescription_preference.email_address
  end

  it 'includes :rx_flag' do
    expect(rendered_attributes[:rx_flag]).to eq prescription_preference.rx_flag
  end
end
