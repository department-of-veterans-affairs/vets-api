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

    context 'with empty communication-permissions response' do
      before do
        allow(user).to receive(:vet360_id).and_return('7909')
      end

      it 'returns the right groups' do
        VCR.use_cassette('va_profile/communication/communication_permissions_not_found', VCR::MATCH_EVERYTHING) do
          VCR.use_cassette('va_profile/communication/communication_items', VCR::MATCH_EVERYTHING) do
            res = subject.get_items_and_permissions

            expect(JSON.parse(res.to_json)).to eq(get_fixture('va_profile/items_without_permissions'))
          end
        end
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
               'allowed' => true,
               'sensitive' => true },
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

  describe '#update_communication_permission' do
    context 'with an existing communication permission' do
      it 'puts to communication-permissions', run_at: '2021-03-24T23:46:17Z' do
        communication_item = build(:communication_item)
        communication_item.communication_channel.communication_permission.id = 46
        communication_item.communication_channel.communication_permission.allowed = true

        VCR.use_cassette('va_profile/communication/put_communication_permissions', VCR::MATCH_EVERYTHING) do
          res = subject.update_communication_permission(communication_item)
          expect(res).to eq(
            { 'tx_audit_id' => '924b24a5-609d-48ff-ab2e-9f5ac8770e93',
              'status' => 'COMPLETED_SUCCESS',
              'bio' =>
              { 'create_date' => '2021-03-24T22:38:21Z',
                'update_date' => '2021-03-24T23:46:17Z',
                'tx_audit_id' => '924b24a5-609d-48ff-ab2e-9f5ac8770e93',
                'source_system' => 'VETSGOV',
                'source_date' => '2021-03-24T23:46:17Z',
                'communication_permission_id' => 46,
                'va_profile_id' => 18_277,
                'communication_channel_id' => 1,
                'communication_item_id' => 2,
                'communication_channel_name' => 'Text',
                'communication_item_common_name' => 'RX Prescription Refill Reminder',
                'allowed' => true } }
          )
        end
      end
    end

    context 'without an existing communication permission' do
      it 'posts to communication-permissions', run_at: '2021-03-24T22:38:21Z' do
        VCR.use_cassette('va_profile/communication/post_communication_permissions', VCR::MATCH_EVERYTHING) do
          res = subject.update_communication_permission(build(:communication_item))
          expect(res).to eq(
            { 'tx_audit_id' => '3e776301-4794-402a-8a99-67d473232b6c',
              'status' => 'COMPLETED_SUCCESS',
              'bio' =>
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
                'allowed' => false } }
          )
        end
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
