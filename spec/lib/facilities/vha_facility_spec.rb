# frozen_string_literal: true

require 'rails_helper'
require 'facilities/bulk_json_client'

RSpec.describe Facilities::VHAFacility do
  before(:each) { BaseFacility.validate_on_load = false }
  after(:each) { BaseFacility.validate_on_load = true }
  it 'should be a Facilities::VHAFacility object' do
    expect(described_class.new).to be_a(Facilities::VHAFacility)
  end

  describe 'pull_source_data' do
    it 'should pull data from a GIS endpoint' do
      VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
        list = Facilities::VHAFacility.pull_source_data
        expect(list.size).to eq(4)
        expect(list.all? { |item| item.is_a?(Facilities::VHAFacility) })
      end
    end

    context 'with single facility' do
      let(:facilities) { Facilities::VHAFacility.pull_source_data }
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

      it 'should include websites for facilities' do
        VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
          expect(facility_2.website).to eq('http://www.maine.va.gov/')
        end
      end

      it 'should indicate if a facility is mobile' do
        VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
          expect(facility.mobile).to eq(false)
          expect(facility_2.mobile).to eq(true)
        end
      end

      context 'services' do
        let(:satisfaction_data) do
          fixture_file_name = "#{::Rails.root}/spec/fixtures/facility_access/satisfaction_data.json"
          File.open(fixture_file_name, 'rb') do |f|
            JSON.parse(f.read)
          end
        end

        let(:wait_time_data) do
          fixture_file_name = "#{::Rails.root}/spec/fixtures/facility_access/wait_time_data.json"
          File.open(fixture_file_name, 'rb') do |f|
            JSON.parse(f.read)
          end
        end

        let(:sat_client_stub) { instance_double('Facilities::AccessSatisfactionClient') }
        let(:wait_client_stub) { instance_double('Facilities::AccessWaitTimeClient') }

        before(:each) do
          allow(Facilities::AccessSatisfactionClient).to receive(:new) { sat_client_stub }
          allow(Facilities::AccessWaitTimeClient).to receive(:new) { wait_client_stub }
          allow(sat_client_stub).to receive(:download).and_return(satisfaction_data)
          allow(wait_client_stub).to receive(:download).and_return(wait_time_data)
          Facilities::AccessDataDownload.new.perform
          Facilities::DentalServiceReloadJob.new.perform
        end

        it 'should parse services' do
          VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
            f1_services = facility.services
            f2_services = facility_2.services
            f1_health = f1_services['health']
            f2_health = f2_services['health']

            expect(f1_services.keys).to match(%w[last_updated health other])
            expect(f1_services['last_updated']).to eq('2017-03-31')
            expect(f1_health.size).to eq(2)
            expect(f1_health.first.keys).to eq(%w[sl1 sl2])
            expect(f1_health.first.values).to eq([['PrimaryCare'], []])
            expect(f1_health.second.keys).to eq(%w[sl1 sl2])
            expect(f1_health.second.values).to eq([['MentalHealthCare'], []])
            expect(f1_services['other']).to be_empty

            expect(f2_services.keys).to match(%w[last_updated health other])
            expect(f2_services['last_updated']).to eq('2017-03-31')
            expect(f2_health.size).to eq(3)
            expect(f2_health.first.keys).to eq(%w[sl1 sl2])
            expect(f2_health.second.keys).to eq(%w[sl1 sl2])
            expect(f2_health.first.values).to eq([['PrimaryCare'], []])
            expect(f2_health.second.values).to eq([['MentalHealthCare'], []])
            expect(f2_health.third.keys).to eq(%w[sl1 sl2])
            expect(f2_health.third.values).to eq([['DentalServices'], []])
          end
        end
      end
    end
  end
end
