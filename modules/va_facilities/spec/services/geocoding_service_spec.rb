# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GeocodingService do
  it 'converts an address to a lat/lng pair' do
    street_address = '3710 Southwest US Veterans Hospital Road'
    city = 'Portland'
    state = 'OR'
    zip = '97239'

    VCR.use_cassette('bing/geocoding/vha_648',
                     match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
      resp = subject.query(street_address, city, state, zip)
      expect(resp[:lat]).to eq(45.496474)
      expect(resp[:lng]).to eq(-122.68319)
    end
  end
end
