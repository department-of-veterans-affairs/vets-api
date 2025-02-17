# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CategorySerializer do
  subject { serialize(category, serializer_class: described_class) }

  let(:category) { build(:category) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes :id' do
    expect(data['id'].to_i).to eq(category.category_id)
  end

  it 'includes :type' do
    expect(data['type']).to eq('categories')
  end

  it 'includes :message_category_type' do
    expect(attributes['message_category_type']).to eq(category.message_category_type)
  end
end
