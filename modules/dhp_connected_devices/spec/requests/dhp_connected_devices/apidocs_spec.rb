# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DhpConnectedDevices::Apidocs', type: :request do
  describe 'GET /dhp_connected_devices/apidocs' do
    it 'renders the apidocs as json' do
      get '/dhp_connected_devices/apidocs'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).first).to eq(%w[openapi 3.0.0])
    end
  end
end
