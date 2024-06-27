# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facilities::VHAFacility do
  before { BaseFacility.validate_on_load = false }

  after { BaseFacility.validate_on_load = true }

  it 'is a Facilities::VHAFacility object' do
    expect(described_class.new).to be_a(Facilities::VHAFacility)
  end

  it 'is able to have multiple DrivetimeBands' do
    create :vha_648
    create :ten_mins_648
    create :twenty_mins_648

    bands = Facilities::VHAFacility.first.drivetime_bands

    expect(bands.length).to eq(2)
  end

  describe 'pull_source_data' do
    it 'pulls data from a GIS endpoint' do
      VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
        list = Facilities::VHAFacility.pull_source_data
        expect(list.size).to eq(4)
        expect(list.all? { |item| item.is_a?(Facilities::VHAFacility) }).to be true
      end
    end

    context 'with single facility' do
      let(:facilities) { Facilities::VHAFacility.pull_source_data }
      let(:facility) { facilities.first }
      let(:facility_2) { facilities.second }

      it 'parses hours correctly' do
        VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
          expect(facility.hours.values).to match_array(
            %w[730AM-430PM 730AM-430PM 730AM-430PM 730AM-430PM 730AM-430PM Closed Closed]
          )
        end
      end

      it 'parses phone correctly' do
        VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
          expect(facility.phone.values).to contain_exactly('000-000-0000', '632-310-5962', '632-550-3888',
                                                           '632-550-3888 x3716', '632-550-3888 x3780',
                                                           '632-550-3888 x5029')
        end
      end

      it 'parses mailing address correctly' do
        VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
          expect(facility.address['mailing']).to eq({})
        end
      end

      it 'parses physical address correctly' do
        VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
          expect(facility.address['physical']).to eq('address_1' => '1501 Roxas Boulevard',
                                                     'address_2' => 'NOX3 Seafront Compound',
                                                     'address_3' => nil, 'city' => 'Pasay City',
                                                     'state' => 'PH', 'zip' => '01302')
        end
      end

      it 'includes just be 5 digit if zip +4 is empty' do
        VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
          expect(facility.address['physical']['zip']).to eq('01302')
        end
      end

      it 'includes zip +4 when available' do
        VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
          expect(facility_2.address['physical']['zip']).to eq('04330-6796')
        end
      end

      it 'includes websites for facilities' do
        VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
          expect(facility_2.website).to eq('https://www.maine.va.gov/locations/directions.asp')
        end
      end

      it 'includes active status for facilities' do
        VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
          expect(facility_2.active_status).to eq('A')
        end
      end

      it 'indicates if a facility is mobile' do
        VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
          expect(facility.mobile).to eq(false)
          expect(facility_2.mobile).to eq(true)
        end
      end

      it 'includes visn for vha facilities' do
        VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
          expect(facility.visn).to eq('21')
          expect(facility_2.visn).to eq('1')
        end
      end

      it 'gets the correct classification name' do
        VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
          expect(facility.classification).to eq('Other Outpatient Services (OOS)')
          expect(facility_2.classification).to eq('VA Medical Center (VAMC)')
        end
      end

      context 'with mental health data' do
        before do
          attrs1 = {
            station_number: '358',
            mh_phone: '407-123-1234',
            mh_ext: nil,
            modified: '2019-09-06T13:00:00.000',
            local_updated: Time.now.utc.iso8601
          }

          attrs2 = {
            station_number: '402',
            mh_phone: '321-987-6543',
            mh_ext: '0002',
            modified: '2019-09-06T13:00:00.000',
            local_updated: Time.now.utc.iso8601
          }

          FacilityMentalHealth.create(attrs1)
          FacilityMentalHealth.create(attrs2)
        end

        it 'adds mental health info for facilities' do
          VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
            expect(facility.phone['mental_health_clinic']).to eq('407-123-1234')
            expect(facility_2.phone['mental_health_clinic']).to eq('321-987-6543 x 0002')
          end
        end
      end

      context 'with services' do
        let(:satisfaction_data) do
          fixture_file_name = Rails.root.join('spec', 'fixtures', 'facility_access', 'satisfaction_data.json')
          File.open(fixture_file_name, 'rb') do |f|
            JSON.parse(f.read)
          end
        end

        let(:wait_time_data) do
          fixture_file_name = Rails.root.join('spec', 'fixtures', 'facility_access', 'wait_time_data.json')
          File.open(fixture_file_name, 'rb') do |f|
            JSON.parse(f.read)
          end
        end

        let(:sat_client_stub) { instance_double('Facilities::AccessSatisfactionClient') }
        let(:wait_client_stub) { instance_double('Facilities::AccessWaitTimeClient') }

        before do
          allow(Facilities::AccessSatisfactionClient).to receive(:new) { sat_client_stub }
          allow(Facilities::AccessWaitTimeClient).to receive(:new) { wait_client_stub }
          allow(sat_client_stub).to receive(:download).and_return(satisfaction_data)
          allow(wait_client_stub).to receive(:download).and_return(wait_time_data)
          Facilities::AccessDataDownload.new.perform
          Facilities::DentalServiceReloadJob.new.perform
        end

        it 'parses services' do
          VCR.use_cassette('facilities/va/vha_facilities_limit_results') do
            f2_services = facility_2.services
            f2_health = f2_services['health']

            expect(f2_services.keys).to match(%w[last_updated health other])
            expect(f2_services['last_updated']).to eq('2017-03-31')
            expect(f2_health.size).to eq(3)
            expect(f2_health.first.keys).to eq(%w[sl1 sl2])
            expect(f2_health.second.keys).to eq(%w[sl1 sl2])
            expect(f2_health.first.values).to eq([['PrimaryCare'], []])
            expect(f2_health.second.values).to eq([['MentalHealthCare'], []])
            expect(f2_health.third.keys).to eq(%w[sl1 sl2])
            expect(f2_health.third.values).to eq([['DentalServices'], []])
            expect(f2_services['other']).to be_empty
          end
        end
      end
    end
  end

  describe 'with_services' do
    it 'returns a list of facilities that provide the selected services' do
      create :vha_648A4
      create :vha_648
      create :vha_648GI

      result = Facilities::VHAFacility.with_services(['UrgentCare'])
      expect(result.length).to eq(1)
      expect(result.first.unique_id).to eq('648')
    end
  end
end
