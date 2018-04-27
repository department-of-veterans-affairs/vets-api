# frozen_string_literal: true

require 'rails_helper'

module Facilities
  VCR.configure do |c|
    c.before_record do |i|
      i.response.body.force_encoding('UTF-8')
    end
  end
  RSpec.describe VBAFacility do
    before(:each) { Facilities::FacilityMapping.validate_on_load = false }
    after(:each) { Facilities::FacilityMapping.validate_on_load = true }

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

      context 'with single facility' do
        let(:facility) { VBAFacility.pull_source_data.first }
        let(:facility_2) { VBAFacility.pull_source_data.second }
        it 'should parse hours correctly' do
          VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
            expect(facility.hours.values).to match_array(
              ['8:00AM-4:30PM', '8:00AM-4:30PM', '8:00AM-4:30PM', '8:00AM-4:30PM',
               '8:00AM-7:30PM', 'Closed', 'Please Call for Hours']
            )
          end
        end
        it 'should parse hours correctly 2' do
          VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
            expect(facility_2.hours.values).to match_array(
              %w[Closed Closed Closed Closed Closed Closed Closed]
            )
          end
        end

        it 'should parse mailing address correctly' do
          VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
            expect(facility.address['mailing']).to eq({})
          end
        end

        it 'should parse mailing address correctly' do
          VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
            expect(facility.address['physical']).to eq('address_1' => '5310 1/2 Warrensville Center Road',
                                                       'address_2' => '',
                                                       'address_3' => nil, 'city' => 'Maple Heights',
                                                       'state' => 'OH', 'zip' => '44137')
          end
        end

        it 'should parse services' do
          VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
            expect(facility.services.keys).to match_array(['benefits'])
          end
        end

        it 'should parse services' do
          VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
            expect(facility.services['benefits'].keys).to match_array(%w[other standard])
          end
        end

        it 'should parse services' do
          VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
            expect(facility.services['benefits'].values).to match_array(['Readjustment Counseling only', []])
          end
        end
      end
    end
  end
end
