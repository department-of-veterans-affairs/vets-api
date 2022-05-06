# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::FacilitiesHelper, type: :model do
  describe 'haversine distance' do
    it 'correctly calculates a close distance', :aggregate_failures do
      geo_a = [40.024910, -83.015700]
      geo_b = [40.023100, -83.014010]
      miles = Mobile::FacilitiesHelper.haversine_distance(geo_a, geo_b)
      expect(miles).to eq(0.15463551668049716)
    end

    it 'correctly calculates a far distance', :aggregate_failures do
      geo_a = [40.024910, -83.015700]
      geo_b = [42.351089, -83.060280]
      miles = Mobile::FacilitiesHelper.haversine_distance(geo_a, geo_b)
      expect(miles).to eq(161.678869083382)
    end
  end
end
