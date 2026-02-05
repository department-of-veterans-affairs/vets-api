# frozen_string_literal: true

require 'rails_helper'

Rspec.describe 'DhpConnectedDevices::VeteranDeviceRecords', type: :request do
  let(:current_user) { build(:user, :loa1) }
  let(:user_without_icn) { build(:user, :loa1, icn: '') }

  describe 'veteran_device_record#record' do
    context 'unauthenticated user' do
      before { Flipper.enable(:dhp_connected_devices_fitbit) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

      it 'returns unauthenticated error' do
        get '/dhp_connected_devices/veteran-device-records'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'authenticated user without icn' do
      before do
        sign_in_as(user_without_icn)
      end

      it 'returns veteran device record' do
        get '/dhp_connected_devices/veteran-device-records'
        json = JSON.parse(response.body)
        expect(json['connectionAvailable']).to be(false)
        expect(json['devices']).to be_nil
      end
    end

    context 'authenticated user with icn' do
      before do
        devices = [create(:device, :fitbit), create(:device, :abbott)]
        sign_in_as(current_user)
        devices.each do |device|
          VeteranDeviceRecord.create(icn: current_user.icn, device_id: device.id, active: true)
        end
      end

      after do
        VeteranDeviceRecord.delete_all
      end

      it 'returns veteran device record' do
        get '/dhp_connected_devices/veteran-device-records'
        json = JSON.parse(response.body)
        expect(json['connectionAvailable']).to be(true)
        expect(json['devices'].length).to eq(2)
        expect(json['devices'][0]['connected']).to be(true)
      end
    end
  end
end
