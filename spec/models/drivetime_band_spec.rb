# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DrivetimeBand do
  let(:create_bands) do
    create :vha_402
    create :ten_mins_402
    create :twenty_mins_402
    create :thirty_mins_402
  end

  it 'belongs to a facility' do
    create :vha_648
    create :thirty_mins

    band_facility = DrivetimeBand.first.vha_facility

    expect(band_facility).to be_a(Facilities::VHAFacility)
    expect(band_facility.unique_id).to eq('648')
  end

  describe 'find_within_max_distance' do
    it 'returns bands that intersect a point <= a max time' do
      create_bands
      bands = DrivetimeBand.find_within_max_distance(44.27874833, -69.70363833, 20)
      
      expect(bands.length).to eq(1)
      expect(bands.first.name).to eq('402 : 0 - 10')
    end
  end
end
