# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/communication_item'

describe VAProfile::Models::CommunicationItem, type: :model do
  describe 'validation' do
    let(:communication_item) { described_class.new }

    %w[id communication_channel].each do |attr|
      it "validates presence of #{attr}" do
        expect_attr_invalid(communication_item, attr, "can't be blank")
      end
    end

    it 'validates first communication_channel' do
      communication_channel = build(:communication_channel)
      communication_channel.id = nil
      communication_item.communication_channel = communication_channel
      expect_attr_invalid(communication_item, :communication_channel, "Id can't be blank")
    end
  end
end
