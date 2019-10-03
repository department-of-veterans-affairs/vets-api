# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProviderSerializer, type: :serializer do
  let(:provider) { build :provider }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  subject { serialize(provider, serializer_class: described_class) }

  it 'includes id' do
    expect(data['id']).to eq('ccp_' + provider.ProviderIdentifier)
  end

  it 'includes latitude' do
    expect(attributes['lat']).to eq(provider.Latitude)
  end

  it 'includes Longitude' do
    expect(attributes['long']).to eq(provider.Longitude)
  end

  it 'includes the address' do
    expect(attributes['address']['street']).to eq(provider.AddressStreet)
  end

  it 'includes the name' do
    expect(attributes['name']).to eq(provider.Name)
  end
end
