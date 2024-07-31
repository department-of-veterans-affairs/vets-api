# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::MessagingPreferenceSerializer, type: :serializer do
  subject { serialize(messaging_preference, serializer_class: described_class) }

  let(:messaging_preference) { build_stubbed(:messaging_preference) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :email_address' do
    expect(attributes['email_address']).to eq messaging_preference.email_address
  end

  it 'includes :frequency' do
    expect(attributes['frequency']).to eq messaging_preference.frequency
  end
end
