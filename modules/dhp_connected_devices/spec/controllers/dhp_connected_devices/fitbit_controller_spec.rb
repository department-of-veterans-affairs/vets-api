# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DhpConnectedDevices::FitbitController, type: :request do
  describe 'fitbit#connect' do
    let(:current_user) { build(:user, :loa1) }

    context 'fitbit feature enabled and un-authenticated user' do
      before { Flipper.enable(:dhp_connected_devices_fitbit) }

      it 'returns unauthenticated' do
        response = get '/dhp_connected_devices/fitbit'
        expect(response).to be 401
      end
    end

    context 'fitbit feature disabled and authenticated user' do
      before do
        sign_in_as(current_user)
        Flipper.disable(:dhp_connected_devices_fitbit)
      end

      it 'returns not found' do
        response = get '/dhp_connected_devices/fitbit'
        expect(response).to be 404
      end
    end

    context 'fitbit feature enabled and authenticated user' do
      before do
        sign_in_as(current_user)
        Flipper.enable(:dhp_connected_devices_fitbit)
      end

      let(:client) { DhpConnectedDevices::Fitbit::Client.new }
      let(:expected_url) { client.auth_url_with_pkce }

      it 'redirects to fitbit' do
        response = get '/dhp_connected_devices/fitbit'
        expect(response).to redirect_to(expected_url)
      end
    end
  end

  # describe 'GET /callback' do
  #   it 'returns the' do
  #   end
  # end
end
