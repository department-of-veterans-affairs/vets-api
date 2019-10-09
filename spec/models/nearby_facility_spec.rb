# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NearbyFacility, type: :model do
  let(:address_params) do
    { 'street_address': '9729 SE 222nd Dr',
      'city': 'Damascus',
      'state': 'OR',
      'zip': '97089',
      'drive_time': '60' }
  end
  let(:lat_lng_params) do
    { 'lat': '45.451950',
      'lng': '-122.435300',
      'drive_time': '60' }
  end

  let(:setup_pdx) do
    %w[vc_0617V nca_907 vha_648 vha_648A4 vha_648GI vba_348 vba_348a vba_348d vba_348e vba_348h].map { |id| create id }
  end

  describe '#query' do
    it 'finds facilities address' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_60',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        expect(NearbyFacility.query(address_params).length).to eq(10)
      end
    end
    it 'finds facilities with lat/lng' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_60_lat_lng',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        expect(NearbyFacility.query_by_lat_lng(lat_lng_params).length).to eq(10)
      end
    end
    it 'returns no facilities when missing address params' do
      expect(NearbyFacility.query({}).length).to eq(0)
    end
    it 'returns no facilities when missing lat/lng params' do
      expect(NearbyFacility.query_by_lat_lng({}).length).to eq(0)
    end
    it 'filters by type and service' do
      params = {
        'type': 'health',
        'services[]': 'PrimaryCare'
      }
      params.merge!(address_params)
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_60+services_primarycare',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        facilities = NearbyFacility.query(params)
        expect(facilities.length).to eq(3)
        facilities.each do |facility|
          expect(facility.facility_type).to eq('va_health_facility')
          expect(facility.services['health']).to include('sl1' => ['PrimaryCare'], 'sl2' => [])
        end
      end
    end
  end

  describe '#make_linestring' do
    it 'converts a polygon array in a string' do
      polygon = [[45.451913, -122.440689], [45.451913, -122.786758], [45.64, -122.440689], [45.64, -122.786758]]
      linestring = '-122.440689 45.451913,-122.786758 45.451913,-122.440689 45.64,-122.786758 45.64'
      expect(NearbyFacility.make_linestring(polygon)).to eq(linestring)
    end
  end

  describe 'parsing location response' do
    it 'extracts coordinates' do
      json = JSON.parse('{"resourceSets": [{"resources": [{"point": {"coordinates": [1,2]}}]}]}')
      result = NearbyFacility.parse_location(json)
      result.should_not be_nil
      result.should match_array([1, 2])
    end

    it 'returns nil and not throw an exception when resourceSets is not defined' do
      json = JSON.parse('{"dfsfasf": [{"resources": [{"point": {"coordinates": [1,2]}}]}]}')
      result = NearbyFacility.parse_location(json)
      result.should be_nil
    end

    it 'returns nil and not throw an exception when resources is not defined' do
      json = JSON.parse('{"resourceSets": [{"resourcesadf": [{"point": {"coordinates": [1,2]}}]}]}')
      result = NearbyFacility.parse_location(json)
      result.should be_nil
    end

    it 'returns nil and not throw an exception when point is not defined' do
      json = JSON.parse('{"resourceSets": [{"resources": [{"podfsfint": {"coordinates": [1,2]}}]}]}')
      result = NearbyFacility.parse_location(json)
      result.should be_nil
    end

    it 'returns nil and not throw an exception when coordinates is not defined' do
      json = JSON.parse('{"resourceSets": [{"resources": [{"point": {"dfsfdsf": [1,2]}}]}]}')
      result = NearbyFacility.parse_location(json)
      result.should be_nil
    end
  end
end
