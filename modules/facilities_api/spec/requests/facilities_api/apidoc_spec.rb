# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'FacilitiesApi::Apidocs' do
  before(:all) do
    get facilities_api.apidocs_url
  end

  context 'json validation' do
    it 'has valid json' do
      get '/facilities_api/apidocs'
      json = response.body
      JSON.parse(json).to_yaml
    end
  end

  context 'API Documentation', type: %i[apivore request] do
    subject(:apivore) { Apivore::SwaggerChecker.instance_for('/facilities_api/apidocs.json') }

    vcr_options = {
      match_requests_on: %i[path query],
      allow_playback_repeats: true,
      record: :new_episodes
    }

    describe 'facilities_api/v1/va', team: :facilities,
                                     vcr: vcr_options.merge(cassette_name: '/lighthouse/facilities') do
      let(:params) do
        {
          '_query_string' => {
            bbox: ['-122.440689', '45.451913', '-122.78675', '45.64']
          }.to_query
        }
      end

      it { is_expected.to validate(:get, '/facilities_api/v1/va', 200, params) }

      it {
        expect(subject).to validate(:get, '/facilities_api/v1/va', 400,
                                    '_query_string' => 'bbox[]=-122&bbox[]=45&bbox[]=-123')
      }
    end

    describe 'facilities/va/{id}', team: :facilities, vcr: vcr_options.merge(cassette_name: '/lighthouse/facilities') do
      it { is_expected.to validate(:get, '/facilities_api/v1/va/{id}', 200, 'id' => 'vha_358') }
      it { is_expected.to validate(:get, '/facilities_api/v1/va/{id}', 404, 'id' => 'nca_9999999') }
    end

    describe 'facilities/ccp/urgent_care', team: :facilities,
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

      it { is_expected.to validate(:get, '/facilities_api/v1/ccp/urgent_care', 200, params) }
    end

    describe 'facilities/ccp/provider', team: :facilities,
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

      it { is_expected.to validate(:get, '/facilities_api/v1/ccp/provider', 200, params) }
    end

    # describe 'facilities/ccp/{id}', team: :facilities, vcr: vcr_options.merge(
    #   cassette_name: 'facilities/ppms/ppms') do
    #   it { is_expected.to validate(:get, '/facilities_api/v1/ccp/{id}', 200, 'id' => '1154383230') }
    # end

    describe 'facilities/ccp/specialties', team: :facilities,
                                           vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_specialties') do
      it { is_expected.to validate(:get, '/facilities_api/v1/ccp/specialties', 200) }
    end
  end
end
