# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Profile::ConnectedApplications', type: :request do
  let(:user) { build(:user, :loa3, uuid: '1847a3eb4b904102882e24e4ddf12ff3') }

  before { sign_in_as(user) }

  context 'with valid response from okta' do
    it 'returns list of grants by app' do
      VCR.use_cassette('lighthouse/auth/client_credentials/connected_apps_200') do
        get '/v0/profile/connected_applications'
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data'][0]['id']).to eq('0oa2ey2m6kEL2897N2p7')
      end
    end

    it 'handle non-200 calls from lh auth' do
      VCR.use_cassette('lighthouse/auth/client_credentials/connected_apps_400') do
        get '/v0/profile/connected_applications'
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data'].length).to eq(0)
      end
    end

    it 'deletes all the grants by app' do
      VCR.use_cassette('lighthouse/auth/client_credentials/revoke_consent_204', allow_playback_repeats: true) do
        delete '/v0/profile/connected_applications/0oa2ey2m6kEL2897N2p7'
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
