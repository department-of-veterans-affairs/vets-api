# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSSSeparationLocationSerializer, type: :serializer do
  subject { serialize(intake_sites_response, serializer_class: described_class) }

  let(:separation_locations) do
    [
      DisabilityCompensation::ApiProvider::SeparationLocation.new(code: 98_283, description: 'AF Academy'),
      DisabilityCompensation::ApiProvider::SeparationLocation.new(code: 123_558, description: 'ANG Hub'),
      DisabilityCompensation::ApiProvider::SeparationLocation.new(code: 98_282, description: 'Aberdeen Proving Ground')
    ]
  end
  let(:intake_sites_response) do
    DisabilityCompensation::ApiProvider::IntakeSitesResponse.new(status: 200, separation_locations:)
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :separation_locations as an array' do
    expect(attributes['separation_locations'].size).to eq intake_sites_response.separation_locations.size
    expect(attributes['separation_locations'].first['code']).to eq intake_sites_response.separation_locations.first.code
  end
end
