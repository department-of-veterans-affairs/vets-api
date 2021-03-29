# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/communication_item'

describe VAProfile::Models::CommunicationItem do
  describe 'validation' do
    it 'validates presence of id' do
      communication_item = described_class.new
      binding.pry; fail
    end
  end
end
