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
        VCR.use_cassette('facilities/va/vha_facilities') do
          list = VHAFacility.pull_source_data
          expect(list.size).to eq(1186)
          expect(list.all? { |item| item.is_a?(VHAFacility) })
        end
      end

      context 'with single facility' do
        let(:facility) { VHAFacility.pull_source_data.first }
        let(:facility_2) { VHAFacility.pull_source_data.second }
        it 'should parse hours correctly' do
          VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
            expect(facility.hours.values).to match_array(
              ['730AM-430PM', '730AM-430PM', '730AM-430PM', '730AM-430PM', '730AM-430PM', '-', '-']
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
                                                       'state' => 'PI', 'zip' => '01302')
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
          it 'should parse services' do
            VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
              expect(facility.services.keys).to match(%w[last_updated health])
              expect(facility.services['last_updated']).to eq('2018-02-09')
              expect(facility.services['health'].size).to eq(2)
              expect(facility.services['health'].first.keys).to eq(%w[sl1 sl2])
              expect(facility.services['health'].first.values).to eq([['MentalHealthCare'], []])
              expect(facility.services['health'].second.keys).to eq(%w[sl1 sl2])
              expect(facility.services['health'].second.values).to eq([['PrimaryCare'], []])
            end
          end

          it 'should parse services 2' do
            VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
              expect(facility_2.services.keys).to match(%w[last_updated health])
              expect(facility_2.services['last_updated']).to eq('2018-02-09')
              expect(facility_2.services['health'].size).to eq(3)
              expect(facility_2.services['health'].first.keys).to eq(%w[sl1 sl2])
              expect(facility_2.services['health'].first.values).to eq([['DentalServices'], []])
              expect(facility_2.services['health'].second.keys).to eq(%w[sl1 sl2])
              expect(facility_2.services['health'].second.values).to eq([['MentalHealthCare'], []])
              expect(facility_2.services['health'].third.keys).to eq(%w[sl1 sl2])
              expect(facility_2.services['health'].third.values).to eq([['PrimaryCare'], []])
            end
          end
        end
      end
    end
  end
end
