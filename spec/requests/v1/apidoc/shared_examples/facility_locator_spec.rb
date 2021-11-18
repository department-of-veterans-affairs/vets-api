# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'V1 Facility Locator' do
  vcr_options = {
    match_requests_on: %i[path query],
    allow_playback_repeats: true,
    record: :new_episodes
  }

  describe 'facilities/va', team: :facilities, vcr: vcr_options.merge(cassette_name: '/lighthouse/facilities') do
    let(:params) do
      {
        '_query_string' => {
          bbox: ['-122.440689', '45.451913', '-122.78675', '45.64']
        }.to_query
      }
    end

    it { is_expected.to validate(:get, '/v1/facilities/va', 200, params) }

    it {
      expect(subject).to validate(:get, '/v1/facilities/va', 400,
                                  '_query_string' => 'bbox[]=-122&bbox[]=45&bbox[]=-123')
    }
  end

  describe 'facilities/va/{id}', team: :facilities, vcr: vcr_options.merge(cassette_name: '/lighthouse/facilities') do
    it { is_expected.to validate(:get, '/v1/facilities/va/{id}', 200, 'id' => 'vha_358') }
    it { is_expected.to validate(:get, '/v1/facilities/va/{id}', 404, 'id' => 'nca_9999999') }
  end

  describe 'facilities/ccp lat/long', team: :facilities,
                                      vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_old') do
    let(:params) do
      {
        '_query_string' => {
          latitude: 40.415217,
          longitude: -74.057114,
          radius: 200,
          type: 'provider',
          specialties: ['213E00000X']
        }.to_query
      }
    end

    it { is_expected.to validate(:get, '/v1/facilities/ccp', 200, params) }
  end

  describe 'facilities/ccp/{id}', team: :facilities,
                                  vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_old') do
    it { is_expected.to validate(:get, '/v1/facilities/ccp/{id}', 200, 'id' => '1154383230') }
  end

  describe 'facilities/ccp/specialties', team: :facilities,
                                         vcr: vcr_options.merge(cassette_name: 'facilities/ppms/ppms_specialties') do
    it { is_expected.to validate(:get, '/v1/facilities/ccp/specialties', 200) }
  end
end
