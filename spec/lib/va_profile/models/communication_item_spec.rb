# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/communication_item'

describe VAProfile::Models::CommunicationItem, type: :model do
  describe 'validation' do
    %w[id communication_channels].each do |attr|
      it "validates presence of #{attr}" do
        communication_item = described_class.new

        expect_attr_invalid(communication_item, attr, "can't be blank")
      end
    end
  end
end
