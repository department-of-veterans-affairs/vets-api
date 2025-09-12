# frozen_string_literal: true

require 'rails_helper'

describe PreferredNameSerializer, type: :serializer do
  subject { serialize(preferred_name_response, serializer_class: described_class) }

  let(:preferred_name_response) { build(:preferred_name_response) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :preferred_name' do
    expect(attributes['preferred_name']).to match(preferred_name_response.preferred_name.attributes.deep_stringify_keys)
  end
end
