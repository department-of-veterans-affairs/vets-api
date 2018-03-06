# frozen_string_literal: true

require 'rails_helper'
module Facilities
  RSpec.describe VHAFacility do
    it 'should be a VHAFacility object' do
      expect(described_class.new).to be_a(VHAFacility)
    end

    describe 'pull_source_data' do
      it 'should pull data from ArcGIS endpoint' do
        VCR.use_cassette('facilities/va/vha_facilities') do
          list = VHAFacility.pull_source_data
          expect(list.size).to eq(1000)
        end
      end

      it 'should return an array of VHAFacility objects' do
        VCR.use_cassette('facilities/va/vha_facilities') do
          list = VHAFacility.pull_source_data
          expect(list).to be_an(Array)
          expect(list.all? { |item| item.is_a?(VHAFacility) })
        end
      end
    end
  end
end
