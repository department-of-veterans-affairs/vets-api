# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facilities::VBAFacility do
  VCR.configure do |c|
    c.before_record do |i|
      i.response.body.force_encoding('UTF-8')
    end
  end
  before { BaseFacility.validate_on_load = false }

  after { BaseFacility.validate_on_load = true }

  it 'is a Facilities::VBAFacility object' do
    expect(described_class.new).to be_a(Facilities::VBAFacility)
  end

  describe 'pull_source_data' do
    it 'pulls data from ArcGIS endpoint' do
      VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
        list = Facilities::VBAFacility.pull_source_data
        expect(list.size).to eq(6)
      end
    end

    it 'returns an array of Facilities::VBAFacility objects' do
      VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
        list = Facilities::VBAFacility.pull_source_data
        expect(list).to be_an(Array)
        expect(list.all? { |item| item.is_a?(Facilities::VBAFacility) }).to be true
      end
    end

    context 'with single facility' do
      let(:facility) { Facilities::VBAFacility.pull_source_data.first }
      let(:facility_2) { Facilities::VBAFacility.pull_source_data.second }

      it 'parses hours correctly' do
        VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
          expect(facility.hours.values).to match_array(
            ['8:00AM-4:30PM', '8:00AM-4:30PM', '8:00AM-4:30PM', '8:00AM-4:30PM',
             '8:00AM-7:30PM', 'Closed', 'Please Call for Hours']
          )
        end
      end

      it 'parses hours correctly 2' do
        VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
          expect(facility_2.hours.values).to match_array(
            %w[Closed Closed Closed Closed Closed Closed Closed]
          )
        end
      end

      it 'parses phone correctly' do
        VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
          expect(facility.phone.values).to match_array(
            %w[
              216-707-7901
              216-707-7902
            ]
          )
        end
      end

      it 'parses mailing address correctly' do
        VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
          expect(facility.address['mailing']).to eq({})
        end
      end

      it 'parses physical address correctly' do
        VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
          expect(facility.address['physical']).to eq('address_1' => '5310 1/2 Warrensville Center Road',
                                                     'address_2' => '',
                                                     'address_3' => nil, 'city' => 'Maple Heights',
                                                     'state' => 'OH', 'zip' => '44137')
        end
      end

      it 'parses services' do
        VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
          expect(facility.services.keys).to match_array(['benefits'])
        end
      end

      it 'parses benefits keys' do
        VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
          expect(facility.services['benefits'].keys).to match_array(%w[other standard])
        end
      end

      it 'parses benefits values' do
        VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
          expect(facility.services['benefits'].values).to match_array(['Readjustment Counseling only', []])
        end
      end

      it 'gets the correct classification name' do
        VCR.use_cassette('facilities/va/vba_facilities_limit_results') do
          expect(facility.classification).to eq('OUTBASED')
        end
      end
    end
  end
end
