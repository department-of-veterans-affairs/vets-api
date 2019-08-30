# frozen_string_literal: true

require 'rails_helper'
module Facilities
  RSpec.describe VHAFacility do
    before(:each) { BaseFacility.validate_on_load = false }
    after(:each) { BaseFacility.validate_on_load = true }
    it 'should be a VHAFacility object' do
      expect(described_class.new).to be_a(VHAFacility)
    end

    describe 'pull_source_data' do
      it 'should pull data from ArcGIS endpoint' do
        VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
          list = VHAFacility.pull_source_data
          expect(list.size).to eq(4)
          expect(list.all? { |item| item.is_a?(VHAFacility) })
        end
      end

      context 'with single facility' do
        let(:facilities) { VHAFacility.pull_source_data }
        let(:facility) { facilities.first }
        let(:facility_2) { facilities.second }
        it 'should parse hours correctly' do
          VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
            expect(facility.hours.values).to match_array(
              ['730AM-430PM', '730AM-430PM', '730AM-430PM', '730AM-430PM', '730AM-430PM', 'Closed', 'Closed']
            )
          end
        end

        it 'should parse mailing address correctly' do
          VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
            expect(facility.address['mailing']).to eq({})
          end
        end

        it 'should parse mailing address correctly' do
          VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
            expect(facility.address['physical']).to eq('address_1' => '1501 Roxas Boulevard',
                                                       'address_2' => 'NOX3 Seafront Compound',
                                                       'address_3' => nil, 'city' => 'Pasay City',
                                                       'state' => 'PH', 'zip' => '01302')
          end
        end

        it 'should include just be 5 digit if zip +4 is empty' do
          VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
            expect(facility.address['physical']['zip']).to eq('01302')
          end
        end

        it 'should include zip +4 when available' do
          VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
            expect(facility_2.address['physical']['zip']).to eq('04330-6796')
          end
        end

        context 'services' do
          it 'does not include services from just GIS data' do
            VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
              expect(facility.services.keys).to match(%w[last_updated health other])
              expect(facility.services['last_updated']).to eq('2019-09-07')
              expect(facility.services['health']).to be_empty
              expect(facility.services['other']).to be_empty
            end
          end
        end
      end
    end
  end
end
