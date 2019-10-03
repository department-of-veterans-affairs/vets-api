# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DrivetimeBand do
  it 'should belong to a facility' do
    create :vha_648
    create :thirty_mins

    band_facility = DrivetimeBand.first.vha_facility

    expect(band_facility).to be_a(Facilities::VHAFacility)
    expect(band_facility.unique_id).to eq('648')
  end
end
