# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DhpConnectedDevices::Fitbit::FitbitController, type: :request do
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
      def error_path
        'http://localhost:3001/health-care/connected-devices/?fitbit=error#_=_'
      end

      def success_path
        'http://localhost:3001/health-care/connected-devices/?fitbit=success#_=_'
      end

      before do
        sign_in_as(current_user)
        Flipper.enable(:dhp_connected_devices_fitbit)
        create(:device, :fitbit)
      end

      let(:fitbit_api) { instance_double(DhpConnectedDevices::Fitbit::Client) }
      let(:fitbit_client) { DhpConnectedDevices::Fitbit::Client }
      let(:token_storage_service) { instance_double(TokenStorageService) }
      let(:token_exchange_error) { DhpConnectedDevices::Fitbit::TokenExchangeError }
      let(:missing_auth_error) { DhpConnectedDevices::Fitbit::MissingAuthError }
      let(:access_token) { '{"access_token":"token"}' }

      it 'logs errors to Sentry ' do
        allow_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(any_args)

        expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry)
        expect(fitbit_callback('?error="error"')).to redirect_to error_path
      end

      it "redirects with 'fitbit=error' when authorization code is not received" do
        allow(fitbit_api).to receive(:get_auth_code).with(any_args).and_raise(missing_auth_error)
        allow_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(any_args)

        expect(fitbit_api).not_to receive(:get_token)
        expect(token_storage_service).not_to receive(:store_tokens)
        expect(VeteranDeviceRecordsService).not_to receive(:create_or_activate)

        expect(fitbit_callback('?')).to redirect_to error_path
        expect(fitbit_callback('?error="error"')).to redirect_to error_path
      end

      it "redirects with 'fitbit=error' when authorization is given but token exchange is unsuccessful" do
        allow_any_instance_of(fitbit_client).to receive(:get_auth_code).with(any_args).and_return('889709')
        allow_any_instance_of(fitbit_client).to receive(:get_token).with(any_args).and_raise(token_exchange_error)
        allow_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(any_args)

        expect(token_storage_service).not_to receive(:store_tokens)

        expect(fitbit_callback('?code=889709')).to redirect_to error_path
      end

      it "redirects with 'fitbit=error' when token exchange is successful but token storage is unsuccessful" do
        allow_any_instance_of(fitbit_client).to receive(:get_auth_code).with(any_args).and_return('889709')
        allow_any_instance_of(fitbit_client).to receive(:get_token).with(any_args).and_return(access_token)
        allow_any_instance_of(TokenStorageService).to receive(:store_tokens).with(any_args).and_raise(TokenStorageError)
        allow_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(any_args)

        expect(fitbit_callback('?code=889709')).to redirect_to error_path
      end

      it "redirects with 'fitbit=success' when is token storage is successful'" do
        allow_any_instance_of(fitbit_client).to receive(:get_auth_code).with(any_args).and_return('889709')
        allow_any_instance_of(fitbit_client).to receive(:get_token).with(any_args).and_return(access_token)
        allow_any_instance_of(TokenStorageService).to receive(:store_tokens).with(any_args).and_return(true)

        expect(fitbit_callback('?code=889709')).to redirect_to success_path
      end
    end
  end

  describe 'fitbit#disconnect' do
    def fitbit_disconnect
      get '/dhp_connected_devices/fitbit/disconnect'
    end

    context 'fitbit feature enabled and authenticated user' do
      before do
        sign_in_as(current_user)
        @device = create(:device, :fitbit)
        @vdr = VeteranDeviceRecord.create(device_id: @device.id, active: true, icn: current_user.icn)
      end

      it 'updates the user\'s fitbit record to false' do
        expect(VeteranDeviceRecord.active_devices(current_user).empty?).to be(false)
        fitbit_disconnect
        expect(VeteranDeviceRecord.active_devices(current_user).empty?).to eq true
      end

      it 'redirects to frontend with disconnect-success code on success' do
        expect(fitbit_disconnect).to redirect_to 'http://localhost:3001/health-care/connected-devices/?fitbit=disconnect-success#_=_'
      end

      it 'redirects to frontend with disconnect-error code on device record not found error' do
        VeteranDeviceRecord.delete(@vdr)
        expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).with(
          instance_of(ActiveRecord::RecordNotFound),
          { icn: current_user.icn }
        )
        expect(fitbit_disconnect).to redirect_to 'http://localhost:3001/health-care/connected-devices/?fitbit=disconnect-error#_=_'
      end
    end

    context 'fitbit feature enabled and user unauthenticated' do
      it 'navigating to /fitbit/disconnect returns error' do
        Flipper.enable(:dhp_connected_devices_fitbit)
        expect(fitbit_disconnect).to be 401
      end
    end
  end
end
