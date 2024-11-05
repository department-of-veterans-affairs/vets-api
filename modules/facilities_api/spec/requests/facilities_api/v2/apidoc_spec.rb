# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'FacilitiesApi::V2::Apidocs', type: :request do
  describe 'GET `index`' do
    it 'is successful' do
      get '/facilities_api/v2/apidocs'

      expect(response).to have_http_status(:ok)
    end

    it 'is a hash' do
      get '/facilities_api/v2/apidocs'

      expect(JSON.parse(response.body)).to be_a(Hash)
    end

    it 'has the correct tag description' do
      description = 'VA facilities, locations, hours of operation, available services'

      get '/facilities_api/v2/apidocs'

      expect(JSON.parse(response.body)['tags'][0]['description']).to eq(description)
    end
  end

  context 'API Documentation', type: %i[apivore request] do
    subject(:apivore) do
      Apivore::SwaggerChecker.instance_for('/facilities_api/v2/apidocs.json')
    end

    vcr_options = {
      match_requests_on: %i[path query],
      allow_playback_repeats: true
    }

    describe 'facilities_api/v2/va', team: :facilities,
                                     vcr: vcr_options.merge(cassette_name: '/lighthouse/facilities') do
      it { is_expected.to validate(:post, '/facilities_api/v2/va', 200) }
    end

    describe 'facilities/v2/va/{id}', team: :facilities,
                                      vcr: vcr_options.merge(cassette_name: '/lighthouse/facilities') do
      it { is_expected.to validate(:get, '/facilities_api/v2/va/{id}', 200, 'id' => 'vha_358') }
      it { is_expected.to validate(:get, '/facilities_api/v2/va/{id}', 404, 'id' => 'nca_9999999') }
    end

    describe '/facilities_api/v2/ccp/urgent_care', team: :facilities,
                                                   vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms') do
      let(:params) do
        {
          '_query_string' => {
            latitude: 40.415217,
            longitude: -74.057114,
            radius: 200
          }.to_query
        }
      end

      it { is_expected.to validate(:get, '/facilities_api/v2/ccp/urgent_care', 200, params) }
    end

    describe '/facilities_api/v2/ccp/provider', team: :facilities,
                                                vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms') do
      let(:params) do
        {
          '_query_string' => {
            latitude: 40.415217,
            longitude: -74.057114,
            radius: 200,
            specialties: ['213E00000X']
          }.to_query
        }
      end

      it { is_expected.to validate(:get, '/facilities_api/v2/ccp/provider', 200, params) }
    end

    describe '/facilities_api/v2/ccp/specialties',
             team: :facilities, vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_specialties') do
      it { is_expected.to validate(:get, '/facilities_api/v2/ccp/specialties', 200) }
    end
  end
end
