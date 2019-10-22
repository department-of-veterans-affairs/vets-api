# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Nearby Facilities API endpoint', type: :request do

  let(:base_query_path) { '/services/va_facilities/v1/nearby' }
  let(:address_params) { '?street_address=1%20VA%20Center&city=Augusta&state=ME&zip=04330&drive_time=20' }
  # let(:lat_lng_params) { '?lat=44.2852359&lng=-69.6989011&drive_time=60' }
  let(:drivetime_bands) do
    create :ten_mins_402
    create :twenty_mins_402
    create :thirty_mins_402
  end

  before do
    create :vha_402
    drivetime_bands
  end

  describe 'get drive time' do

    it 'can be retrieved with an address' do
      VCR.use_cassette('bing/geocoding/vha_402',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        get base_query_path + address_params, params: nil#{street_address: '1 VA Center', city: 'Augusta', state: 'ME', zip: 04330, drive_time: '20'}
        expect(response).to be_successful
        expect(response.body).to be_a(String)
        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(10)
        expect(json['meta']['distances']).to eq([])
      end
    end
  end

end