# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/communication/service'

describe VAProfile::Communication::Service do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3) }

  before do
    allow(user).to receive(:vet360_id).and_return('18277')
  end

  describe '#get_items_and_permissions' do
    it 'creates the right communication groups' do
      VCR.use_cassette('va_profile/communication/get_communication_permissions', VCR::MATCH_EVERYTHING) do
        VCR.use_cassette('va_profile/communication/communication_items', VCR::MATCH_EVERYTHING) do
          res = subject.get_items_and_permissions

          expect(JSON.parse(res.to_json)).to eq(get_fixture('va_profile/items_and_permissions'))
        end
      end
    end
  end

  describe '#update_all_communication_permissions' do
    let!(:communication_items) do
      [
        build(:communication_item, id: 3).tap do |communication_item|
          communication_permission = communication_item.communication_channels[0].communication_permission
          communication_permission.allowed = true
          communication_permission.id = 342
        end,
        build(:communication_item, id: 2).tap do |communication_item|
          communication_permission = communication_item.communication_channels[0].communication_permission
          communication_permission.allowed = true
          communication_permission.id = 341
        end,
        build(:communication_item, id: 4).tap do |communication_item|
          communication_permission = communication_item.communication_channels[0].communication_permission
          communication_permission.allowed = true
          communication_permission.id = 729
        end,
        build(:communication_item, id: 5).tap do |communication_item|
          communication_item.communication_channels[0].id = 2
          communication_permission = communication_item.communication_channels[0].communication_permission
          communication_permission.allowed = true
        end
      ]
    end

    before do
      allow(user).to receive(:vet360_id).and_return('16445')
    end

    it 'sends a request to update multiple communication permissions', run_at: '2021-04-13T20:54:58Z' do
      VCR.use_cassette('va_profile/communication/update_all_communication_permissions', VCR::MATCH_EVERYTHING) do
        res = subject.update_all_communication_permissions(communication_items)
        expect(res).to eq(
          { 'tx_audit_id' => '4e3ae638-4269-4d10-8fbc-71b10872d774',
            'status' => 'COMPLETED_SUCCESS',
            'bio' =>
            { 'create_date' => '2021-04-02T22:25:25Z',
              'update_date' => '2021-04-02T22:25:25Z',
              'tx_audit_id' => 'bc6b2c88-98d6-4e20-b15b-5c746789d7ed',
              'source_system' => 'VETSGOV',
              'source_date' => '2021-04-02T22:25:24Z',
              'va_profile_id' => 16_445,
              'communication_permissions' =>
              [{ 'create_date' => '2021-04-12T15:21:52Z',
                 'update_date' => '2021-04-13T20:54:59Z',
                 'tx_audit_id' => '4e3ae638-4269-4d10-8fbc-71b10872d774',
                 'source_system' => 'VETSGOV',
                 'source_date' => '2021-04-13T20:54:58Z',
                 'communication_permission_id' => 729,
                 'va_profile_id' => 16_445,
                 'communication_channel_id' => 1,
                 'communication_item_id' => 4,
                 'communication_channel_name' => 'Text',
                 'communication_item_common_name' => 'Form 22-1990 Submission Confirmation',
                 'allowed' => true },
               { 'create_date' => '2021-04-13T20:54:59Z',
                 'update_date' => '2021-04-13T20:54:59Z',
                 'tx_audit_id' => '4e3ae638-4269-4d10-8fbc-71b10872d774',
                 'source_system' => 'VETSGOV',
                 'source_date' => '2021-04-13T20:54:58Z',
                 'communication_permission_id' => 770,
                 'va_profile_id' => 16_445,
                 'communication_channel_id' => 2,
                 'communication_item_id' => 5,
                 'communication_channel_name' => 'Email',
                 'communication_item_common_name' => 'Form 526-EZ Submission Confirmation',
                 'allowed' => true },
               { 'create_date' => '2021-04-02T22:25:25Z',
                 'update_date' => '2021-04-13T20:54:59Z',
                 'tx_audit_id' => '4e3ae638-4269-4d10-8fbc-71b10872d774',
                 'source_system' => 'VETSGOV',
                 'source_date' => '2021-04-13T20:54:58Z',
                 'communication_permission_id' => 341,
                 'va_profile_id' => 16_445,
                 'communication_channel_id' => 1,
                 'communication_item_id' => 2,
                 'communication_channel_name' => 'Text',
                 'communication_item_common_name' => 'RX Prescription Refill Reminder',
                 'allowed' => true },
               { 'create_date' => '2021-04-02T22:25:25Z',
                 'update_date' => '2021-04-13T20:54:59Z',
                 'tx_audit_id' => '4e3ae638-4269-4d10-8fbc-71b10872d774',
                 'source_system' => 'VETSGOV',
                 'source_date' => '2021-04-13T20:54:58Z',
                 'communication_permission_id' => 342,
                 'va_profile_id' => 16_445,
                 'communication_channel_id' => 1,
                 'communication_item_id' => 3,
                 'communication_channel_name' => 'Text',
                 'communication_item_common_name' => 'Scheduled Appointment Confirmation',
                 'allowed' => true }] } }
        )
      end
    end
  end

  describe '#get_communication_permissions' do
    it 'increments statsd' do
      allow(StatsD).to receive(:increment)
      expect(StatsD).to receive(:increment).with('api.va_profile.communication.get_communication_permissions.total')

      VCR.use_cassette('va_profile/communication/get_communication_permissions', VCR::MATCH_EVERYTHING) do
        subject.get_communication_permissions
      end
    end

    it 'gets the users communication permissions' do
      VCR.use_cassette('va_profile/communication/get_communication_permissions', VCR::MATCH_EVERYTHING) do
        res = subject.get_communication_permissions
        expect(res).to eq(
          { 'tx_audit_id' => '9ac95d0f-42b8-45a3-9d18-f07e1e81e97f',
            'status' => 'COMPLETED_SUCCESS',
            'bios' =>
            [{ 'create_date' => '2021-03-23T23:19:55Z',
               'update_date' => '2021-03-23T23:19:55Z',
               'tx_audit_id' => '7a1ed4b3-1749-4faa-95de-439e965cfd2a',
               'source_system' => 'VETSGOV',
               'source_date' => '2021-03-23T23:19:55Z',
               'communication_permission_id' => 21,
               'va_profile_id' => 18_277,
               'communication_channel_id' => 1,
               'communication_item_id' => 1,
               'communication_channel_name' => 'Text',
               'communication_item_common_name' => 'Health Appointment Reminder',
               'allowed' => true },
             { 'create_date' => '2021-03-24T22:38:21Z',
               'update_date' => '2021-03-24T22:38:21Z',
               'tx_audit_id' => '3e776301-4794-402a-8a99-67d473232b6c',
               'source_system' => 'VETSGOV',
               'source_date' => '2021-03-24T22:38:21Z',
               'communication_permission_id' => 46,
               'va_profile_id' => 18_277,
               'communication_channel_id' => 1,
               'communication_item_id' => 2,
               'communication_channel_name' => 'Text',
               'communication_item_common_name' => 'RX Prescription Refill Reminder',
               'allowed' => false }] }
        )
      end
    end
  end

  describe '#get_communication_items' do
    it 'gets communication items' do
      VCR.use_cassette('va_profile/communication/communication_items', VCR::MATCH_EVERYTHING) do
        res = subject.get_communication_items

        expect(res).to eq(get_fixture('va_profile/communication_items'))
      end
    end
  end
end
