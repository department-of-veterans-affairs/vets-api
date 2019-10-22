# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GeocodingService do
  it 'converts an address to a lat/lng pair' do
    address = {
      street_address: '1 VA Center',
      city: 'Augusta',
      state: 'ME',
      zip: '04330'
    }

    VCR.use_cassette('bing/geocoding/vha_402',
                     match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
      resp = subject.query(address)
      expect(resp[:lat]).to eq(44.27874833)
      expect(resp[:lng]).to eq(-69.70363833)
    end
  end
end
