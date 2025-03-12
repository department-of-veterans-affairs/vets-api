# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VeteranDeviceRecord, type: :model do
  describe 'Veteran Device Record' do
    let(:current_user) { build(:user) }

    before do
      @device = create(:device, :fitbit)
    end

    after do
      VeteranDeviceRecord.delete_all
    end

    it 'creates a Veteran Device Record' do
      expect(VeteranDeviceRecord.new(icn: current_user.icn, device_id: @device.id,
                                     active: true)).to be_valid
    end

    it 'requires user icn' do
      expect(VeteranDeviceRecord.new(device_id: @device.id, active: true)).not_to be_valid
    end

    it 'requires device_id' do
      expect(VeteranDeviceRecord.new(icn: current_user.icn, active: true)).not_to be_valid
    end

    it "is 'active' by default" do
      expect(VeteranDeviceRecord.new(icn: current_user.icn, device_id: @device.id).active).to be_truthy
    end

    it 'has a device' do
      vdr = create(:veteran_device_record, device_id: @device.id)
      expect(vdr.device).to eq(@device)
    end

    it 'only returns active device connections when #active_devices() is called' do
      device2 = create(:device, :abbott)
      vdr_active = create(:veteran_device_record, device_id: @device.id, icn: current_user.icn)
      create(:veteran_device_record, device_id: device2.id, icn: current_user.icn, active: false)
      veteran_active_devices = VeteranDeviceRecord.active_devices(current_user)

      expect(veteran_active_devices.length).to eq(1)
      expect(veteran_active_devices.first).to eq(vdr_active)
    end

    it 'does not create record if user ID and device ID combination exist' do
      VeteranDeviceRecord.create(device_id: @device.id, icn: current_user.icn, active: true)
      expect(VeteranDeviceRecord.create(icn: current_user.icn, device_id: @device.id,
                                        active: true)).not_to be_valid
    end
  end
end
