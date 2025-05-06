# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VeteranDeviceRecordsService, type: :service do
  describe 'veteran_device_records#create_or_activate' do
    let!(:user) { create(:user, :loa3) }
    let!(:device) { create(:device, :fitbit) }

    context 'when no veteran device record exists' do
      it 'create one' do
        VeteranDeviceRecordsService.create_or_activate(user, device.key)
        record = VeteranDeviceRecord.all.first

        expect(record.device_id).to eq(device.id)
        expect(record.icn).to eq(user.icn)
        expect(record.active).to be(true)
      end
    end

    context 'when veteran device record exists but not active' do
      let!(:inactive_record) { create(:veteran_device_record, :inactive, icn: user.icn, device_id: device.id) }

      it 'sets the record active to true' do
        expect(inactive_record.active).to be(false)

        VeteranDeviceRecordsService.create_or_activate(user, device.key)
        record = VeteranDeviceRecord.all.first

        expect(record.device_id).to eq(device.id)
        expect(record.icn).to eq(user.icn)
        expect(record.active).to be(true)
      end
    end

    context 'when veteran device record exists and active' do
      let!(:active_record) { create(:veteran_device_record, icn: user.icn, device_id: device.id) }

      it 'does not change the record' do
        expect(active_record.active).to be(true)

        VeteranDeviceRecordsService.create_or_activate(user, device.key)
        record = VeteranDeviceRecord.all.first

        expect(record.device_id).to eq(device.id)
        expect(record.icn).to eq(user.icn)
        expect(record.active).to be(true)
      end
    end

    context 'when no device with given key exists' do
      it 'throws error' do
        expected = expect do
          VeteranDeviceRecordsService.create_or_activate(user, 'non-existing-device')
        end
        expected.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe 'veteran_device_records#deactivate' do
    let!(:user) { create(:user, :loa3) }
    let!(:device) { create(:device, :fitbit) }

    before do
      @vdr = VeteranDeviceRecord.create(icn: user.icn, device_id: device.id, active: true)
    end

    context 'when device exists and veteran device record is active' do
      it 'updates record' do
        VeteranDeviceRecordsService.deactivate(user, device.key)
        record = VeteranDeviceRecord.all.first
        expect(record.active).to be(false)
      end
    end

    context 'when device doesn\'t exist' do
      it 'throws error' do
        expected = expect do
          VeteranDeviceRecordsService.deactivate(user, 'non-existing-device')
        end
        expected.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when device is already deactivated' do
      it 'doesn\'t throw error' do
        @vdr.active = false
        VeteranDeviceRecordsService.deactivate(user, device.key)
        record = VeteranDeviceRecord.all.first
        expect(record.active).to be(false)
      end
    end
  end
end
