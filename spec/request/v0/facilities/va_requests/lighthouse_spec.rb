# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: '/lighthouse/facilities',
  match_requests_on: %i[path query],
  allow_playback_repeats: true,
  record: :new_episodes
}

RSpec.describe 'VA Facilities Locator - Lighthouse', type: :request, team: :facilities, vcr: vcr_options do
  include SchemaMatchers

  before do
    Flipper.enable(:facility_locator_pull_operating_status_from_lighthouse, false)
    Flipper.enable(:facility_locator_lighthouse_api, true)
  end

  describe 'GET #index' do
    subject! { get '/v0/facilities/va', params: params; JSON.parse(response.body).with_indifferent_access }

    context 'only bbox' do
      let(:params) {
        { 
          bbox: [ -122.786758, 45.451913, -122.440689, 45.64 ]
        }
      }
  
      it { expect(response).to be_successful }

      it {
        is_expected.to include(
          meta: {
            pagination: {
              current_page: 1,
              per_page: 10,
              total_entries: 10,
              total_pages: 1
            }
          }
        )
      }

      it {
        is_expected.to include(
          links: {
            self: 'http://www.example.com/v0/facilities/va?bbox%5B%5D=-122.786758&bbox%5B%5D=45.451913&bbox%5B%5D=-122.440689&bbox%5B%5D=45.64',
            first: 'http://www.example.com/v0/facilities/va?bbox%5B%5D=-122.786758&bbox%5B%5D=45.451913&bbox%5B%5D=-122.440689&bbox%5B%5D=45.64&page=1&per_page=10',
            prev: nil,
            next: nil,
            last: 'http://www.example.com/v0/facilities/va?bbox%5B%5D=-122.786758&bbox%5B%5D=45.451913&bbox%5B%5D=-122.440689&bbox%5B%5D=45.64&page=1&per_page=10'
          }
        )
      }
  
      it do
        expect(JSON.parse(response.body)['data'].collect {|x| x['id']}).to match(
          [ 
            'vba_348e', 'vha_648GI', 'vba_348', 'vba_348a', 'vc_0617V',
            'vba_348d', 'vha_648', 'vba_348h', 'vha_648A4', 'nca_907'
          ]
        )
      end
    end

    context 'bbox and type' do
      let(:params) {
        { 
          bbox: [ -122.786758, 45.451913, -122.440689, 45.64 ],
          type: 'health'
        }
      }
  
      it { expect(response).to be_successful }
      
      it {
        is_expected.to include(
          meta: {
            pagination: {
              current_page: 1,
              per_page: 10,
              total_entries: 4,
              total_pages: 1
            }
          }
        )
      }

      it {
        is_expected.to include(
          links: {
            self: 'http://www.example.com/v0/facilities/va?bbox%5B%5D=-122.786758&bbox%5B%5D=45.451913&bbox%5B%5D=-122.440689&bbox%5B%5D=45.64&type=health',
            first: 'http://www.example.com/v0/facilities/va?bbox%5B%5D=-122.786758&bbox%5B%5D=45.451913&bbox%5B%5D=-122.440689&bbox%5B%5D=45.64&page=1&per_page=10&type=health',
            prev: nil,
            next: nil,
            last: 'http://www.example.com/v0/facilities/va?bbox%5B%5D=-122.786758&bbox%5B%5D=45.451913&bbox%5B%5D=-122.440689&bbox%5B%5D=45.64&page=1&per_page=10&type=health'
          }
        )
      }
  
      it do
        expect(JSON.parse(response.body)['data'].collect {|x| x['id']}).to match(
          [ 
            'vha_648GI', 'vha_648', 'vha_648A4', 'vha_648GE'
          ]
        )
      end
    end

  end
end