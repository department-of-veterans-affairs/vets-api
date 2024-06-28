# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::CategorySerializer do
  let(:category) { build_stubbed(:category) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(category, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to eq category.category_id.to_s
  end

  it 'includes :message_category_type' do
    expect(rendered_attributes[:message_category_type]).to eq category.message_category_type
  end
end
