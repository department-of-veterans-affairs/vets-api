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

  let(:setup_pdx) do
    %w[vc_0617V nca_907 vha_648 vha_648A4 vha_648GI vba_348 vba_348a vba_348d vba_348e vba_348h].map { |id| create id }
  end

  describe '#query' do
    it 'should find facilities' do
      setup_pdx
      VCR.use_cassette('bing/isochrone/pdx_drive_time_60',
                       match_requests_on: [:method, VCR.request_matchers.uri_without_param(:key)]) do
        expect(NearbyFacility.query(address_params).length).to eq(10)
      end
    end
    it 'should return no facilities when missing params' do
      expect(NearbyFacility.query({}).length).to eq(0)
    end
    it 'should filter by type and service' do
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
    it 'should convert a polygon array in a string' do
      polygon = [[45.451913, -122.440689], [45.451913, -122.786758], [45.64, -122.440689], [45.64, -122.786758]]
      linestring = '-122.440689 45.451913,-122.786758 45.451913,-122.440689 45.64,-122.786758 45.64'
      expect(NearbyFacility.make_linestring(polygon)).to eq(linestring)
    end
  end
end
