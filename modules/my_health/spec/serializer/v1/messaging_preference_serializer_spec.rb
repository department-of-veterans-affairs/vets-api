# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::MessagingPreferenceSerializer do
  let(:messaging_preference) { build_stubbed(:messaging_preference) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(messaging_preference, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :email_address' do
    expect(rendered_attributes[:email_address]).to eq messaging_preference.email_address
  end

  it 'includes :frequency' do
    expect(rendered_attributes[:frequency]).to eq messaging_preference.frequency
  end
end
