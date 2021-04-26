# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/communication_item'

describe VAProfile::Models::CommunicationItem, type: :model do
  describe 'validation' do
    let(:communication_item) { described_class.new }

    %w[id communication_channels].each do |attr|
      it "validates presence of #{attr}" do
        expect_attr_invalid(communication_item, attr, "can't be blank")
      end
    end

    it 'validates array length of communication_channels' do
      communication_item.communication_channels = [build(:communication_channel), build(:communication_channel)]
      expect_attr_invalid(communication_item, :communication_channels, 'must have only one communication channel')

      communication_item.communication_channels = [build(:communication_channel)]
      expect_attr_valid(communication_item, :communication_channels)
    end

    it 'validates first communication_channel' do
      communication_channel = build(:communication_channel)
      communication_channel.id = nil
      communication_item.communication_channels = [communication_channel]
      expect_attr_invalid(communication_item, :communication_channels, "Id can't be blank")
    end
  end
end
