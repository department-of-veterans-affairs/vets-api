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

  it 'includes :template_id' do
    expect(attributes['template_id']).to eq notification.template_id
  end

  it 'includes :va_profile_id' do
    expect(attributes['va_profile_id']).to eq notification.va_profile_id
  end

  it 'includes :dismissed' do
    expect(attributes['dismissed']).to eq notification.dismissed
  end

  it 'includes :created_at' do
    expect_time_eq(attributes['created_at'], notification.created_at)
  end

  it 'includes :updated_at' do
    expect_time_eq(attributes['updated_at'], notification.updated_at)
  end
end
