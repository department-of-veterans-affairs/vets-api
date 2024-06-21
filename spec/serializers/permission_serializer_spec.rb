# frozen_string_literal: true

require 'rails_helper'

describe PermissionSerializer, type: :serializer do
  subject { serialize(permission, serializer_class: described_class) }

  let(:permission) { build_stubbed(:permission) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :permission_type' do
    expect(attributes['permission_type']).to eq permission.permission_type
  end

  it 'includes :permission_value' do
    expect(attributes['permission_value']).to eq permission.permission_value
  end
end
