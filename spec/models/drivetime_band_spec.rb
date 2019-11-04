# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DrivetimeBand do
  let(:create_bands) do
    create :vha_648
    create :vha_648GI
    create :ten_mins_648
    create :twenty_mins_648
    create :ten_mins_648GI
    create :twenty_mins_648GI
  end

  it 'belongs to a facility' do
    create :vha_648
    create :ten_mins_648

    band_facility = DrivetimeBand.first.vha_facility

    expect(band_facility).to be_a(Facilities::VHAFacility)
    expect(band_facility.unique_id).to eq('648')
  end

  describe 'find_within_max_distance' do
    it 'returns bands that intersect a point <= a max time' do
      create_bands

      bands = DrivetimeBand.find_within_max_distance(45.4967668, -122.6832211, 10, nil)

      expect(bands.length).to eq(1)
      expect(bands.first.name).to eq('648 : 0 - 10')
    end

    it 'only finds for a subset facilities if a list of ids is provided' do
      create_bands

      bands = DrivetimeBand.find_within_max_distance(45.4967668, -122.6832211, 20, ['648GI'])

      expect(bands.length).to eq(1)
      expect(bands.first.name).to eq('648GI : 10 - 20')
    end
  end
end
