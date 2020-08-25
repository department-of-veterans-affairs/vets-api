# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facilities::VCFacility do
  before { BaseFacility.validate_on_load = false }

  after { BaseFacility.validate_on_load = true }

  it 'is a Facilities::VCFacility object' do
    expect(described_class.new).to be_a(Facilities::VCFacility)
  end

  describe 'pull_source_data' do
    it 'pulls data from ArcGIS endpoint' do
      VCR.use_cassette('facilities/va/vc_facilities') do
        list = Facilities::VCFacility.pull_source_data
        expect(list.size).to eq(10)
      end
    end

    it 'returns an array of Facilities::VCFacility objects' do
      VCR.use_cassette('facilities/va/vc_facilities') do
        list = Facilities::VCFacility.pull_source_data
        expect(list).to be_an(Array)
        expect(list.all? { |item| item.is_a?(Facilities::VCFacility) }).to be true
      end
    end
  end
end
