# frozen_string_literal: true

require 'rails_helper'
module Facilities
  RSpec.describe VBAFacility do
    it 'should be a VBAFacility object' do
      expect(described_class.new).to be_a(VBAFacility)
    end

    describe 'pull_source_data' do
      it 'should pull data from ArcGIS endpoint' do
        VCR.use_cassette('facilities/va/vba_facilities') do
          list = VBAFacility.pull_source_data
          expect(list.size).to eq(487)
        end
      end
      it 'should return an array of VBAFacility objects' do
        VCR.use_cassette('facilities/va/vba_facilities') do
          list = VBAFacility.pull_source_data
          expect(list).to be_an(Array)
          expect(list.all? { |item| item.is_a?(VBAFacility) })
        end
      end
    end
  end
end
