# frozen_string_literal: true

require 'rails_helper'

describe EVSS::AWSConfiguration do
  describe '#mock_enabled?' do
    it 'has a mock_enabled? method that returns a boolean' do
      expect(described_class.instance.mock_enabled?).to be_in([true, false])
    end
  end
end
