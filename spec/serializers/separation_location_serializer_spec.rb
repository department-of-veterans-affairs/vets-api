# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SeparationLocationSerializer, type: :serializer do
  subject { described_class.new(intake_sites_response).to_json }

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

  let(:data) { JSON.parse(subject) }
  let(:attributes) { data['attributes'] }

  it 'includes :status' do
    expect(data['status']).to eq intake_sites_response.status
  end

  it 'includes :separation_locations as an array' do
    expect(data['separation_locations'].size).to eq intake_sites_response.separation_locations.size
    expect(data['separation_locations'].first['code']).to eq intake_sites_response.separation_locations.first.code
  end
end
