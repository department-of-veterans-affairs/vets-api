# frozen_string_literal: true

require 'rails_helper'

Rspec.describe DhpConnectedDevices::VeteranDeviceRecordsController, type: :request do
  let(:current_user) { build(:user, :loa1) }

  describe 'veteran_device_record#record' do
    context 'unauthenticated user' do
      before { Flipper.enable(:dhp_connected_devices_fitbit) }

      it 'returns unauthenticated error' do
        get '/dhp_connected_devices/veteran-device-records'
        expect(response.status).to eq(401)
      end
    end

    context 'authenticated user' do
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
        expect(json['devices'].length).to eq(2)
        expect(json['devices'][0]['connected']).to eq(true)
      end
    end
  end
end
