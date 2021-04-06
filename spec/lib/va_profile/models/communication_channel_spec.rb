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
end
