# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DhpConnectedDevices::FitbitController, type: :request do
  let(:current_user) { build(:user, :loa1) }

  describe 'fitbit#connect' do
    def fitbit_connect
      get '/dhp_connected_devices/fitbit'
    end

    context 'fitbit feature enabled and un-authenticated user' do
      before { Flipper.enable(:dhp_connected_devices_fitbit) }

      it 'returns unauthenticated' do
        expect(fitbit_connect).to be 401
      end
    end

    context 'fitbit feature disabled and authenticated user' do
      before do
        sign_in_as(current_user)
        Flipper.disable(:dhp_connected_devices_fitbit)
      end

      it 'returns not found' do
        expect(fitbit_connect).to be 404
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
        expect(fitbit_connect).to redirect_to(expected_url)
      end
    end
  end

  describe 'fitbit#callback' do
    def fitbit_callback(params = '')
      get "/dhp_connected_devices/fitbit-callback#{params}"
    end

    context 'fitbit feature enabled and user unauthenticated' do
      it 'navigating to /fitbit-callback returns error' do
        Flipper.enable(:dhp_connected_devices_fitbit)
        expect(fitbit_callback).to be 401
      end
    end

    context 'fitbit feature not enabled and user unauthenticated' do
      it 'navigating to /fitbit-callback returns error' do
        Flipper.disable(:dhp_connected_devices_fitbit)
        expect(fitbit_callback).to be 401
      end
    end

    context 'fitbit feature not enabled and user authenticated' do
      before do
        sign_in_as(current_user)
        Flipper.disable(:dhp_connected_devices_fitbit)
      end

      it 'navigating to /fitbit-callback returns error' do
        expect(fitbit_callback).to be 404
      end
    end

    context 'fitbit feature enabled and user authenticated' do
      before do
        sign_in_as(current_user)
        Flipper.enable(:dhp_connected_devices_fitbit)
      end

      it "redirects with 'fitbit=error' when error occurs" do
        expect(fitbit_callback('?error=declined')).to redirect_to 'http://localhost:3001/health-care/connected-devices/?fitbit=error#_=_'
      end

      it "redirects with 'fitbit=success' when auth code is returned and token exchange is successful'" do
        faraday_response = double('response', status: 200)
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(faraday_response)
        expect(fitbit_callback('?code=889709')).to redirect_to 'http://localhost:3001/health-care/connected-devices/?fitbit=success#_=_'
      end
    end
  end
end
