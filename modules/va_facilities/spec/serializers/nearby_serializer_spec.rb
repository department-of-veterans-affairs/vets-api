# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VaFacilities::NearbySerializer, type: :serializer do
  subject { serialize(thirty, serializer_class: described_class) }

  let(:thirty) { create(:thirty_mins) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:relationships) { data['relationships'] }
  let(:vha_648) { create(:vha_648) }

  before { vha_648 }

  it 'returns an id' do
    expect(data['id']).to eq('vha_648')
  end

  it 'returns a type' do
    expect(data['type']).to eq('nearby_facility')
  end

  it 'returns a drivetime_band_min attribute' do
    expect(attributes['drivetime_band_min']).to eq(20)
  end

  it 'returns a drivetime_band_max attribute' do
    expect(attributes['drivetime_band_max']).to eq(30)
  end

  it 'returns a relationship link to its facility' do
    fac_path = "#{VaFacilities::NearbySerializer::BASE_PATH}/facilities/vha_#{vha_648.unique_id}"
    expect(relationships['va_facilities']['links']['related']).to eq(fac_path)
  end

  it 'returns a relationship link to its drivetime band' do
    band_path = "#{VaFacilities::NearbySerializer::BASE_PATH}/drivetime_bands/#{thirty.id}"
    expect(relationships['drivetime_band']['links']['related']).to eq(band_path)
  end
end
