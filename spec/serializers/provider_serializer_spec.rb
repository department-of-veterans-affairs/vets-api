# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProviderSerializer, type: :serializer do
  subject(:serialized_provider) { serialize(provider, serializer_class: described_class) }

  let(:provider) { build :provider, :from_provider_locator }
  let(:data) { JSON.parse(serialized_provider)['data'] }
  let(:attributes) { data['attributes'] }

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

  context 'Flipper facilities_ppms_caresite_name: true' do
    before do
      Flipper.enable(:facilities_ppms_caresite_name)
    end

    context "ProviderType is 'GroupPracticeOrAgency'" do
      let(:provider) { build :provider, :from_provider_locator, ProviderType: 'GroupPracticeOrAgency' }

      it 'includes the caresite name' do
        expect(attributes['name']).to eq(provider.CareSite)
      end
    end

    context "ProviderType is 'Individual'" do
      let(:provider) { build :provider, :from_provider_locator, ProviderType: 'Individual' }

      it 'includes the caresite name' do
        expect(attributes['name']).to eq(provider.ProviderName)
      end
    end
  end

  context 'Flipper facilities_ppms_caresite_name: false' do
    before do
      Flipper.disable(:facilities_ppms_caresite_name)
    end

    context "ProviderType is 'GroupPracticeOrAgency'" do
      let(:provider) { build :provider, :from_provider_locator, ProviderType: 'GroupPracticeOrAgency' }

      it 'includes the caresite name' do
        expect(attributes['name']).to eq(provider.ProviderName)
      end
    end

    context "ProviderType is 'Individual'" do
      let(:provider) { build :provider, :from_provider_locator, ProviderType: 'Individual' }

      it 'includes the caresite name' do
        expect(attributes['name']).to eq(provider.ProviderName)
      end
    end
  end
end
