# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: '/lighthouse/facilities',
  match_requests_on: %i[path query],
  allow_playback_repeats: true,
  record: :new_episodes
}

RSpec.shared_examples 'has Pagination metadata and links' do
  it 'is expected to include pagination metadata' do
    is_expected.to include(
      meta: {
        pagination: {
          current_page: a_kind_of(Integer),
          per_page: a_kind_of(Integer),
          total_entries: a_kind_of(Integer),
          total_pages: a_kind_of(Integer)
        }
      }
    )
  end

  it 'is expected to include pagination links' do
    binding.pry
    is_expected.to include(
      links: {
        self: a_kind_of(String),
        first: a_kind_of(String),
        prev: nil,
        next: nil,
        last: a_kind_of(String)
      }
    )
  end
end

RSpec.describe 'VA Facilities Locator - Lighthouse', type: :request, team: :facilities, vcr: vcr_options do
  include SchemaMatchers

  before do
    Flipper.enable(:facility_locator_pull_operating_status_from_lighthouse, false)
    Flipper.enable(:facility_locator_lighthouse_api, true)
  end

  describe 'GET #index' do
    before
      get get '/v0/facilities/va', params: params
    end
    subject! { JSON.parse(response.body) }

    context 'bbox' do
      let(:params) {
        { 
          bbox: [ -122.786758, 45.451913, -122.440689, 45.64 ]
        }
      }
  
      it_behaves_like 'has Pagination metadata and links'

      it { expect(response).to be_successful }
  
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
      
      it_behaves_like 'has Pagination metadata and links'
  
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