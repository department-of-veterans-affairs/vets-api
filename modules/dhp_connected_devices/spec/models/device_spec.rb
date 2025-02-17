# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Device, type: :model do
  let(:current_user) { build(:user) }

  it 'creates device when given a name and key' do
    expect(Device.new(name: 'name', key: 'key')).to be_valid
  end

  it 'requires a key' do
    Device.create(name: 'fitbit')
    expect(Device.new(name: 'device_name')).not_to be_valid
  end

  it 'requires a name' do
    expect(Device.new(key: 'device_key')).not_to be_valid
  end

  it 'has many veteran_device_records' do
    device = create(:device, :fitbit)
    vdrs = [
      create(:veteran_device_record, icn: 'def', device_id: device.id),
      create(:veteran_device_record, device_id: device.id)
    ]

    expect(device.veteran_device_records.count).to eq(2)
    expect(device.veteran_device_records).to eq(vdrs)
  end

  it '#device_records returns all active and inactive devices for a user' do
    device1 = create(:device, :fitbit)
    device2 = create(:device, :abbott)

    create(:veteran_device_record, icn: '123456', active: true, device_id: device2.id)
    active_devices = create(:veteran_device_record, icn: current_user.icn, active: true, device_id: device1.id)
    inactive_devices = create(:veteran_device_record, icn: current_user.icn, active: false, device_id: device2.id)
    records = Device.veteran_device_records(current_user)
    expect(records[:active].length).to eq(1)
    expect(records[:inactive].length).to eq(1)

    expect(records[:active][0].key).to eq(active_devices.device.key)
    expect(records[:inactive][0].key).to eq(inactive_devices.device.key)
  end
end
