# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppsApi::V0::DirectoryController, type: :controller do
  context 'with no params' do
    it 'returns list of oauth apps in okta' do
      VCR.use_cassette('apps/200_apps') do
        get :index
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data'][0]['id']).to eq('0oa1c01m77heEXUZt2p7')
      end
    end
  end
end
