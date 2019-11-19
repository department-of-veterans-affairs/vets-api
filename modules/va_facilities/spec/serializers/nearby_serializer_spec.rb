# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VaFacilities::NearbySerializer, type: :serializer do
  subject { serialize(ten_min_band, serializer_class: described_class) }

  let(:ten_min_band) { create(:ten_mins_648) }
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

  it 'returns a min_time attribute' do
    expect(attributes['min_time']).to eq(0)
  end

  it 'returns a max_time attribute' do
    expect(attributes['max_time']).to eq(10)
  end

  it 'returns a relationship link to its facility' do
    fac_path = "#{VaFacilities::NearbySerializer::BASE_PATH}/facilities/vha_#{vha_648.unique_id}"
    expect(relationships['va_facility']['links']['related']).to eq(fac_path)
  end
end
