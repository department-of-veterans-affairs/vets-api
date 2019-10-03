# frozen_string_literal: true

require 'rails_helper'
module Facilities
  RSpec.describe NCAFacility do
    before(:each) { BaseFacility.validate_on_load = false }

    after(:each) { BaseFacility.validate_on_load = true }

    it 'is an NCAFacility object' do
      expect(described_class.new).to be_an(NCAFacility)
    end

    describe 'pull_source_data' do
      it 'pulls data from ArcGIS endpoint' do
        VCR.use_cassette('facilities/va/nca_facilities') do
          list = NCAFacility.pull_source_data
          expect(list.size).to eq(10)
        end
      end

      it 'returns an array of NCAFacility objects' do
        VCR.use_cassette('facilities/va/nca_facilities') do
          list = NCAFacility.pull_source_data
          expect(list).to be_an(Array)
          expect(list.all? { |item| item.is_a?(NCAFacility) })
        end
      end

      context 'with single facility' do
        let(:facilities) { NCAFacility.pull_source_data }
        let(:facility) { facilities.first }

        it 'gets the correct classification name' do
          VCR.use_cassette('facilities/va/nca_facilities') do
            expect(facility.classification).to eq('Soldiers Lot')
          end
        end
      end
    end
  end
end
