# frozen_string_literal: true

require 'rails_helper'

describe OnsiteNotificationSerializer, type: :serializer do
  subject { serialize(notification, serializer_class: described_class) }

  let(:notification) { build_stubbed(:onsite_notification) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq notification.id.to_s
  end

  it 'includes all input attributes' do
    expected_attributes = notification.attributes.keys - ['id']
    expect(attributes.keys).to eq expected_attributes
  end
end
