# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/communication_channel'

describe VAProfile::Models::CommunicationChannel, type: :model do
  describe 'validation' do
    let(:communication_channel) { described_class.new }

    %w[id communication_permission].each do |attr|
      it "validates presence of #{attr}" do
        expect_attr_invalid(communication_channel, attr, "can't be blank")
      end
    end

    it 'validates communication_permission' do
      communication_channel.communication_permission = build(:communication_permission, allowed: nil)
      expect_attr_invalid(communication_channel, :communication_permission, 'Allowed must be set')
    end
  end

  describe '.create_from_api' do
    let(:channel_data) { { 'communication_channel_id' => 1 } }
    let(:item_channel_data) { { 'default_send_indicator' => true } }
    let(:permission_res) do
      {
        'bios' => [
          {
            'communication_item_id' => 123,
            'communication_channel_id' => 1,
            'communication_permission_id' => 42,
            'allowed' => true
          }
        ]
      }
    end

    it 'creates a channel without sensitive indicators' do
      channel = described_class.create_from_api(channel_data, 123, item_channel_data, permission_res)

      expect(channel.sensitive_indicator).to be_nil
      expect(channel.default_sensitive_indicator).to be_nil
      expect(channel.communication_permission.sensitive).to be_nil
    end

    it 'sets sensitive indicators when present' do
      item_channel_data.merge!(
        'sensitive_indicator' => false,
        'default_sensitive_indicator' => true
      )
      permission_res['bios'][0]['sensitive'] = true

      channel = described_class.create_from_api(channel_data, 123, item_channel_data, permission_res)

      expect(channel.sensitive_indicator).to eq(false)
      expect(channel.default_sensitive_indicator).to eq(true)
      expect(channel.communication_permission.sensitive).to eq(true)
    end

    it 'does not assign sensitive fields if only one is present' do
      item_channel_data_with_one_sensitive_field = item_channel_data.merge('sensitive_indicator' => true)

      channel = described_class.create_from_api(channel_data, 123, item_channel_data_with_one_sensitive_field, permission_res)

      expect(channel.sensitive_indicator).to be_nil
      expect(channel.default_sensitive_indicator).to be_nil
    end
  end
end
