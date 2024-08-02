# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::PrescriptionPreferenceSerializer, type: :serializer do
  subject { serialize(prescription_preference, serializer_class: described_class) }

  let(:prescription_preference) { build_stubbed(:prescription_preference) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :email_address' do
    expect(attributes['email_address']).to eq prescription_preference.email_address
  end

  it 'includes :rx_flag' do
    expect(attributes['rx_flag']).to eq prescription_preference.rx_flag
  end
end
