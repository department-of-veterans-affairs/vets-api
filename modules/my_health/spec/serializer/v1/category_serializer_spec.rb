# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::CategorySerializer, type: :serializer do
  subject { serialize(category, serializer_class: described_class) }

  let(:category) { build_stubbed(:category) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq category.category_id.to_s
  end

  it 'includes :message_category_type' do
    expect(attributes['message_category_type']).to eq category.message_category_type
  end
end
