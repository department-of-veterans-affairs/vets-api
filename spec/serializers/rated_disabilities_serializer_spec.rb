# frozen_string_literal: true

require 'rails_helper'

describe RatedDisabilitiesSerializer, type: :serializer do
  subject { serialize(rated_disabilities_response, serializer_class: described_class) }

  let(:rated_disabilities_response) { build(:rated_disabilities_response) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :rated_disabilities' do
    expect(attributes['rated_disabilities'].size).to eq rated_disabilities_response.rated_disabilities.size
  end

  it 'includes :rated_disabilities with attributes' do
    expected_attributes = rated_disabilities_response.rated_disabilities.first.attributes.keys.map(&:to_s)
    expect(attributes['rated_disabilities'].first.keys).to eq expected_attributes
  end
end
