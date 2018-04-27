# frozen_string_literal: true

require 'rails_helper'
module Facilities
  RSpec.describe NCAFacility do
    before(:each) { Facilities::FacilityMapping.validate_on_load = false }
    after(:each) { Facilities::FacilityMapping.validate_on_load = true }

    it 'should be an NCAFacility object' do
      expect(described_class.new).to be_an(NCAFacility)
    end

    describe 'pull_source_data' do
      it 'should pull data from ArcGIS endpoint' do
        VCR.use_cassette('facilities/va/nca_facilities') do
          list = NCAFacility.pull_source_data
          expect(list.size).to eq(173)
        end
      end

      it 'should return an array of NCAFacility objects' do
        VCR.use_cassette('facilities/va/nca_facilities') do
          list = NCAFacility.pull_source_data
          expect(list).to be_an(Array)
          expect(list.all? { |item| item.is_a?(NCAFacility) })
        end
      end
    end
  end
end
