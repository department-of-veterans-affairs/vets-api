# frozen_string_literal: true

require 'rails_helper'
module Facilities
  RSpec.describe VCFacility do
    before { BaseFacility.validate_on_load = false }

    after { BaseFacility.validate_on_load = true }

    it 'is a VCFacility object' do
      expect(described_class.new).to be_a(VCFacility)
    end

    describe 'pull_source_data' do
      it 'pulls data from ArcGIS endpoint' do
        VCR.use_cassette('facilities/va/vc_facilities') do
          list = VCFacility.pull_source_data
          expect(list.size).to eq(10)
        end
      end

      it 'returns an array of VCFacility objects' do
        VCR.use_cassette('facilities/va/vc_facilities') do
          list = VCFacility.pull_source_data
          expect(list).to be_an(Array)
          expect(list.all? { |item| item.is_a?(VCFacility) })
        end
      end
    end
  end
end
