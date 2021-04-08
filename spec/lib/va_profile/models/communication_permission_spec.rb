# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/communication_permission'

describe VAProfile::Models::CommunicationPermission, type: :model do
  describe 'validation' do
    let(:communication_permission) { described_class.new }

    %w[allowed].each do |attr|
      it "validates presence of #{attr}" do
        expect_attr_invalid(communication_permission, attr, 'must be set')
      end
    end
  end
end
