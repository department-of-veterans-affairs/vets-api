# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/facilities/v1/client'

RSpec.describe Lighthouse::Facilities::V1::Client do
  let(:client) { described_class.new }
  let(:params) { { bbox: [60.99, 10.54, 180.00, 20.55] } }
  let(:data) do
    [
      { 'id' => 'vha_042',
        'attributes' => {
          'name' => 'Facility One',
          'facilityType' => 'va_health_facility',
          'mobile' => true
        } },
      { 'id' => 'vha_043', 'attributes' => {
        'name' => 'Facility Two',
        'facilityType' => 'va_health_facility'
      } }
    ]
  end

  let(:meta) do
    {
      'pagination' => {
        'currentPage' => 1,
        'perPage' => 10,
        'totalEntries' => 20
      },
      'distances' => [
        { 'distance' => 5.0 },
        { 'distance' => 10.0 }
      ]
    }
  end

  let(:mock_response_body) do
    {
      'links' => {},
      'meta' => meta,
      'data' => data
    }.to_json
  end

  let(:mock_response) { instance_double(Faraday::Response, body: mock_response_body, status: 200) }

  describe '#get_facilities' do
    context 'when exclude_mobile is not specified' do
      it 'returns all facilities' do
        allow(client).to receive(:perform).with(:get, '/services/va_facilities/v1/facilities',
                                                params).and_return(mock_response)

        facilities = client.get_facilities(params)

        expect(facilities).to be_an(Array)
        expect(facilities.size).to eq(2)
        expect(facilities.map(&:id)).to include('vha_042', 'vha_043')
      end
    end

    context 'when exclude_mobile is specified' do
      it 'filters out mobile facilities' do
        params_with_exclude_mobile = params.merge('exclude_mobile' => true)
        allow(client).to receive(:perform).with(:get, '/services/va_facilities/v1/facilities',
                                                params_with_exclude_mobile).and_return(mock_response)

        facilities = client.get_facilities(params_with_exclude_mobile)

        expect(facilities).to be_an(Array)
        expect(facilities.size).to eq(1)
        expect(facilities.first.id).to eq('vha_043')
      end
    end
  end

  describe '#get_paginated_facilities' do
    it 'returns a response object' do
      allow(client).to receive(:perform).with(:get, '/services/va_facilities/v1/facilities',
                                              params).and_return(mock_response)

      response = client.get_paginated_facilities(params)

      expect(response).to be_a(Lighthouse::Facilities::V1::Response)
      expect(response.facilities).to be_an(Array)
      expect(response.meta).to eq meta
    end
  end
end
