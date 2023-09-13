# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Connected Applications API endpoint' do
  let(:user) { build(:user, :loa3, uuid: '1847a3eb4b904102882e24e4ddf12ff3') }

  before { sign_in_as(user) }

  context 'with valid response from okta' do
    it 'returns list of grants by app' do
      with_okta_configured do
        VCR.use_cassette('okta/grants') do
          get '/v0/profile/connected_applications'
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data'][0]['id']).to eq('0oa2ey2m6kEL2897N2p7')
        end
      end
    end

    it 'deletes all the grants by app' do
      with_okta_configured do
        VCR.use_cassette('lighthouse/auth/client_credentials/revoke_consent_204', allow_playback_repeats: true) do
          delete '/v0/profile/connected_applications/0oa2ey2m6kEL2897N2p7'
          expect(response).to have_http_status(:no_content)
        end
      end
    end
  end
end
